//+------------------------------------------------------------------+
//|                      ICT_Reversal_Pro.mq5                       |
//|    Multi-Timeframe ICT Reversal Indicator v2.0                  |
//|                                                                  |
//|  Based on ICT Concepts by Michael Huddleston                    |
//|                                                                  |
//|  CONCEPTOS IMPLEMENTADOS:                                        |
//|  ✓ Liquidity Sweeps / Turtle Soup (desde HTF ≥ 4H)             |
//|  ✓ Fair Value Gaps (FVG) desde HTF                             |
//|  ✓ Order Blocks (OB) desde HTF                                 |
//|  ✓ Breaker Blocks (OBs que giran de rol)                       |
//|  ✓ Kill Zones: Asian, London, NY AM, NY PM                     |
//|  ✓ Previous Day High/Low (PDH/PDL)                             |
//|  ✓ Previous Week High/Low (PWH/PWL)                            |
//|  ✓ Change of Character (CHOCH / MSS)                           |
//|  ✓ Equal Highs/Lows (Liquidity Magnets)                        |
//|  ✓ Buy-Side / Sell-Side Liquidity (BSL/SSL)                    |
//|  ✓ Premium & Discount (con zona OTE 61.8-79%)                  |
//|  ✓ Power of 3: Accumulation-Manipulation-Distribution           |
//+------------------------------------------------------------------+
#property copyright   "ICT Concepts - Michael Huddleston"
#property link        ""
#property version     "2.00"
#property indicator_chart_window
#property indicator_buffers 8
#property indicator_plots   4

// Señal 1: Reversión por Liquidity Sweep (Turtle Soup Alcista)
#property indicator_label1  "Bull Turtle Soup ▲"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLime
#property indicator_width1  3

// Señal 2: Reversión por Liquidity Sweep (Turtle Soup Bajista)
#property indicator_label2  "Bear Turtle Soup ▼"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_width2  3

// Señal 3: Reversión por OB o FVG (Alcista)
#property indicator_label3  "Bull OB/FVG ▲"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrDeepSkyBlue
#property indicator_width3  2

// Señal 4: Reversión por OB o FVG (Bajista)
#property indicator_label4  "Bear OB/FVG ▼"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrOrangeRed
#property indicator_width4  2

//=================================================================
//  PARÁMETROS DE ENTRADA
//=================================================================
input group "══════ TEMPORALIDADES ══════"
input ENUM_TIMEFRAMES InpHTF       = PERIOD_H4;   // Temporalidad Principal (mín H4)
input ENUM_TIMEFRAMES InpHTF2      = PERIOD_D1;   // Temporalidad Secundaria

input group "══════ DETECCIÓN DE SWINGS ══════"
input int   InpSwingStr    = 5;   // Fuerza del pivote (barras a cada lado)
input int   InpSwingLook   = 60;  // Lookback HTF (barras)
input int   InpEQHTol      = 5;   // Tolerancia Equal Highs/Lows (pips)

input group "══════ KILL ZONES (Hora Servidor GMT) ══════"
input bool  InpShowKZ      = true;  // Mostrar Kill Zones
input bool  InpKZFilter    = true;  // Señales SOLO en Kill Zones
input int   InpAsianH1     = 21;   // Asian KZ inicio (hora GMT)
input int   InpAsianH2     = 0;    // Asian KZ fin (hora GMT)
input int   InpLondonH1    = 2;    // London KZ inicio (hora GMT)
input int   InpLondonH2    = 5;    // London KZ fin (hora GMT)
input int   InpNYH1        = 7;    // NY AM KZ inicio (hora GMT)
input int   InpNYH2        = 10;   // NY AM KZ fin (hora GMT)
input int   InpNYPmH1      = 13;   // NY PM/London Close KZ inicio
input int   InpNYPmH2      = 16;   // NY PM/London Close KZ fin

input group "══════ ELEMENTOS VISUALES ══════"
input bool  InpShowOB      = true;  // Mostrar Order Blocks
input bool  InpShowFVG     = true;  // Mostrar Fair Value Gaps
input bool  InpShowLiq     = true;  // Mostrar Niveles de Liquidez
input bool  InpShowPDHL    = true;  // Mostrar PDH/PDL (Prev Day High/Low)
input bool  InpShowPWHL    = true;  // Mostrar PWH/PWL (Prev Week High/Low)
input bool  InpShowCHOCH   = true;  // Mostrar CHOCH / MSS
input bool  InpShowOTE     = false; // Mostrar OTE (61.8-79% Fib)
input bool  InpShowLabels  = true;  // Mostrar etiquetas en señales
input int   InpMaxBars     = 500;   // Barras máximas a calcular

input group "══════ FILTROS DE SEÑAL ══════"
input double InpMinFVGPips  = 5.0;  // FVG mínimo en pips
input double InpDispFactor  = 1.5;  // Factor de desplazamiento para OB
input int    InpSweepPips   = 2;    // Pips mínimos del sweep

input group "══════ COLORES ══════"
input color InpBullOBCol   = C'0,90,20';         // Order Block Alcista
input color InpBearOBCol   = C'90,0,20';         // Order Block Bajista
input color InpBreakerCol  = C'80,0,80';         // Breaker Block
input color InpBullFVGCol  = C'0,60,120';        // FVG Alcista
input color InpBearFVGCol  = C'120,50,0';        // FVG Bajista
input color InpBSLCol      = clrGold;            // Buy-Side Liquidity
input color InpSSLCol      = clrSilver;          // Sell-Side Liquidity
input color InpEQHCol      = clrYellow;          // Equal Highs
input color InpEQLCol      = clrAqua;            // Equal Lows
input color InpAsianCol    = C'30,30,60';        // Asian Kill Zone
input color InpLondonCol   = C'0,55,30';         // London Kill Zone
input color InpNYCol       = C'60,30,0';         // NY Kill Zone
input color InpPDHCol      = clrCornflowerBlue;  // Prev Day High
input color InpPDLCol      = clrLightCoral;      // Prev Day Low
input color InpPWHCol      = C'80,80,180';       // Prev Week High
input color InpPWLCol      = C'180,80,80';       // Prev Week Low
input color InpCHOCHCol    = clrMagenta;         // CHOCH / MSS
input color InpOTECol      = C'80,80,0';         // OTE Zone

//=================================================================
//  ESTRUCTURAS
//=================================================================
struct SSwing
{
    double   price;
    datetime time;
    int      htfBar;
    bool     isHigh;
    bool     swept;
    bool     isEqual;   // Equal High/Low
};

