"""Indicadores técnicos y detección de patrones de velas."""
from __future__ import annotations
import numpy as np
import pandas as pd


def ema(series: pd.Series, period: int) -> pd.Series:
    return series.ewm(span=period, adjust=False).mean()


def rsi(series: pd.Series, period: int = 14) -> pd.Series:
    delta = series.diff()
    gain = delta.clip(lower=0)
    loss = -delta.clip(upper=0)
    avg_gain = gain.ewm(alpha=1 / period, adjust=False).mean()
    avg_loss = loss.ewm(alpha=1 / period, adjust=False).mean()
    rs = avg_gain / avg_loss.replace(0, np.nan)
    return 100 - (100 / (1 + rs))


def atr(df: pd.DataFrame, period: int = 14) -> pd.Series:
    high, low, close = df["high"], df["low"], df["close"]
    prev_close = close.shift(1)
    tr = pd.concat([
        high - low,
        (high - prev_close).abs(),
        (low - prev_close).abs(),
    ], axis=1).max(axis=1)
    return tr.ewm(alpha=1 / period, adjust=False).mean()


def add_indicators(df: pd.DataFrame, ema_fast: int, ema_slow: int,
                   rsi_period: int, atr_period: int) -> pd.DataFrame:
    df = df.copy()
    df["ema_fast"] = ema(df["close"], ema_fast)
    df["ema_slow"] = ema(df["close"], ema_slow)
    df["rsi"] = rsi(df["close"], rsi_period)
    df["atr"] = atr(df, atr_period)
    return df


# ---------- Patrones de velas ----------

def is_bullish_engulfing(df: pd.DataFrame, i: int = -1) -> bool:
    """Vela i envuelve cuerpo de vela i-1 al alza."""
    if len(df) < 2:
        return False
    prev, cur = df.iloc[i - 1], df.iloc[i]
    return (prev["close"] < prev["open"] and
            cur["close"] > cur["open"] and
            cur["close"] > prev["open"] and
            cur["open"] < prev["close"])


def is_bearish_engulfing(df: pd.DataFrame, i: int = -1) -> bool:
    if len(df) < 2:
        return False
    prev, cur = df.iloc[i - 1], df.iloc[i]
    return (prev["close"] > prev["open"] and
            cur["close"] < cur["open"] and
            cur["close"] < prev["open"] and
            cur["open"] > prev["close"])


def is_bullish_pin_bar(df: pd.DataFrame, i: int = -1) -> bool:
    """Mecha inferior >= 2x cuerpo, cuerpo en el tercio superior."""
    c = df.iloc[i]
    body = abs(c["close"] - c["open"])
    if body == 0:
        return False
    lower_wick = min(c["open"], c["close"]) - c["low"]
    upper_wick = c["high"] - max(c["open"], c["close"])
    return lower_wick >= 2 * body and upper_wick <= body


def is_bearish_pin_bar(df: pd.DataFrame, i: int = -1) -> bool:
    c = df.iloc[i]
    body = abs(c["close"] - c["open"])
    if body == 0:
        return False
    upper_wick = c["high"] - max(c["open"], c["close"])
    lower_wick = min(c["open"], c["close"]) - c["low"]
    return upper_wick >= 2 * body and lower_wick <= body


def breaks_resistance(df: pd.DataFrame, lookback: int) -> bool:
    """Última vela cierra por encima del máximo de las `lookback` velas previas."""
    if len(df) < lookback + 1:
        return False
    prev_high = df["high"].iloc[-lookback - 1:-1].max()
    return df["close"].iloc[-1] > prev_high


def breaks_support(df: pd.DataFrame, lookback: int) -> bool:
    if len(df) < lookback + 1:
        return False
    prev_low = df["low"].iloc[-lookback - 1:-1].min()
    return df["close"].iloc[-1] < prev_low
