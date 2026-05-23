"""
Backtest sencillo: corre la estrategia sobre velas históricas y calcula win-rate.
Uso:
    python backtest.py EURUSD            # corre 1 símbolo
    python backtest.py --all             # corre los 16
Asume conexión MT5 activa (igual que main.py).
"""
from __future__ import annotations
import argparse
import logging
import os
import sys
from dataclasses import dataclass
from typing import List
import pandas as pd
from dotenv import load_dotenv

from config import SYMBOLS, STRATEGY
from data_fetcher import MT5Connection
from indicators import add_indicators
from strategy import (
    _trend_direction, _momentum_signal, _structure_confirmation,
)

logging.basicConfig(level=logging.INFO, format="%(message)s")
log = logging.getLogger("backtest")

BARS_TO_TEST = 5000   # cuántas velas de M15 (~52 días)
MAX_HOLD = 96         # cerrar trade si no toca SL/TP en 96 velas (24h en M15)


@dataclass
class Trade:
    symbol: str
    side: str
    entry: float
    sl: float
    tp: float
    exit_price: float
    bars_held: int
    result: str  # "WIN", "LOSS", "TIMEOUT"


def simulate_trade(df_future: pd.DataFrame, side: str, entry: float,
                   sl: float, tp: float) -> Trade:
    for i in range(len(df_future)):
        bar = df_future.iloc[i]
        if side == "BUY":
            if bar["low"] <= sl:
                return Trade("", side, entry, sl, tp, sl, i + 1, "LOSS")
            if bar["high"] >= tp:
                return Trade("", side, entry, sl, tp, tp, i + 1, "WIN")
        else:
            if bar["high"] >= sl:
                return Trade("", side, entry, sl, tp, sl, i + 1, "LOSS")
            if bar["low"] <= tp:
                return Trade("", side, entry, sl, tp, tp, i + 1, "WIN")
    last_close = float(df_future["close"].iloc[-1])
    return Trade("", side, entry, sl, tp, last_close, len(df_future), "TIMEOUT")


def backtest_symbol(mt5_conn: MT5Connection, symbol_key: str) -> List[Trade]:
    cfg = SYMBOLS[symbol_key]
    df_t_raw = mt5_conn.get_candles(cfg.symbol, cfg.tf_trend, BARS_TO_TEST // 4)
    df_s_raw = mt5_conn.get_candles(cfg.symbol, cfg.tf_signal, BARS_TO_TEST)
    if df_t_raw is None or df_s_raw is None:
        log.warning("Sin datos para %s", cfg.symbol)
        return []

    df_t = add_indicators(df_t_raw, STRATEGY["ema_fast"], STRATEGY["ema_slow"],
                          STRATEGY["rsi_period"], STRATEGY["atr_period"])
    df_s = add_indicators(df_s_raw, STRATEGY["ema_fast"], STRATEGY["ema_slow"],
                          STRATEGY["rsi_period"], STRATEGY["atr_period"])

    trades: List[Trade] = []
    warmup = max(STRATEGY["ema_slow"], 50)

    for i in range(warmup, len(df_s) - MAX_HOLD):
        df_s_slice = df_s.iloc[: i + 1]
        # Para tendencia, alineamos por timestamp: tomamos las velas H1 hasta el time de df_s[i]
        cur_time = df_s.iloc[i]["time"]
        df_t_slice = df_t[df_t["time"] <= cur_time]
        if len(df_t_slice) < warmup:
            continue

        trend = _trend_direction(df_t_slice)
        if trend is None:
            continue
        side = _momentum_signal(df_s_slice, cfg.rsi_low, cfg.rsi_high)
        if side is None:
            continue
        if (side == "BUY" and trend != "up") or (side == "SELL" and trend != "down"):
            continue
        struct = _structure_confirmation(df_s_slice, side, STRATEGY["structure_lookback"])
        if struct is None:
            continue

        last = df_s_slice.iloc[-1]
        atr_v = float(last["atr"])
        if pd.isna(atr_v) or atr_v <= 0:
            continue
        entry = float(last["close"])
        if side == "BUY":
            sl, tp = entry - 1.5 * atr_v, entry + 3.0 * atr_v
        else:
            sl, tp = entry + 1.5 * atr_v, entry - 3.0 * atr_v

        df_future = df_s.iloc[i + 1: i + 1 + MAX_HOLD]
        t = simulate_trade(df_future, side, entry, sl, tp)
        t.symbol = cfg.symbol
        trades.append(t)

    return trades


def report(trades: List[Trade], label: str):
    if not trades:
        print(f"\n{label}: sin operaciones generadas.")
        return
    wins = sum(1 for t in trades if t.result == "WIN")
    losses = sum(1 for t in trades if t.result == "LOSS")
    timeouts = sum(1 for t in trades if t.result == "TIMEOUT")
    total_closed = wins + losses
    wr = (wins / total_closed * 100) if total_closed else 0
    # Expectativa con RR 1:2: edge = winrate*2 - lossrate*1
    expectancy = (wins * 2 - losses * 1) / len(trades) if trades else 0
    print(f"\n=== {label} ===")
    print(f"Total señales: {len(trades)}")
    print(f"Wins:   {wins}")
    print(f"Losses: {losses}")
    print(f"Timeouts: {timeouts}")
    print(f"Win rate (cerradas): {wr:.1f}%")
    print(f"Expectativa por trade (R): {expectancy:.2f}R")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("symbol", nargs="?", help="Símbolo a testear (ej. EURUSD)")
    parser.add_argument("--all", action="store_true", help="Testea todos los símbolos")
    args = parser.parse_args()

    load_dotenv()
    conn = MT5Connection(
        login=int(os.getenv("MT5_LOGIN", "0")),
        password=os.getenv("MT5_PASSWORD", ""),
        server=os.getenv("MT5_SERVER", ""),
        path=os.getenv("MT5_PATH") or None,
    )
    if not conn.connect():
        log.error("No se pudo conectar a MT5.")
        sys.exit(1)

    try:
        if args.all:
            all_trades = []
            for key in SYMBOLS:
                log.info("Backtesteando %s...", key)
                trades = backtest_symbol(conn, key)
                report(trades, key)
                all_trades.extend(trades)
            report(all_trades, "GLOBAL")
        elif args.symbol:
            if args.symbol not in SYMBOLS:
                log.error("Símbolo %s no está en config.SYMBOLS", args.symbol)
                sys.exit(1)
            trades = backtest_symbol(conn, args.symbol)
            report(trades, args.symbol)
        else:
            parser.print_help()
    finally:
        conn.disconnect()


if __name__ == "__main__":
    main()
