# XM Forex Screener

Screener inteligente para cuenta **XM (MetaTrader 5)** que envía alertas de compra/venta tempranas a **Telegram** usando confluencia de 3 capas (tendencia + momentum + estructura).

## Instrumentos monitoreados (16)

**Majors (7):** EURUSD, GBPUSD, USDJPY, USDCHF, AUDUSD, USDCAD, NZDUSD
**Crosses (5):** EURJPY, GBPJPY, EURGBP, AUDJPY, CHFJPY
**Metales (1):** XAUUSD
**Índices (3):** US30, US100, GER40

## Estrategia: Confluencia de 3 capas

Solo genera señal cuando coinciden las **3 condiciones**:

1. **Tendencia macro** — EMA50 vs EMA200 en H1 define dirección (solo BUY si EMA50>EMA200, solo SELL al revés).
2. **Momentum temprano** — RSI en M15 saliendo de zona extrema (cruce 30→35 para BUY, 70→65 para SELL).
3. **Confirmación de estructura** — precio rompe máximo/mínimo de las últimas N velas o vela de rechazo (engulfing / pin bar).

**Filtros adicionales:**
- Sesión activa (Londres + NY overlap por defecto)
- ATR mínimo por activo (evita rangos muertos)
- Spread máximo (evita ejecutar en horarios sucios)
- Cooldown por símbolo (no spamea la misma señal)

## Instalación

```bash
pip install -r requirements.txt
cp .env.example .env
# Editar .env con tus credenciales (cuenta XM + bot Telegram)
python main.py
```

## Estructura

```
xm-forex-screener/
├── config.py           # Símbolos, parámetros por activo, sesiones
├── data_fetcher.py     # Conexión MT5 y descarga de velas
├── indicators.py       # EMA, RSI, ATR, detección de patrones
├── strategy.py         # Lógica de confluencia 3 capas
├── filters.py          # Sesión, spread, volatilidad, cooldown
├── alerts.py           # Bot de Telegram
├── backtest.py         # Validación histórica
├── main.py             # Loop principal
└── requirements.txt
```

## Roadmap

- [x] MVP de alertas (esta versión)
- [ ] Backtest con 2 años de histórico
- [ ] Dashboard web con señales activas
- [ ] Ejecución automática de órdenes en MT5
- [ ] Gestión de riesgo dinámica (lotaje según ATR + saldo)

## Disclaimer

Esto es una herramienta educativa. **No es asesoría financiera.** Validá siempre con backtest antes de operar con dinero real. Empezá en cuenta DEMO.