struct SOB
{
    double   hi, lo;
    datetime t1;
    bool     bull;
    bool     broken;
    bool     isBreaker;
    bool     mitigated;
    string   name;
};

struct SFVG
{
    double   hi, lo;
    datetime t1;
    bool     bull;
    bool     filled;
    bool     isInverse;
    string   name;
};

struct SCHOCH
{
    double   price;
    datetime time;
    bool     bull;      // true = alcista CHOCH
    bool     isMSS;
    string   name;
};

//=================================================================
//  BUFFERS
//=================================================================
double BullLiqBuf[];    // Señal Turtle Soup alcista
double BearLiqBuf[];    // Señal Turtle Soup bajista
double BullOBFVGBuf[];  // Señal OB/FVG alcista
double BearOBFVGBuf[];  // Señal OB/FVG bajista
double DummyBuf1[];
double DummyBuf2[];
double DummyBuf3[];
double DummyBuf4[];

//=================================================================
//  VARIABLES GLOBALES
//=================================================================
SSwing  g_swings[];
SOB     g_obs[];
SFVG    g_fvgs[];
SCHOCH  g_chochs[];

string  PFXO = "ICTR_";     // Prefijo objetos
int     g_lastHTFBars = 0;
int     g_lastHTF2Bars = 0;
double  g_pip;              // Valor del pip

//=================================================================
//  INICIALIZACIÓN
//=================================================================
int OnInit()
{
    // Validar HTF
    if(PeriodSeconds(InpHTF) < PeriodSeconds(PERIOD_H4))
    {
        Alert("ICT Reversal Pro: La temporalidad debe ser H4 o mayor.");
        return INIT_FAILED;
    }
    if(PeriodSeconds(InpHTF) >= PeriodSeconds(InpHTF2))
    {
        Alert("ICT Reversal Pro: HTF2 debe ser mayor que HTF.");
        return INIT_FAILED;
    }

    // Calcular valor del pip
    g_pip = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    if(_Digits == 3 || _Digits == 5) g_pip *= 10;

    // Buffers de datos
    SetIndexBuffer(0, BullLiqBuf,   INDICATOR_DATA);
    SetIndexBuffer(1, BearLiqBuf,   INDICATOR_DATA);
    SetIndexBuffer(2, BullOBFVGBuf, INDICATOR_DATA);
    SetIndexBuffer(3, BearOBFVGBuf, INDICATOR_DATA);
    SetIndexBuffer(4, DummyBuf1,    INDICATOR_CALCULATIONS);
    SetIndexBuffer(5, DummyBuf2,    INDICATOR_CALCULATIONS);
    SetIndexBuffer(6, DummyBuf3,    INDICATOR_CALCULATIONS);
    SetIndexBuffer(7, DummyBuf4,    INDICATOR_CALCULATIONS);

    // Códigos de flechas (Wingdings)
    PlotIndexSetInteger(0, PLOT_ARROW, 233);  // ▲
    PlotIndexSetInteger(1, PLOT_ARROW, 234);  // ▼
    PlotIndexSetInteger(2, PLOT_ARROW, 217);  // △
    PlotIndexSetInteger(3, PLOT_ARROW, 218);  // ▽

    // Desplazamiento vertical para que la flecha no tape la vela
    PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, -10);
    PlotIndexSetInteger(1, PLOT_ARROW_SHIFT,  10);
    PlotIndexSetInteger(2, PLOT_ARROW_SHIFT, -8);
    PlotIndexSetInteger(3, PLOT_ARROW_SHIFT,  8);

    // Valor vacío
    for(int p = 0; p < 4; p++)
        PlotIndexSetDouble(p, PLOT_EMPTY_VALUE, 0.0);

    // Nombre corto
    IndicatorSetString(INDICATOR_SHORTNAME,
        "ICT Reversal Pro [" + EnumToString(InpHTF) + "/" +
        EnumToString(InpHTF2) + "]");

    ObjectsDeleteAll(0, PFXO);
    return INIT_SUCCEEDED;
}

//=================================================================
//  DESINICIALIZACIÓN
//=================================================================
void OnDeinit(const int reason)
{
    ObjectsDeleteAll(0, PFXO);
}

