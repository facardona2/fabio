"""Filtros de calidad: sesión activa, spread, volatilidad, cooldown."""
from __future__ import annotations
from datetime import datetime, timezone, timedelta
from typing import Dict
import pandas as pd

from config import SESSIONS_UTC, SymbolConfig


def is_session_active(symbol_cfg: SymbolConfig, now_utc: datetime | None = None) -> bool:
    if not symbol_cfg.sessions:
        return True
    now = now_utc or datetime.now(timezone.utc)
    hour = now.hour
    for s in symbol_cfg.sessions:
        start, end = SESSIONS_UTC[s]
        if start <= end:
            if start <= hour < end:
                return True
        else:  # cruza medianoche (ej. Sydney)
            if hour >= start or hour < end:
                return True
    return False


def spread_ok(symbol_cfg: SymbolConfig, tick, point: float) -> bool:
    """tick.ask - tick.bid en 'puntos' del símbolo. point lo da symbol_info.point."""
    if tick is None or point == 0 or symbol_cfg.max_spread == 0:
        return True
    spread_pts = (tick.ask - tick.bid) / point
    # Convertimos a "pips" para FX (1 pip = 10 puntos en brokers de 5 dígitos).
    # Para oro/índices el max_spread del config ya está en la unidad nativa, así que comparamos en puntos.
    if symbol_cfg.category in ("metal", "index"):
        return (tick.ask - tick.bid) <= symbol_cfg.max_spread
    pips = spread_pts / 10.0
    return pips <= symbol_cfg.max_spread


def volatility_ok(symbol_cfg: SymbolConfig, df_signal: pd.DataFrame) -> bool:
    """Comprueba que el ATR del último bar supera el mínimo configurado."""
    if symbol_cfg.atr_min == 0 or "atr" not in df_signal.columns:
        return True
    last_atr = df_signal["atr"].iloc[-1]
    if pd.isna(last_atr):
        return False
    return float(last_atr) >= symbol_cfg.atr_min


class CooldownTracker:
    """Evita spam: no re-alerta el mismo símbolo/lado antes de N minutos."""
    def __init__(self):
        self._last: Dict[str, datetime] = {}

    def can_alert(self, key: str, cooldown_min: int) -> bool:
        now = datetime.now(timezone.utc)
        last = self._last.get(key)
        if last is None:
            return True
        return (now - last) >= timedelta(minutes=cooldown_min)

    def mark(self, key: str):
        self._last[key] = datetime.now(timezone.utc)
