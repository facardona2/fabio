"""Envío de alertas a Telegram."""
from __future__ import annotations
import logging
import requests

from strategy import Signal

log = logging.getLogger(__name__)


def format_signal(sig: Signal) -> str:
    emoji = "🟢" if sig.side == "BUY" else "🔴"
    reasons = "\n".join(f"  • {r}" for r in sig.reasons)
    return (
        f"{emoji} *{sig.side} {sig.symbol}* ({sig.timeframe})\n"
        f"💲 Precio: `{sig.price}`\n"
        f"🛑 SL: `{sig.sl}`\n"
        f"🎯 TP: `{sig.tp}`\n"
        f"📊 RSI: {sig.rsi}  |  ATR: {sig.atr}\n"
        f"\n*Razones:*\n{reasons}"
    )


class TelegramAlerter:
    def __init__(self, token: str, chat_id: str):
        self.token = token
        self.chat_id = chat_id
        self.api = f"https://api.telegram.org/bot{token}/sendMessage"

    def send(self, text: str) -> bool:
        try:
            r = requests.post(
                self.api,
                json={
                    "chat_id": self.chat_id,
                    "text": text,
                    "parse_mode": "Markdown",
                    "disable_web_page_preview": True,
                },
                timeout=10,
            )
            if r.status_code != 200:
                log.error("Telegram respondió %s: %s", r.status_code, r.text)
                return False
            return True
        except requests.RequestException as e:
            log.error("Error enviando a Telegram: %s", e)
            return False

    def send_signal(self, sig: Signal) -> bool:
        return self.send(format_signal(sig))


class ConsoleAlerter:
    """Alerter de respaldo para modo DRY (no manda nada, solo imprime)."""
    def send(self, text: str) -> bool:
        print("\n" + "=" * 60)
        print(text)
        print("=" * 60)
        return True

    def send_signal(self, sig: Signal) -> bool:
        return self.send(format_signal(sig))
