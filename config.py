"""Configuración central del screener: símbolos, parámetros por activo, sesiones."""
from dataclasses import dataclass, field
from typing import Dict


@dataclass
class SymbolConfig:
    symbol: str
    category: str          # "major", "cross", "metal", "index"
    tf_trend: str = "H1"   # timeframe para filtro de tendencia (EMA50/EMA200)
    tf_signal: str = "M15" # timeframe para la señal (RSI + estructura)
    rsi_low: int = 30
    rsi_high: int = 70
    atr_min: float = 0.0   # ATR mínimo en M15 para considerar el activo "vivo"
    max_spread: float = 0.0  # spread máximo aceptable (en pips/puntos del activo)
    sessions: tuple = ("london", "newyork")  # sesiones donde escanea
    cooldown_min: int = 60  # minutos antes de re-alertar el mismo símbolo


# Mapeo de nombres de símbolos en XM (algunos brokers usan sufijos, ajustá si hace falta)
SYMBOLS: Dict[str, SymbolConfig] = {
    # --- Majors ---
    "EURUSD": SymbolConfig("EURUSD", "major", atr_min=0.0008, max_spread=2.0),
    "GBPUSD": SymbolConfig("GBPUSD", "major", atr_min=0.0010, max_spread=2.5),
    "USDJPY": SymbolConfig("USDJPY", "major", atr_min=0.08,   max_spread=2.0),
    "USDCHF": SymbolConfig("USDCHF", "major", atr_min=0.0008, max_spread=2.5),
    "AUDUSD": SymbolConfig("AUDUSD", "major", atr_min=0.0007, max_spread=2.0,
                            sessions=("sydney", "london", "newyork")),
    "USDCAD": SymbolConfig("USDCAD", "major", atr_min=0.0008, max_spread=2.5),
    "NZDUSD": SymbolConfig("NZDUSD", "major", atr_min=0.0007, max_spread=2.5,
                            sessions=("sydney", "london", "newyork")),

    # --- Crosses (más volátiles, ajustamos RSI más agresivo) ---
    "EURJPY": SymbolConfig("EURJPY", "cross", rsi_low=25, rsi_high=75, atr_min=0.10),
    "GBPJPY": SymbolConfig("GBPJPY", "cross", rsi_low=25, rsi_high=75, atr_min=0.15),
    "EURGBP": SymbolConfig("EURGBP", "cross", atr_min=0.0005),
    "AUDJPY": SymbolConfig("AUDJPY", "cross", rsi_low=25, rsi_high=75, atr_min=0.08,
                            sessions=("sydney", "london", "newyork")),
    "CHFJPY": SymbolConfig("CHFJPY", "cross", rsi_low=25, rsi_high=75, atr_min=0.08),

    # --- Metales ---
    "XAUUSD": SymbolConfig("XAUUSD", "metal", tf_signal="M15", atr_min=1.5,
                            max_spread=35.0),

    # --- Índices (CFDs en XM, nombres exactos pueden variar: US30Cash, US100Cash, etc.) ---
    "US30":  SymbolConfig("US30",  "index", rsi_low=35, rsi_high=65, atr_min=15.0,
                           sessions=("newyork",)),
    "US100": SymbolConfig("US100", "index", rsi_low=35, rsi_high=65, atr_min=20.0,
                           sessions=("newyork",)),
    "GER40": SymbolConfig("GER40", "index", rsi_low=35, rsi_high=65, atr_min=10.0,
                           sessions=("london", "newyork")),
}


# Sesiones en hora UTC (XM usa servidor GMT+2/+3 según horario de verano,
# acá normalizamos todo a UTC; el módulo filters convierte la hora actual a UTC)
SESSIONS_UTC = {
    "sydney":  (21, 6),   # 21:00 → 06:00 UTC
    "tokyo":   (0,  9),
    "london":  (7,  16),
    "newyork": (12, 21),
}


# Parámetros generales de la estrategia
STRATEGY = {
    "ema_fast": 50,
    "ema_slow": 200,
    "rsi_period": 14,
    "atr_period": 14,
    "structure_lookback": 20,   # velas para detectar ruptura de máximo/mínimo
    "candles_to_fetch": 300,    # cuántas velas pedimos por consulta
}