//=================================================================
//  CÁLCULO PRINCIPAL
//=================================================================
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    if(rates_total < 100) return 0;

    bool fullCalc = (prev_calculated == 0 ||
                     rates_total - prev_calculated > 5);

    // Arrays como series (índice 0 = barra más reciente)
    ArraySetAsSeries(time,  true);
    ArraySetAsSeries(open,  true);
    ArraySetAsSeries(high,  true);
    ArraySetAsSeries(low,   true);
    ArraySetAsSeries(close, true);

    if(fullCalc)
    {
        ObjectsDeleteAll(0, PFXO);
        ArrayResize(g_swings, 0);
        ArrayResize(g_obs,    0);
        ArrayResize(g_fvgs,   0);
        ArrayResize(g_chochs, 0);
        ArrayInitialize(BullLiqBuf,   0);
        ArrayInitialize(BearLiqBuf,   0);
        ArrayInitialize(BullOBFVGBuf, 0);
        ArrayInitialize(BearOBFVGBuf, 0);
        g_lastHTFBars = 0;
        g_lastHTF2Bars = 0;
    }

    // Verificar si hay nuevas barras HTF (para redibujar niveles)
    int curHTFBars  = Bars(_Symbol, InpHTF);
    int curHTF2Bars = Bars(_Symbol, InpHTF2);
    bool rebuildHTF = (curHTFBars != g_lastHTFBars || curHTF2Bars != g_lastHTF2Bars);

    if(fullCalc || rebuildHTF)
    {
        // Cargar datos HTF
        int htfCnt = MathMin(InpSwingLook + 30, 300);
        MqlRates r1[], r2[];
        int n1 = CopyRates(_Symbol, InpHTF,  0, htfCnt, r1);
        int n2 = CopyRates(_Symbol, InpHTF2, 0, MathMin(60, 200), r2);

        if(n1 >= 10)
        {
            // Reconstruir análisis HTF
            ArrayResize(g_swings, 0);
            ArrayResize(g_obs,    0);
            ArrayResize(g_fvgs,   0);

            BuildSwings(r1, n1);
            MarkEqualHL();
            BuildOBs(r1, n1);
            BuildFVGs(r1, n1);
            if(n2 >= 5)
                BuildSwingsHTF2(r2, n2);
        }

        // Redibujar elementos estáticos
        if(InpShowLiq)   DrawLiqLines(time[0]);
        if(InpShowOB)    DrawOBBoxes(time[0]);
        if(InpShowFVG)   DrawFVGBoxes(time[0]);
        if(InpShowPDHL)  DrawPrevDayHL(time[0]);
        if(InpShowPWHL)  DrawPrevWeekHL(time[0]);
        if(InpShowKZ)    DrawKillZones(time, rates_total);

        g_lastHTFBars  = curHTFBars;
        g_lastHTF2Bars = curHTF2Bars;
    }

    // CHOCH en TF actual (se recalcula siempre)
    if(InpShowCHOCH)
    {
        ArrayResize(g_chochs, 0);
        DetectCHOCH(time, high, low, close, rates_total);
        DrawCHOCHMarkers(time[0]);
    }

    // ——— BUCLE PRINCIPAL DE SEÑALES ———
    int scanLim = fullCalc ? MathMin(rates_total - 2, InpMaxBars) : 3;

    for(int i = scanLim; i >= 2; i--)
    {
        int idx = rates_total - 1 - i;   // Índice en el buffer
        if(idx < 0 || idx >= rates_total) continue;

        // Inicializar
        BullLiqBuf[idx]   = 0;
        BearLiqBuf[idx]   = 0;
        BullOBFVGBuf[idx] = 0;
        BearOBFVGBuf[idx] = 0;

        bool inKZ = IsKillZone(time[i]);
        if(InpKZFilter && !inKZ) continue;

        // ══ A. Turtle Soup / Liquidity Sweep ══
        int liqSig = CheckTurtleSoup(i, time, high, low, close, open, rates_total);
        if(liqSig == 1)
        {
            BullLiqBuf[idx] = low[i] - g_pip * 3;
            if(InpShowLabels)
                DrawSignalLabel(PFXO + "SIG_BL_" + IntegerToString(idx),
                    time[i], low[i] - g_pip * 8,
                    "LIQ Bull", InpBSSLSignalColor(true), true);
        }
        else if(liqSig == -1)
        {
            BearLiqBuf[idx] = high[i] + g_pip * 3;
            if(InpShowLabels)
                DrawSignalLabel(PFXO + "SIG_BrL_" + IntegerToString(idx),
                    time[i], high[i] + g_pip * 8,
                    "LIQ Bear", InpBSSLSignalColor(false), false);
        }

        // ══ B. Order Block / FVG Reversal ══
        if(liqSig == 0)
        {
            string sigType = "";
            int obSig = CheckOBFVGReversal(i, time, high, low, close, open, sigType);
            if(obSig == 1)
            {
                BullOBFVGBuf[idx] = low[i] - g_pip * 3;
                if(InpShowLabels)
                    DrawSignalLabel(PFXO + "SIG_BO_" + IntegerToString(idx),
                        time[i], low[i] - g_pip * 8,
                        sigType + " Bull", clrDeepSkyBlue, true);
            }
            else if(obSig == -1)
            {
                BearOBFVGBuf[idx] = high[i] + g_pip * 3;
                if(InpShowLabels)
                    DrawSignalLabel(PFXO + "SIG_BrO_" + IntegerToString(idx),
                        time[i], high[i] + g_pip * 8,
                        sigType + " Bear", clrOrangeRed, false);
            }
        }
    }

    return rates_total;
}

//=================================================================
//  HELPERS DE COLOR
//=================================================================
color InpBSSLSignalColor(bool bull) { return bull ? clrLime : clrRed; }

//=================================================================
//  CONSTRUCCIÓN DE SWINGS (HTF Principal)
//=================================================================
void BuildSwings(MqlRates &r[], int cnt)
{
    int str = MathMax(2, MathMin(InpSwingStr, 5));
    for(int i = str; i < cnt - str; i++)
    {
        bool isHi = true, isLo = true;
        for(int j = 1; j <= str; j++)
        {
            if(r[i].high <= r[i-j].high || r[i].high <= r[i+j].high) isHi = false;
            if(r[i].low  >= r[i-j].low  || r[i].low  >= r[i+j].low ) isLo = false;
        }
        if(!isHi && !isLo) continue;

        int sz = ArraySize(g_swings);
        ArrayResize(g_swings, sz + 1);
        g_swings[sz].price   = isHi ? r[i].high : r[i].low;
        g_swings[sz].time    = r[i].time;
        g_swings[sz].htfBar  = i;
        g_swings[sz].isHigh  = isHi;
        g_swings[sz].swept   = false;
        g_swings[sz].isEqual = false;
    }
}

//=================================================================
//  CONSTRUCCIÓN DE SWINGS (HTF2 Secundario)
//=================================================================
void BuildSwingsHTF2(MqlRates &r[], int cnt)
{
    int str = MathMax(3, InpSwingStr);
    for(int i = str; i < cnt - str; i++)
    {
        bool isHi = true, isLo = true;
        for(int j = 1; j <= str; j++)
        {
            if(r[i].high <= r[i-j].high || r[i].high <= r[i+j].high) isHi = false;
            if(r[i].low  >= r[i-j].low  || r[i].low  >= r[i+j].low ) isLo = false;
        }
        if(!isHi && !isLo) continue;

        // Verificar que no está duplicado
        double swPrice = isHi ? r[i].high : r[i].low;
        bool dup = false;
        for(int k = 0; k < ArraySize(g_swings); k++)
        {
            if(MathAbs(g_swings[k].price - swPrice) < g_pip * 5) { dup = true; break; }
        }
        if(dup) continue;

        int sz = ArraySize(g_swings);
        ArrayResize(g_swings, sz + 1);
        g_swings[sz].price   = swPrice;
        g_swings[sz].time    = r[i].time;
        g_swings[sz].htfBar  = i;
        g_swings[sz].isHigh  = isHi;
        g_swings[sz].swept   = false;
        g_swings[sz].isEqual = false;
    }
}

//=================================================================
//  MARCAR EQUAL HIGHS / EQUAL LOWS
//=================================================================
void MarkEqualHL()
{
    double tol = g_pip * InpEQHTol;
    int n = ArraySize(g_swings);
    for(int i = 0; i < n - 1; i++)
    {
        for(int j = i + 1; j < n; j++)
        {
            if(g_swings[i].isHigh == g_swings[j].isHigh &&
               MathAbs(g_swings[i].price - g_swings[j].price) <= tol)
            {
                g_swings[i].isEqual = true;
                g_swings[j].isEqual = true;
            }
        }
    }
}

