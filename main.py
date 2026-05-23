"""Loop principal del screener: escanea símbolos, evalúa estrategia, dispara alertas."""
from __future__ import annotations
import logging
import os
import sys
import time
from dotenv import load_dotenv

from config import SYMBOLS, STRATEGY
from data_fetcher import MT5Connection
from strategy import evaluate
from filters import is_session_active, spread_ok, volatility_ok, CooldownTracker
from alerts import TelegramAlerter, ConsoleAlerter
from indicators import add_indicators

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("screener")


def load_config():
    load_dotenv()
    cfg = {
        "mt5_login":       int(os.getenv("MT5_LOGIN", "0")),
        "mt5_password":    os.getenv("MT5_PASSWORD", ""),
        "mt5_server":      os.getenv("MT5_SERVER", ""),
        "mt5_path":        os.getenv("MT5_PATH") or None,
        "tg_token":        os.getenv("TELEGRAM_TOKEN", ""),
        "tg_chat":         os.getenv("TELEGRAM_CHAT_ID", ""),
        "scan_interval":   int(os.getenv("SCAN_INTERVAL", "300")),
        "mode":            os.getenv("MODE", "LIVE").upper(),
    }
    return cfg


def scan_once(mt5_conn: MT5Connection, alerter, cooldown: CooldownTracker):
    for name, sym_cfg in SYMBOLS.items():
        try:
            if not is_session_active(sym_cfg):
                continue

            info = mt5_conn.get_symbol_info(sym_cfg.symbol)
            if info is None:
                log.warning("Símbolo %s no encontrado en el broker (verifica el nombre).", sym_cfg.symbol)
                continue

            tick = mt5_conn.get_tick(sym_cfg.symbol)
            if not spread_ok(sym_cfg, tick, info.point):
                continue

            df_trend = mt5_conn.get_candles(sym_cfg.symbol, sym_cfg.tf_trend,
                                            STRATEGY["candles_to_fetch"])
            df_signal = mt5_conn.get_candles(sym_cfg.symbol, sym_cfg.tf_signal,
                                             STRATEGY["candles_to_fetch"])
            if df_trend is None or df_signal is None:
                continue

            # Pre-cálculo de indicadores para filtro de volatilidad
            df_signal_ind = add_indicators(
                df_signal,
                STRATEGY["ema_fast"], STRATEGY["ema_slow"],
                STRATEGY["rsi_period"], STRATEGY["atr_period"],
            )
            if not volatility_ok(sym_cfg, df_signal_ind):
                continue

            sig = evaluate(sym_cfg, df_trend, df_signal)
            if sig is None:
                continue

            key = f"{sig.symbol}:{sig.side}"
            if not cooldown.can_alert(key, sym_cfg.cooldown_min):
                log.info("Cooldown activo para %s, omitido.", key)
                continue

            if alerter.send_signal(sig):
                cooldown.mark(key)
                log.info("✅ Señal enviada: %s %s @ %s", sig.side, sig.symbol, sig.price)

        except Exception as e:
            log.exception("Error procesando %s: %s", name, e)


def main():
    cfg = load_config()

    if not cfg["mt5_login"] or not cfg["mt5_password"] or not cfg["mt5_server"]:
        log.error("Faltan credenciales MT5 en .env (MT5_LOGIN, MT5_PASSWORD, MT5_SERVER).")
        sys.exit(1)

    if cfg["mode"] == "LIVE":
        if not cfg["tg_token"] or not cfg["tg_chat"]:
            log.error("Modo LIVE pero faltan TELEGRAM_TOKEN o TELEGRAM_CHAT_ID en .env.")
            sys.exit(1)
        alerter = TelegramAlerter(cfg["tg_token"], cfg["tg_chat"])
        log.info("Modo LIVE — alertas a Telegram.")
    else:
        alerter = ConsoleAlerter()
        log.info("Modo DRY — alertas solo en consola.")

    mt5_conn = MT5Connection(
        login=cfg["mt5_login"],
        password=cfg["mt5_password"],
        server=cfg["mt5_server"],
        path=cfg["mt5_path"],
    )
    if not mt5_conn.connect():
        log.error("No se pudo conectar a MT5. Abortando.")
        sys.exit(1)

    cooldown = CooldownTracker()
    interval = cfg["scan_interval"]
    log.info("Iniciando loop de escaneo cada %ss para %d símbolos.", interval, len(SYMBOLS))

    try:
        while True:
            log.info("--- Nuevo ciclo de escaneo ---")
            scan_once(mt5_conn, alerter, cooldown)
            time.sleep(interval)
    except KeyboardInterrupt:
        log.info("Deteniendo screener.")
    finally:
        mt5_conn.disconnect()


if __name__ == "__main__":
    main()
