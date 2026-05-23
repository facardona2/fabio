"""Conexión a MetaTrader 5 y descarga de velas."""
from __future__ import annotations
import logging
from typing import Optional
import pandas as pd

try:
    import MetaTrader5 as mt5
except ImportError:
    mt5 = None

log = logging.getLogger(__name__)

# Mapeo de timeframes string -> constante MT5
_TF_MAP = {
    "M1":  "TIMEFRAME_M1",
    "M5":  "TIMEFRAME_M5",
    "M15": "TIMEFRAME_M15",
    "M30": "TIMEFRAME_M30",
    "H1":  "TIMEFRAME_H1",
    "H4":  "TIMEFRAME_H4",
    "D1":  "TIMEFRAME_D1",
}


def _tf(tf_str: str):
    if mt5 is None:
        raise RuntimeError("MetaTrader5 no está instalado. pip install MetaTrader5 (solo Windows).")
    return getattr(mt5, _TF_MAP[tf_str])


class MT5Connection:
    def __init__(self, login: int, password: str, server: str, path: Optional[str] = None):
        self.login = login
        self.password = password
        self.server = server
        self.path = path
        self.connected = False

    def connect(self) -> bool:
        if mt5 is None:
            raise RuntimeError("MetaTrader5 no está disponible.")
        ok = mt5.initialize(path=self.path) if self.path else mt5.initialize()
        if not ok:
            log.error("mt5.initialize falló: %s", mt5.last_error())
            return False
        authorized = mt5.login(self.login, password=self.password, server=self.server)
        if not authorized:
            log.error("Login MT5 falló: %s", mt5.last_error())
            mt5.shutdown()
            return False
        self.connected = True
        info = mt5.account_info()
        if info:
            log.info("Conectado a %s — cuenta %s (%s %.2f)",
                     self.server, info.login, info.currency, info.balance)
        return True

    def disconnect(self):
        if mt5 is not None and self.connected:
            mt5.shutdown()
            self.connected = False

    def get_candles(self, symbol: str, timeframe: str, count: int = 300) -> Optional[pd.DataFrame]:
        """Devuelve un DataFrame con columnas: time, open, high, low, close, tick_volume."""
        rates = mt5.copy_rates_from_pos(symbol, _tf(timeframe), 0, count)
        if rates is None or len(rates) == 0:
            log.warning("Sin datos para %s %s: %s", symbol, timeframe, mt5.last_error())
            return None
        df = pd.DataFrame(rates)
        df["time"] = pd.to_datetime(df["time"], unit="s", utc=True)
        return df

    def get_tick(self, symbol: str):
        """Tick actual (bid, ask, last, time). Útil para calcular spread."""
        return mt5.symbol_info_tick(symbol)

    def get_symbol_info(self, symbol: str):
        info = mt5.symbol_info(symbol)
        if info is None:
            return None
        if not info.visible:
            # Algunos símbolos hay que activarlos en Market Watch
            mt5.symbol_select(symbol, True)
            info = mt5.symbol_info(symbol)
        return info