//=================================================================
//  ORDER BLOCKS (HTF)
//=================================================================
void BuildOBs(MqlRates &r[], int cnt)
{
    for(int i = 1; i < cnt - 2; i++)
    {
        // ── BULLISH OB: última vela bajista antes de impulso alcista ──
        if(r[i].close < r[i].open)
        {
            // Confirmar impulso alcista: cierre de la siguiente vela por encima del máximo del OB
            bool impulse = (r[i-1].close > r[i].high);
            double bodySize = r[i].open - r[i].close;
            double moveSize = r[i-1].close - r[i].open;
            bool disp = (moveSize > bodySize * InpDispFactor);

            if(impulse || disp)
            {
                // Verificar que no hay un OB igual reciente
                bool dup = false;
                for(int k = 0; k < ArraySize(g_obs); k++)
                    if(g_obs[k].bull && MathAbs(g_obs[k].lo - r[i].low) < g_pip * 3) { dup = true; break; }
                if(!dup)
                {
                    int sz = ArraySize(g_obs);
                    ArrayResize(g_obs, sz + 1);
                    g_obs[sz].hi       = r[i].high;
                    g_obs[sz].lo       = MathMin(r[i].open, r[i].close); // Cuerpo del OB
                    g_obs[sz].t1       = r[i].time;
                    g_obs[sz].bull     = true;
                    g_obs[sz].broken   = false;
                    g_obs[sz].isBreaker = false;
                    g_obs[sz].mitigated = false;
                    g_obs[sz].name     = "";
                    // ¿Ya fue roto? (precio actual perforó por debajo del mínimo del OB)
                    if(r[0].low < r[i].low) g_obs[sz].broken = true;
                }
            }
        }

        // ── BEARISH OB: última vela alcista antes de impulso bajista ──
        if(r[i].close > r[i].open)
        {
            bool impulse = (r[i-1].close < r[i].low);
            double bodySize = r[i].close - r[i].open;
            double moveSize = r[i].open - r[i-1].close;
            bool disp = (moveSize > bodySize * InpDispFactor);

            if(impulse || disp)
            {
                bool dup = false;
                for(int k = 0; k < ArraySize(g_obs); k++)
                    if(!g_obs[k].bull && MathAbs(g_obs[k].hi - r[i].high) < g_pip * 3) { dup = true; break; }
                if(!dup)
                {
                    int sz = ArraySize(g_obs);
                    ArrayResize(g_obs, sz + 1);
                    g_obs[sz].hi       = MathMax(r[i].open, r[i].close); // Cuerpo del OB
                    g_obs[sz].lo       = r[i].low;
                    g_obs[sz].t1       = r[i].time;
                    g_obs[sz].bull     = false;
                    g_obs[sz].broken   = false;
                    g_obs[sz].isBreaker = false;
                    g_obs[sz].mitigated = false;
                    g_obs[sz].name     = "";
                    if(r[0].high > r[i].high) g_obs[sz].broken = true;
                }
            }
        }
    }

    // ── BREAKER BLOCKS: OBs rotos que giran de rol ──
    for(int k = 0; k < ArraySize(g_obs); k++)
    {
        if(g_obs[k].broken)
        {
            // Un bull OB roto se convierte en resistencia (Bearish Breaker)
            // Un bear OB roto se convierte en soporte (Bullish Breaker)
            g_obs[k].isBreaker = true;
            // El Breaker mantiene su zona pero cambia polaridad
        }
    }
}

//=================================================================
//  FAIR VALUE GAPS (HTF)
//=================================================================
void BuildFVGs(MqlRates &r[], int cnt)
{
    double minGap = g_pip * InpMinFVGPips;

    for(int i = 1; i < cnt - 1; i++)
    {
        // r[i+1] = más antigua, r[i] = media, r[i-1] = más reciente

        // ── BULLISH FVG: gap entre máximo de [i+1] y mínimo de [i-1] ──
        double gapLo = r[i+1].high;
        double gapHi = r[i-1].low;
        if(gapHi > gapLo && (gapHi - gapLo) >= minGap)
        {
            // Verificar que aún no ha sido llenado
            bool filled = false;
            for(int k = 0; k < i; k++)
                if(r[k].low <= gapLo) { filled = true; break; }

            if(!filled)
            {
                bool dup = false;
                for(int k = 0; k < ArraySize(g_fvgs); k++)
                    if(g_fvgs[k].bull && MathAbs(g_fvgs[k].lo - gapLo) < g_pip * 2) { dup = true; break; }
                if(!dup)
                {
                    int sz = ArraySize(g_fvgs);
                    ArrayResize(g_fvgs, sz + 1);
                    g_fvgs[sz].hi        = gapHi;
                    g_fvgs[sz].lo        = gapLo;
                    g_fvgs[sz].t1        = r[i+1].time;
                    g_fvgs[sz].bull      = true;
                    g_fvgs[sz].filled    = false;
                    g_fvgs[sz].isInverse = false;
                    g_fvgs[sz].name      = "";
                }
            }
        }

        // ── BEARISH FVG: gap entre mínimo de [i+1] y máximo de [i-1] ──
        gapLo = r[i-1].high;
        gapHi = r[i+1].low;
        if(gapHi > gapLo && (gapHi - gapLo) >= minGap)
        {
            bool filled = false;
            for(int k = 0; k < i; k++)
                if(r[k].high >= gapHi) { filled = true; break; }

            if(!filled)
            {
                bool dup = false;
                for(int k = 0; k < ArraySize(g_fvgs); k++)
                    if(!g_fvgs[k].bull && MathAbs(g_fvgs[k].hi - gapHi) < g_pip * 2) { dup = true; break; }
                if(!dup)
                {
                    int sz = ArraySize(g_fvgs);
                    ArrayResize(g_fvgs, sz + 1);
                    g_fvgs[sz].hi        = gapHi;
                    g_fvgs[sz].lo        = gapLo;
                    g_fvgs[sz].t1        = r[i+1].time;
                    g_fvgs[sz].bull      = false;
                    g_fvgs[sz].filled    = false;
                    g_fvgs[sz].isInverse = false;
                    g_fvgs[sz].name      = "";
                }
            }
        }
    }
}

