"""Lógica de confluencia de 3 capas: tendencia + momentum + estructura."""
from __future__ import annotations
from dataclasses import dataclass
from typing import Optional
import pandas as pd

from config import STRATEGY, SymbolConfig
from indicators import (
    add_indicators,
    breaks_resistance, breaks_support,
    is_bullish_engulfing, is_bearish_engulfing,
    is_bullish_pin_bar, is_bearish_pin_bar,
)


@dataclass
class Signal:
    symbol: str
    side: str            # "BUY" o "SELL"
    price: float
    sl: float            # stop loss sugerido (basado en ATR)
    tp: float            # take profit sugerido (RR 1:2)
    rsi: float
    atr: float
    reasons: list        # qué disparó la señal
    timeframe: str


def _trend_direction(df_trend: pd.DataFrame) -> Optional[str]:
    """Devuelve 'up', 'down' o None según EMA50 vs EMA200 en el TF de tendencia."""
    last = df_trend.iloc[-1]
    if pd.isna(last["ema_fast"]) or pd.isna(last["ema_slow"]):
        return None
    if last["ema_fast"] > last["ema_slow"] and last["close"] > last["ema_fast"]:
        return "up"
    if last["ema_fast"] < last["ema_slow"] and last["close"] < last["ema_fast"]:
        return "down"
    return None


def _momentum_signal(df_sig: pd.DataFrame, rsi_low: int, rsi_high: int) -> Optional[str]:
    """
    Señal temprana: RSI saliendo de zona extrema.
    BUY si RSI cruzó de <rsi_low a >rsi_low en las últimas 2 velas.
    SELL espejo.
    """
    if len(df_sig) < 3:
        return None
    rsi_prev = df_sig["rsi"].iloc[-2]
    rsi_now = df_sig["rsi"].iloc[-1]
    if pd.isna(rsi_prev) or pd.isna(rsi_now):
        return None
    # Cruce al alza desde sobreventa
    if rsi_prev < rsi_low <= rsi_now:
        return "BUY"
    # Cruce a la baja desde sobrecompra
    if rsi_prev > rsi_high >= rsi_now:
        return "SELL"
    # También aceptamos si RSI viene saliendo (estuvo extremo en últimas 5 velas y ahora se recupera)
    recent = df_sig["rsi"].iloc[-5:-1]
    if recent.min() < rsi_low and rsi_now > rsi_low + 3 and rsi_now < 50:
        return "BUY"
    if recent.max() > rsi_high and rsi_now < rsi_high - 3 and rsi_now > 50:
        return "SELL"
    return None


def _structure_confirmation(df_sig: pd.DataFrame, side: str, lookback: int) -> Optional[str]:
    """Devuelve la razón estructural si hay confirmación, None si no."""
    if side == "BUY":
        if breaks_resistance(df_sig, lookback):
            return "ruptura de resistencia"
        if is_bullish_engulfing(df_sig):
            return "envolvente alcista"
        if is_bullish_pin_bar(df_sig):
            return "pin bar alcista"
    else:
        if breaks_support(df_sig, lookback):
            return "ruptura de soporte"
        if is_bearish_engulfing(df_sig):
            return "envolvente bajista"
        if is_bearish_pin_bar(df_sig):
            return "pin bar bajista"
    return None


def evaluate(symbol_cfg: SymbolConfig,
             df_trend: pd.DataFrame,
             df_signal: pd.DataFrame) -> Optional[Signal]:
    """
    Aplica las 3 capas. Devuelve Signal si las 3 coinciden, None si no.
    df_trend: velas del TF de tendencia (H1 por defecto)
    df_signal: velas del TF de señal (M15 por defecto)
    """
    df_t = add_indicators(df_trend,
                          STRATEGY["ema_fast"], STRATEGY["ema_slow"],
                          STRATEGY["rsi_period"], STRATEGY["atr_period"])
    df_s = add_indicators(df_signal,
                          STRATEGY["ema_fast"], STRATEGY["ema_slow"],
                          STRATEGY["rsi_period"], STRATEGY["atr_period"])

    # Capa 1: tendencia
    trend = _trend_direction(df_t)
    if trend is None:
        return None

    # Capa 2: momentum (señal temprana)
    side = _momentum_signal(df_s, symbol_cfg.rsi_low, symbol_cfg.rsi_high)
    if side is None:
        return None
    # Debe coincidir con la tendencia macro
    if (side == "BUY" and trend != "up") or (side == "SELL" and trend != "down"):
        return None

    # Capa 3: confirmación estructural
    structure_reason = _structure_confirmation(df_s, side, STRATEGY["structure_lookback"])
    if structure_reason is None:
        return None

    last = df_s.iloc[-1]
    price = float(last["close"])
    atr_val = float(last["atr"])
    if pd.isna(atr_val) or atr_val <= 0:
        return None

    # SL: 1.5x ATR del lado opuesto. TP: RR 1:2.
    if side == "BUY":
        sl = price - 1.5 * atr_val
        tp = price + 3.0 * atr_val
    else:
        sl = price + 1.5 * atr_val
        tp = price - 3.0 * atr_val

    return Signal(
        symbol=symbol_cfg.symbol,
        side=side,
        price=price,
        sl=round(sl, 5),
        tp=round(tp, 5),
        rsi=round(float(last["rsi"]), 2),
        atr=round(atr_val, 5),
        reasons=[
            f"tendencia {trend.upper()} en {symbol_cfg.tf_trend}",
            f"RSI {round(float(last['rsi']), 1)} ({'sobreventa→' if side=='BUY' else 'sobrecompra→'}recuperando)",
            structure_reason,
        ],
        timeframe=symbol_cfg.tf_signal,
    )