//=================================================================
//  DETECTAR CHOCH / MSS EN TF ACTUAL
//=================================================================
void DetectCHOCH(const datetime &t[], const double &h[],
                 const double &l[], const double &c[], int total)
{
    // Necesitamos swings en TF actual
    int lookback = MathMin(50, total - 5);
    double lastSwHi = 0, lastSwLo = DBL_MAX;
    int    lastSwHiBar = -1, lastSwLoBar = -1;
    bool   prevTrendUp = true;
    int    str = 3;

    for(int i = lookback; i >= str + 1; i--)
    {
        // Detectar swing high/low local en TF actual
        bool shi = true, slo = true;
        for(int j = 1; j <= str; j++)
        {
            if(h[i] <= h[i-j] || h[i] <= h[i+j]) shi = false;
            if(l[i] >= l[i-j] || l[i] >= l[i+j]) slo = false;
        }

        if(shi)
        {
            // ¿El precio actual rompe por debajo del último swing high previo?
            // En un uptrend, un nuevo LH (Lower High) + break del HL → CHOCH bajista
            if(lastSwHi > 0 && h[i] < lastSwHi)
            {
                // Posible CHOCH bajista si la estructura era alcista
                if(c[i] < lastSwLo && lastSwLoBar > 0)
                {
                    // Break of previous Higher Low → Bearish CHOCH
                    int sz = ArraySize(g_chochs);
                    ArrayResize(g_chochs, sz + 1);
                    g_chochs[sz].price = lastSwLo;
                    g_chochs[sz].time  = t[lastSwLoBar];
                    g_chochs[sz].bull  = false;
                    g_chochs[sz].isMSS = false;
                    g_chochs[sz].name  = "";
                }
            }
            lastSwHi = h[i];
            lastSwHiBar = i;
        }

        if(slo)
        {
            // ¿Nuevo Higher Low después de un downtrend? → posible CHOCH alcista
            if(lastSwLo < DBL_MAX && l[i] > lastSwLo)
            {
                // Ruptura del último Lower High → Bullish CHOCH
                if(c[i] > lastSwHi && lastSwHiBar > 0)
                {
                    int sz = ArraySize(g_chochs);
                    ArrayResize(g_chochs, sz + 1);
                    g_chochs[sz].price = lastSwHi;
                    g_chochs[sz].time  = t[lastSwHiBar];
                    g_chochs[sz].bull  = true;
                    g_chochs[sz].isMSS = false;
                    g_chochs[sz].name  = "";
                }
            }
            lastSwLo = l[i];
            lastSwLoBar = i;
        }
    }
}

//=================================================================
//  KILL ZONE: ¿Estamos dentro?
//=================================================================
bool IsKillZone(datetime t)
{
    MqlDateTime dt;
    TimeToStruct(t, dt);
    int h = dt.hour;

    // Asian KZ (puede cruzar medianoche)
    if(InpAsianH1 > InpAsianH2)
    {
        if(h >= InpAsianH1 || h < InpAsianH2) return true;
    }
    else if(h >= InpAsianH1 && h < InpAsianH2) return true;

    if(h >= InpLondonH1 && h < InpLondonH2) return true;   // London
    if(h >= InpNYH1     && h < InpNYH2)     return true;   // NY AM
    if(h >= InpNYPmH1   && h < InpNYPmH2)   return true;   // NY PM

    return false;
}

string GetKZName(datetime t)
{
    MqlDateTime dt;
    TimeToStruct(t, dt);
    int h = dt.hour;

    if(InpAsianH1 > InpAsianH2)
    {
        if(h >= InpAsianH1 || h < InpAsianH2) return "Asian";
    }
    else if(h >= InpAsianH1 && h < InpAsianH2) return "Asian";

    if(h >= InpLondonH1 && h < InpLondonH2) return "London Open";
    if(h >= InpNYH1     && h < InpNYH2)     return "NY AM";
    if(h >= InpNYPmH1   && h < InpNYPmH2)   return "NY PM";
    return "";
}

//=================================================================
//  SEÑAL A: TURTLE SOUP / LIQUIDITY SWEEP
//=================================================================
int CheckTurtleSoup(int i,
                    const datetime &t[], const double &h[],
                    const double &l[], const double &c[], const double &o[],
                    int total)
{
    double atr = CalcATR(i, h, l, c, 14);
    if(atr <= 0) return 0;

    double minSweep = g_pip * InpSweepPips;
    int n = ArraySize(g_swings);

    for(int s = 0; s < n; s++)
    {
        if(g_swings[s].swept) continue;
        if(g_swings[s].time >= t[i]) continue;  // Nivel debe ser anterior

        double swP = g_swings[s].price;

        // ──── BULLISH TURTLE SOUP ────
        // El precio barre por debajo del SSL (swing low) y cierra de vuelta arriba
        if(!g_swings[s].isHigh)
        {
            bool swept    = (l[i] < swP - minSweep);           // Wick por debajo
            bool closeAbv = (c[i] > swP);                       // Cierre por encima
            bool bullCandle = (c[i] > o[i]);                    // Vela alcista
            bool wickRej  = ((o[i] - l[i]) > (c[i] - o[i]));  // Wick inferior largo

            if(swept && (closeAbv || (c[i] > swP - g_pip * 2)) && bullCandle)
            {
                g_swings[s].swept = true;
                return 1;   // Señal alcista
            }
        }

        // ──── BEARISH TURTLE SOUP ────
        // El precio barre por encima del BSL (swing high) y cierra de vuelta abajo
        if(g_swings[s].isHigh)
        {
            bool swept    = (h[i] > swP + minSweep);
            bool closeBel = (c[i] < swP);
            bool bearCandle = (c[i] < o[i]);
            bool wickRej  = ((h[i] - o[i]) > (o[i] - c[i]));

            if(swept && (closeBel || (c[i] < swP + g_pip * 2)) && bearCandle)
            {
                g_swings[s].swept = true;
                return -1;  // Señal bajista
            }
        }
    }
    return 0;
}

//=================================================================
//  SEÑAL B: ORDER BLOCK / FVG REVERSAL
//=================================================================
int CheckOBFVGReversal(int i,
                       const datetime &t[], const double &h[],
                       const double &l[], const double &c[], const double &o[],
                       string &sigType)
{
    double curH = h[i], curL = l[i], curC = c[i], curO = o[i];

    // ── Verificar Order Blocks ──
    for(int k = 0; k < ArraySize(g_obs); k++)
    {
        if(g_obs[k].t1 >= t[i]) continue;  // OB debe ser anterior

        // ── BULLISH OB / BULLISH BREAKER ──
        if(g_obs[k].bull && !g_obs[k].mitigated)
        {
            bool inZone  = (curL <= g_obs[k].hi && curH >= g_obs[k].lo);
            bool bullish = (curC > curO);
            bool aboveMid = (curC > (g_obs[k].lo + g_obs[k].hi) / 2.0);
            bool wickRej = ((curO - curL) > (curC - curO) * 0.5);

            if(inZone && bullish && (aboveMid || wickRej))
            {
                g_obs[k].mitigated = true;
                sigType = g_obs[k].isBreaker ? "BREAKER\nBull" : "OB Bull";
                return 1;
            }
        }

        // ── BEARISH OB / BEARISH BREAKER ──
        if(!g_obs[k].bull && !g_obs[k].mitigated)
        {
            bool inZone  = (curH >= g_obs[k].lo && curL <= g_obs[k].hi);
            bool bearish = (curC < curO);
            bool belowMid = (curC < (g_obs[k].lo + g_obs[k].hi) / 2.0);
            bool wickRej = ((curH - curO) > (curO - curC) * 0.5);

            if(inZone && bearish && (belowMid || wickRej))
            {
                g_obs[k].mitigated = true;
                sigType = g_obs[k].isBreaker ? "BREAKER\nBear" : "OB Bear";
                return -1;
            }
        }
    }

    // ── Verificar Fair Value Gaps ──
    for(int k = 0; k < ArraySize(g_fvgs); k++)
    {
        if(g_fvgs[k].t1 >= t[i]) continue;
        if(g_fvgs[k].filled) continue;

        // ── BULLISH FVG: precio retrocede al gap y rebota ──
        if(g_fvgs[k].bull)
        {
            bool inGap   = (curL <= g_fvgs[k].hi && curH >= g_fvgs[k].lo);
            bool bullish = (curC > curO);
            bool holdGap = (curC > g_fvgs[k].lo); // Cierra por encima del gap

            if(inGap && bullish && holdGap)
            {
                g_fvgs[k].filled = true;
                sigType = "FVG Bull";
                return 1;
            }
        }

        // ── BEARISH FVG: precio retrocede al gap y cae ──
        if(!g_fvgs[k].bull)
        {
            bool inGap   = (curH >= g_fvgs[k].lo && curL <= g_fvgs[k].hi);
            bool bearish = (curC < curO);
            bool holdGap = (curC < g_fvgs[k].hi);

            if(inGap && bearish && holdGap)
            {
                g_fvgs[k].filled = true;
                sigType = "FVG Bear";
                return -1;
            }
        }
    }

    return 0;
}

//=================================================================
//  ATR PARA FILTROS
//=================================================================
double CalcATR(int idx, const double &h[], const double &l[],
               const double &c[], int period)
{
    if(idx + period + 1 >= ArraySize(h)) return 0;
    double s = 0;
    for(int i = idx; i < idx + period; i++)
    {
        double tr = MathMax(h[i] - l[i],
                   MathMax(MathAbs(h[i] - c[i+1]),
                           MathAbs(l[i] - c[i+1])));
        s += tr;
    }
    return s / period;
}

//=================================================================
//  DIBUJO: KILL ZONES
//=================================================================
void DrawKillZones(const datetime &t[], int total)
{
    // Eliminar zonas previas
    for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
    {
        string nm = ObjectName(0, i);
        if(StringFind(nm, PFXO + "KZ") == 0) ObjectDelete(0, nm);
    }

    double bigHi = SymbolInfoDouble(_Symbol, SYMBOL_BID) * 10.0;
    double bigLo = 0.0001;

    string curKZ   = "";
    datetime kzSt  = 0;
    int kzCnt      = 0;
    int lim        = MathMin(total - 1, InpMaxBars);

    for(int i = lim; i >= 1; i--)
    {
        string kzName = GetKZName(t[i]);
        bool inKZ = (kzName != "");

        if(inKZ && curKZ == "")
        {
            kzSt  = t[i];
            curKZ = kzName;
        }
        else if((!inKZ || kzName != curKZ) && curKZ != "")
        {
            // Dibujar la zona
            string nm  = PFXO + "KZ_" + IntegerToString(kzCnt++);
            color  clr = (curKZ == "Asian")        ? InpAsianCol  :
                         (curKZ == "London Open")  ? InpLondonCol : InpNYCol;
            string tip = curKZ + " Kill Zone";

            ObjectCreate(0, nm, OBJ_RECTANGLE, 0,
                        kzSt, bigHi, t[i], bigLo);
            ObjectSetInteger(0, nm, OBJPROP_COLOR,  clr);
            ObjectSetInteger(0, nm, OBJPROP_STYLE,  STYLE_SOLID);
            ObjectSetInteger(0, nm, OBJPROP_FILL,   true);
            ObjectSetInteger(0, nm, OBJPROP_BACK,   true);
            ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
            ObjectSetString(0, nm,  OBJPROP_TOOLTIP, tip);

            // Etiqueta de la Kill Zone
            if(InpShowLabels)
            {
                string lnm = nm + "_L";
                double midTime = ((double)kzSt + (double)t[i]) / 2.0;
                ObjectCreate(0, lnm, OBJ_TEXT, 0,
                            (datetime)midTime, bigHi * 0.99);
                ObjectSetString(0, lnm, OBJPROP_TEXT, curKZ + " KZ");
                ObjectSetInteger(0, lnm, OBJPROP_COLOR,    ColorAdd(clr, 80));
                ObjectSetInteger(0, lnm, OBJPROP_FONTSIZE, 7);
                ObjectSetInteger(0, lnm, OBJPROP_HIDDEN,   true);
            }

            curKZ = inKZ ? kzName : "";
            kzSt  = inKZ ? t[i] : 0;
        }
    }
}

// Aclarar color (formato BGR interno de MT5: 0x00BBGGRR)
color ColorAdd(color c, int delta)
{
    int ch0 = MathMin(255, (int)((c >> 16) & 0xFF) + delta);
    int ch1 = MathMin(255, (int)((c >> 8)  & 0xFF) + delta);
    int ch2 = MathMin(255, (int)( c        & 0xFF)  + delta);
    return (color)((ch0 << 16) | (ch1 << 8) | ch2);
}

//=================================================================
//  DIBUJO: LÍNEAS DE LIQUIDEZ (BSL/SSL)
//=================================================================
void DrawLiqLines(datetime curTime)
{
    for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
    {
        string nm = ObjectName(0, i);
        if(StringFind(nm, PFXO + "LIQ") == 0) ObjectDelete(0, nm);
    }

    datetime extEnd = curTime + (datetime)(PeriodSeconds(PERIOD_H1) * 8);
    int n = ArraySize(g_swings);

    for(int s = 0; s < n; s++)
    {
        if(g_swings[s].swept) continue;

        string nm  = PFXO + "LIQ_" + IntegerToString(s);
        bool   isH = g_swings[s].isHigh;
        bool   isEq = g_swings[s].isEqual;
        color  clr  = isH ? InpBSLCol : InpSSLCol;
        if(isEq) clr = isH ? InpEQHCol : InpEQLCol;

        string label = isH ? (isEq ? "EQH (BSL)" : "BSL") :
                             (isEq ? "EQL (SSL)" : "SSL");

        // Línea de nivel
        ObjectCreate(0, nm, OBJ_TREND, 0,
                    g_swings[s].time, g_swings[s].price,
                    extEnd,           g_swings[s].price);
        ObjectSetInteger(0, nm, OBJPROP_COLOR,     clr);
        ObjectSetInteger(0, nm, OBJPROP_STYLE,     isEq ? STYLE_SOLID : STYLE_DASH);
        ObjectSetInteger(0, nm, OBJPROP_WIDTH,     isEq ? 2 : 1);
        ObjectSetInteger(0, nm, OBJPROP_RAY_RIGHT, false);
        ObjectSetString(0, nm,  OBJPROP_TOOLTIP,
            StringFormat("ICT %s: %.5f", label, g_swings[s].price));

        // Etiqueta
        if(InpShowLabels)
        {
            string lnm = nm + "_L";
            ObjectCreate(0, lnm, OBJ_TEXT, 0, extEnd, g_swings[s].price);
            ObjectSetString(0, lnm, OBJPROP_TEXT,     label);
            ObjectSetInteger(0, lnm, OBJPROP_COLOR,   clr);
            ObjectSetInteger(0, lnm, OBJPROP_FONTSIZE, 7);
        }
    }
}

//=================================================================
//  DIBUJO: ORDER BLOCKS
//=================================================================
void DrawOBBoxes(datetime curTime)
{
    for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
    {
        string nm = ObjectName(0, i);
        if(StringFind(nm, PFXO + "OB") == 0) ObjectDelete(0, nm);
    }

    datetime extEnd = curTime + (datetime)(PeriodSeconds(PERIOD_H1) * 6);
    int n = ArraySize(g_obs);

    for(int k = 0; k < n; k++)
    {
        // No dibujar OBs rotos (solo Breakers)
        if(g_obs[k].broken && !g_obs[k].isBreaker) continue;
        if(g_obs[k].mitigated) continue;

        string nm   = PFXO + "OB_" + IntegerToString(k);
        bool   bull = g_obs[k].bull;
        bool   brkr = g_obs[k].isBreaker;

        color  clr  = brkr ? InpBreakerCol :
                     (bull ? InpBullOBCol : InpBearOBCol);
        string tipL = brkr ? (bull ? "Bullish Breaker Block" : "Bearish Breaker Block") :
                             (bull ? "Bullish Order Block"   : "Bearish Order Block");

        ObjectCreate(0, nm, OBJ_RECTANGLE, 0,
                    g_obs[k].t1, g_obs[k].hi,
                    extEnd,      g_obs[k].lo);
        ObjectSetInteger(0, nm, OBJPROP_COLOR,  clr);
        ObjectSetInteger(0, nm, OBJPROP_STYLE,  STYLE_SOLID);
        ObjectSetInteger(0, nm, OBJPROP_WIDTH,  1);
        ObjectSetInteger(0, nm, OBJPROP_FILL,   true);
        ObjectSetInteger(0, nm, OBJPROP_BACK,   true);
        ObjectSetString(0, nm,  OBJPROP_TOOLTIP,
            StringFormat("ICT %s: %.5f - %.5f", tipL, g_obs[k].hi, g_obs[k].lo));

        // Etiqueta
        if(InpShowLabels)
        {
            string lnm = nm + "_L";
            ObjectCreate(0, lnm, OBJ_TEXT, 0, g_obs[k].t1,
                        (g_obs[k].hi + g_obs[k].lo) / 2.0);
            ObjectSetString(0, lnm, OBJPROP_TEXT,
                           brkr ? (bull ? "BullBrkr" : "BearBrkr") :
                                  (bull ? "Bull OB"  : "Bear OB"));
            ObjectSetInteger(0, lnm, OBJPROP_COLOR,    clr);
            ObjectSetInteger(0, lnm, OBJPROP_FONTSIZE, 7);
        }
    }
}

//=================================================================
//  DIBUJO: FAIR VALUE GAPS
//=================================================================
void DrawFVGBoxes(datetime curTime)
{
    for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
    {
        string nm = ObjectName(0, i);
        if(StringFind(nm, PFXO + "FVG") == 0) ObjectDelete(0, nm);
    }

    datetime extEnd = curTime + (datetime)(PeriodSeconds(PERIOD_H1) * 6);
    int n = ArraySize(g_fvgs);

    for(int k = 0; k < n; k++)
    {
        if(g_fvgs[k].filled) continue;

        string nm   = PFXO + "FVG_" + IntegerToString(k);
        bool   bull = g_fvgs[k].bull;
        bool   inv  = g_fvgs[k].isInverse;
        color  clr  = bull ? InpBullFVGCol : InpBearFVGCol;

        ObjectCreate(0, nm, OBJ_RECTANGLE, 0,
                    g_fvgs[k].t1, g_fvgs[k].hi,
                    extEnd,       g_fvgs[k].lo);
        ObjectSetInteger(0, nm, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, nm, OBJPROP_STYLE, inv ? STYLE_DOT : STYLE_SOLID);
        ObjectSetInteger(0, nm, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, nm, OBJPROP_FILL,  true);
        ObjectSetInteger(0, nm, OBJPROP_BACK,  true);
        ObjectSetString(0, nm,  OBJPROP_TOOLTIP,
            StringFormat("ICT %s FVG: %.5f - %.5f",
            bull ? "Bull" : "Bear", g_fvgs[k].hi, g_fvgs[k].lo));

        if(InpShowLabels)
        {
            string lnm = nm + "_L";
            ObjectCreate(0, lnm, OBJ_TEXT, 0, g_fvgs[k].t1,
                        (g_fvgs[k].hi + g_fvgs[k].lo) / 2.0);
            ObjectSetString(0, lnm, OBJPROP_TEXT, bull ? "FVG▲" : "FVG▼");
            ObjectSetInteger(0, lnm, OBJPROP_COLOR,    clr);
            ObjectSetInteger(0, lnm, OBJPROP_FONTSIZE, 7);
        }
    }
}

//=================================================================
//  DIBUJO: PDH / PDL
//=================================================================
void DrawPrevDayHL(datetime curTime)
{
    for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
    {
        string nm = ObjectName(0, i);
        if(StringFind(nm, PFXO + "PD") == 0) ObjectDelete(0, nm);
    }

    MqlRates daily[];
    if(CopyRates(_Symbol, PERIOD_D1, 1, 2, daily) < 1) return;

    string pdPfx[2]; pdPfx[0] = PFXO+"PDH"; pdPfx[1] = PFXO+"PDL";
    double pdPrice[2]; pdPrice[0] = daily[0].high; pdPrice[1] = daily[0].low;
    color  pdClr[2];  pdClr[0]  = InpPDHCol;      pdClr[1]  = InpPDLCol;
    string pdLbl[2];  pdLbl[0]  = "PDH";           pdLbl[1]  = "PDL";

    for(int k = 0; k < 2; k++)
    {
        ObjectCreate(0, pdPfx[k], OBJ_HLINE, 0, 0, pdPrice[k]);
        ObjectSetInteger(0, pdPfx[k], OBJPROP_COLOR, pdClr[k]);
        ObjectSetInteger(0, pdPfx[k], OBJPROP_STYLE, STYLE_DASH);
        ObjectSetInteger(0, pdPfx[k], OBJPROP_WIDTH, 1);
        ObjectSetString(0, pdPfx[k], OBJPROP_TOOLTIP,
            StringFormat("ICT %s: %.5f  (Liquidity target)", pdLbl[k], pdPrice[k]));

        if(InpShowLabels)
        {
            string lnm = pdPfx[k] + "_L";
            ObjectCreate(0, lnm, OBJ_TEXT, 0, curTime, pdPrice[k]);
            ObjectSetString(0, lnm, OBJPROP_TEXT,     pdLbl[k]);
            ObjectSetInteger(0, lnm, OBJPROP_COLOR,   pdClr[k]);
            ObjectSetInteger(0, lnm, OBJPROP_FONTSIZE, 8);
        }
    }
}

//=================================================================
//  DIBUJO: PWH / PWL
//=================================================================
void DrawPrevWeekHL(datetime curTime)
{
    for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
    {
        string nm = ObjectName(0, i);
        if(StringFind(nm, PFXO + "PW") == 0) ObjectDelete(0, nm);
    }

    MqlRates weekly[];
    if(CopyRates(_Symbol, PERIOD_W1, 1, 2, weekly) < 1) return;

    string pwPfx[2]; pwPfx[0] = PFXO+"PWH"; pwPfx[1] = PFXO+"PWL";
    double pwPrice[2]; pwPrice[0] = weekly[0].high; pwPrice[1] = weekly[0].low;
    color  pwClr[2];  pwClr[0]  = InpPWHCol;       pwClr[1]  = InpPWLCol;
    string pwLbl[2];  pwLbl[0]  = "PWH";            pwLbl[1]  = "PWL";

    for(int k = 0; k < 2; k++)
    {
        ObjectCreate(0, pwPfx[k], OBJ_HLINE, 0, 0, pwPrice[k]);
        ObjectSetInteger(0, pwPfx[k], OBJPROP_COLOR, pwClr[k]);
        ObjectSetInteger(0, pwPfx[k], OBJPROP_STYLE, STYLE_DOT);
        ObjectSetInteger(0, pwPfx[k], OBJPROP_WIDTH, 1);
        ObjectSetString(0, pwPfx[k], OBJPROP_TOOLTIP,
            StringFormat("ICT %s: %.5f  (Weekly Liquidity)", pwLbl[k], pwPrice[k]));

        if(InpShowLabels)
        {
            string lnm = pwPfx[k] + "_L";
            ObjectCreate(0, lnm, OBJ_TEXT, 0, curTime, pwPrice[k]);
            ObjectSetString(0, lnm, OBJPROP_TEXT,     pwLbl[k]);
            ObjectSetInteger(0, lnm, OBJPROP_COLOR,   pwClr[k]);
            ObjectSetInteger(0, lnm, OBJPROP_FONTSIZE, 8);
        }
    }
}

//=================================================================
//  DIBUJO: CHOCH / MSS
//=================================================================
void DrawCHOCHMarkers(datetime curTime)
{
    for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
    {
        string nm = ObjectName(0, i);
        if(StringFind(nm, PFXO + "CHOCH") == 0) ObjectDelete(0, nm);
    }

    for(int k = 0; k < ArraySize(g_chochs); k++)
    {
        string nm = PFXO + "CHOCH_" + IntegerToString(k);
        ObjectCreate(0, nm, OBJ_HLINE, 0, 0, g_chochs[k].price);
        ObjectSetInteger(0, nm, OBJPROP_COLOR, InpCHOCHCol);
        ObjectSetInteger(0, nm, OBJPROP_STYLE, STYLE_DASHDOT);
        ObjectSetInteger(0, nm, OBJPROP_WIDTH, 1);
        string tipLabel = g_chochs[k].bull ? "Bullish CHOCH" : "Bearish CHOCH";
        ObjectSetString(0, nm, OBJPROP_TOOLTIP,
            StringFormat("ICT %s @ %.5f", tipLabel, g_chochs[k].price));

        if(InpShowLabels)
        {
            string lnm = nm + "_L";
            ObjectCreate(0, lnm, OBJ_TEXT, 0, g_chochs[k].time, g_chochs[k].price);
            ObjectSetString(0, lnm, OBJPROP_TEXT,
                           g_chochs[k].bull ? "CHOCH ↑" : "CHOCH ↓");
            ObjectSetInteger(0, lnm, OBJPROP_COLOR,    InpCHOCHCol);
            ObjectSetInteger(0, lnm, OBJPROP_FONTSIZE, 8);
        }
    }
}

//=================================================================
//  DIBUJO: ETIQUETA DE SEÑAL
//=================================================================
void DrawSignalLabel(string nm, datetime t, double price,
                     string txt, color clr, bool isUp)
{
    if(ObjectFind(0, nm) >= 0) ObjectDelete(0, nm);

    ObjectCreate(0, nm, OBJ_TEXT, 0, t, price);
    ObjectSetString(0, nm, OBJPROP_TEXT,     txt);
    ObjectSetInteger(0, nm, OBJPROP_COLOR,   clr);
    ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, 7);
    // ANCHOR_RIGHT_UPPER=6, ANCHOR_RIGHT_LOWER=4 (ENUM_ANCHOR_POINT)
    ObjectSetInteger(0, nm, OBJPROP_ANCHOR, isUp ? 6 : 4);
    ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
}
//+------------------------------------------------------------------+
