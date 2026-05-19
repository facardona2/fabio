//+------------------------------------------------------------------+
//|                       NY_Sessions_XM.mq5                         |
//|   Sesiones NY · EMA 20/50/150 · Judas Swing filtrado · XM        |
//|                                                                  |
//|  LÓGICA DE SEÑALES (Judas Swing + EMA):                          |
//|  ► BUY  = EMA20>EMA50>EMA150 (tendencia arriba)                  |
//|           + Judas barrió mínimos previos (false breakdown)       |
//|           + Precio tocó EMA20 o EMA50 (retroceso a media)        |
//|           + Vela alcista de confirmación tras el barrido          |
//|  ► SELL = EMA20<EMA50<EMA150 (tendencia abajo)                   |
//|           + Judas barrió máximos previos (false breakout)        |
//|           + Precio tocó EMA20 o EMA50 (retroceso a media)        |
//|           + Vela bajista de confirmación tras el barrido          |
//+------------------------------------------------------------------+
#property copyright   "2024"
#property version     "3.00"
#property description "Sesiones NY · EMA 20/50/150 · Judas Swing filtrado por tendencia · XM"
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   3

// Plot 0 – EMA rápida
#property indicator_plot1_label "EMA 20"
#property indicator_plot1_type  DRAW_LINE
#property indicator_plot1_color clrCyan
#property indicator_plot1_width 1
#property indicator_plot1_style STYLE_SOLID

// Plot 1 – EMA media
#property indicator_plot2_label "EMA 50"
#property indicator_plot2_type  DRAW_LINE
#property indicator_plot2_color clrOrange
#property indicator_plot2_width 1
#property indicator_plot2_style STYLE_SOLID

// Plot 2 – EMA lenta
#property indicator_plot3_label "EMA 150"
#property indicator_plot3_type  DRAW_LINE
#property indicator_plot3_color clrRed
#property indicator_plot3_width 2
#property indicator_plot3_style STYLE_SOLID

//============================================================
//  INPUTS
//============================================================

sinput string  _s0 = "════ HORARIO ════";
input  int     InpNYOffset = 7;       // Diferencia Broker vs NY (horas)
input  int     InpLookback = 500;     // Barras históricas a analizar

sinput string  _sp = "════ PANEL ════";
input  int     InpPanelY   = 160;     // Posición Y del panel (px desde arriba)

sinput string  _s1 = "════ SESIÓN 1 ════";
input  bool    InpS1_Enable  = true;
input  string  InpS1_Name    = "NY 20:30";
input  string  InpS1_StartNY = "20:30";
input  string  InpS1_EndNY   = "21:00";
input  color   InpS1_Color   = clrDodgerBlue;
input  int     InpS1_Opacity = 60;

sinput string  _s2 = "════ SESIÓN 2 ════";
input  bool    InpS2_Enable  = true;
input  string  InpS2_Name    = "NY 01:30";
input  string  InpS2_StartNY = "01:30";
input  string  InpS2_EndNY   = "02:00";
input  color   InpS2_Color   = clrLimeGreen;
input  int     InpS2_Opacity = 60;

sinput string  _s3 = "════ SESIÓN 3 ════";
input  bool    InpS3_Enable  = true;
input  string  InpS3_Name    = "NY 06:30";
input  string  InpS3_StartNY = "06:30";
input  string  InpS3_EndNY   = "07:00";
input  color   InpS3_Color   = clrOrange;
input  int     InpS3_Opacity = 60;

sinput string  _s4 = "════ SESIÓN 4 ════";
input  bool    InpS4_Enable  = true;
input  string  InpS4_Name    = "NY 13:30";
input  string  InpS4_StartNY = "13:30";
input  string  InpS4_EndNY   = "14:00";
input  color   InpS4_Color   = clrMagenta;
input  int     InpS4_Opacity = 60;

sinput string  _s5 = "════ LÍNEAS HI / MID ════";
input  int              InpLinesCount    = 3;
input  int              InpLineWidth     = 1;
input  ENUM_LINE_STYLE  InpHighLineStyle = STYLE_DASH;
input  ENUM_LINE_STYLE  InpMidLineStyle  = STYLE_DOT;

sinput string  _s6 = "════ JUDAS SWING ════";
input  bool    InpJudas_Enable   = true;
input  int     InpJudas_PreBars  = 10;    // Barras previas para detectar sweep
input  int     InpJudas_ArrSize  = 3;     // Tamaño flechas
input  color   InpJudas_BuyClr   = clrAqua;
input  color   InpJudas_SellClr  = clrRed;

sinput string  _s7 = "════ FILTRO TENDENCIA EMA ════";
input  bool    InpEMA_Enable       = true;   // Filtrar señales con EMAs
input  int     InpEMA1             = 20;     // EMA rápida (período)
input  int     InpEMA2             = 50;     // EMA media (período)
input  int     InpEMA3             = 150;    // EMA lenta (período)
input  bool    InpEMA_ShowLines    = true;   // Mostrar EMAs en gráfico al iniciar
input  color   InpEMA1_Color       = clrCyan;    // Color EMA 20
input  color   InpEMA2_Color       = clrOrange;  // Color EMA 50
input  color   InpEMA3_Color       = clrRed;     // Color EMA 150
input  int     InpEMA1_Width       = 1;
input  int     InpEMA2_Width       = 1;
input  int     InpEMA3_Width       = 2;
input  bool    InpEMA_RequireTouch = true;   // Exigir que precio toque EMA20/50
input  int     InpEMA_TouchPips    = 20;     // Tolerancia toque EMA (puntos)
input  bool    InpEMA_RequireRev   = true;   // Exigir vela de reversión tras sweep

//============================================================
//  STRUCT
//============================================================

struct SessBlock
{
   datetime t_start;
   datetime t_end;
   int      idx_start;
   int      idx_end;     // -1 si sesión aún abierta
   double   hi;
   double   lo;
   bool     is_open;
};

//============================================================
//  NOMBRES DE OBJETOS
//============================================================

#define BTN_S1    "NYS_B1"
#define BTN_S2    "NYS_B2"
#define BTN_S3    "NYS_B3"
#define BTN_S4    "NYS_B4"
#define BTN_EMA   "NYS_BE"
#define LBL_TITLE "NYS_TT"
#define LBL_CLOCK "NYS_CK"
#define LBL_TREND "NYS_TR"

#define PFX_R1 "NYS_R1_"
#define PFX_R2 "NYS_R2_"
#define PFX_R3 "NYS_R3_"
#define PFX_R4 "NYS_R4_"
#define PFX_H1 "NYS_H1_"
#define PFX_H2 "NYS_H2_"
#define PFX_H3 "NYS_H3_"
#define PFX_H4 "NYS_H4_"
#define PFX_M1 "NYS_M1_"
#define PFX_M2 "NYS_M2_"
#define PFX_M3 "NYS_M3_"
#define PFX_M4 "NYS_M4_"
#define PFX_A1 "NYS_A1_"
#define PFX_A2 "NYS_A2_"
#define PFX_A3 "NYS_A3_"
#define PFX_A4 "NYS_A4_"

//============================================================
//  ESTADO GLOBAL
//============================================================

bool   g_S1_On, g_S2_On, g_S3_On, g_S4_On;
bool   g_EMA_On;
int    g_S1_Judas, g_S2_Judas, g_S3_Judas, g_S4_Judas;  // 0 / 1(BUY) / -1(SELL)
int    g_GlobalTrend = 0;   // tendencia actual para el label

// Buffers de indicador (para dibujar las EMAs en gráfico)
double bufEMA20[], bufEMA50[], bufEMA150[];

//============================================================
//  ON INIT / DEINIT / CALCULATE / TIMER / CHARTEVENT
//============================================================

int OnInit()
{
   g_S1_On = InpS1_Enable;
   g_S2_On = InpS2_Enable;
   g_S3_On = InpS3_Enable;
   g_S4_On = InpS4_Enable;
   g_EMA_On = InpEMA_ShowLines;
   g_S1_Judas = g_S2_Judas = g_S3_Judas = g_S4_Judas = 0;

   // ─── Indicadores EMA buffers ───────────────────────────────────
   SetIndexBuffer(0, bufEMA20,  INDICATOR_DATA);
   SetIndexBuffer(1, bufEMA50,  INDICATOR_DATA);
   SetIndexBuffer(2, bufEMA150, INDICATOR_DATA);

   PlotIndexSetString (0, PLOT_LABEL,      "EMA " + IntegerToString(InpEMA1));
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpEMA1_Color);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpEMA1_Width);

   PlotIndexSetString (1, PLOT_LABEL,      "EMA " + IntegerToString(InpEMA2));
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpEMA2_Color);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpEMA2_Width);

   PlotIndexSetString (2, PLOT_LABEL,      "EMA " + IntegerToString(InpEMA3));
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, InpEMA3_Color);
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, InpEMA3_Width);

   ApplyEMAVisibility();

   // ─── UI ───────────────────────────────────────────────────────
   UI_Build();
   UI_RefreshButtons();
   EventSetTimer(1);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   Cleanup();
}

int OnCalculate(const int      rates_total,
                const int      prev_calculated,
                const datetime &time[],
                const double   &open[],
                const double   &high[],
                const double   &low[],
                const double   &close[],
                const long     &tick_volume[],
                const long     &volume[],
                const int      &spread[])
{
   // ─── Calcular EMAs ────────────────────────────────────────────
   int startFrom = (prev_calculated <= 1) ? 0 : prev_calculated - 1;
   CalcEMABuffer(close, bufEMA20,  InpEMA1, rates_total, startFrom);
   CalcEMABuffer(close, bufEMA50,  InpEMA2, rates_total, startFrom);
   CalcEMABuffer(close, bufEMA150, InpEMA3, rates_total, startFrom);

   // ─── Tendencia actual (última barra) ─────────────────────────
   g_GlobalTrend = GetTrendDir(rates_total - 1);

   // ─── Procesar sesiones ───────────────────────────────────────
   ProcessAll(rates_total, time, open, high, low, close);
   UI_UpdateClock();
   return rates_total;
}

void OnTimer()
{
   UI_UpdateClock();
}

void OnChartEvent(const int id,
                  const long   &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id != CHARTEVENT_OBJECT_CLICK) return;

   // Botón EMA
   if(sparam == BTN_EMA)
   {
      g_EMA_On = !g_EMA_On;
      ApplyEMAVisibility();
      UI_RefreshButtons();
      ChartRedraw();
      return;
   }

   // Botones de sesión
   bool changed = false;
   if(sparam == BTN_S1) { g_S1_On = !g_S1_On; changed = true; }
   if(sparam == BTN_S2) { g_S2_On = !g_S2_On; changed = true; }
   if(sparam == BTN_S3) { g_S3_On = !g_S3_On; changed = true; }
   if(sparam == BTN_S4) { g_S4_On = !g_S4_On; changed = true; }
   if(!changed) return;

   UI_RefreshButtons();
   RedrawFromRates();
}

//============================================================
//  CÁLCULO DE EMAs
//============================================================

void CalcEMABuffer(const double &src[],
                   double       &dst[],
                   int           period,
                   int           total,
                   int           from)
{
   double k = 2.0 / (period + 1.0);

   if(from <= period - 1)
   {
      // Inicialización completa desde cero
      int validFrom = period - 1;
      for(int i = 0; i < validFrom && i < total; i++)
         dst[i] = EMPTY_VALUE;

      if(total < period) return;

      double sum = 0;
      for(int i = 0; i < period; i++) sum += src[i];
      dst[validFrom] = sum / period;

      for(int i = validFrom + 1; i < total; i++)
         dst[i] = src[i] * k + dst[i-1] * (1.0 - k);
   }
   else
   {
      // Solo actualizar barras nuevas (dst[from-1] ya es válido)
      for(int i = from; i < total; i++)
         dst[i] = src[i] * k + dst[i-1] * (1.0 - k);
   }
}

// Visibilidad de los plots EMA
void ApplyEMAVisibility()
{
   int dt = g_EMA_On ? DRAW_LINE : DRAW_NONE;
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, dt);
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, dt);
   PlotIndexSetInteger(2, PLOT_DRAW_TYPE, dt);
}

//============================================================
//  TENDENCIA
//============================================================

// Devuelve  1=alcista  -1=bajista  0=neutral
int GetTrendDir(int idx)
{
   if(idx < 0 || idx >= ArraySize(bufEMA20)) return 0;
   double e1 = bufEMA20[idx];
   double e2 = bufEMA50[idx];
   double e3 = bufEMA150[idx];
   if(e1 == EMPTY_VALUE || e2 == EMPTY_VALUE || e3 == EMPTY_VALUE) return 0;
   if(e1 > e2 && e2 > e3) return  1;
   if(e1 < e2 && e2 < e3) return -1;
   return 0;
}

string TrendText(int t)
{
   if(t ==  1) return "TENDENCIA ▲ ALCISTA";
   if(t == -1) return "TENDENCIA ▼ BAJISTA";
   return "TENDENCIA — NEUTRAL";
}

color TrendColor(int t)
{
   if(t ==  1) return InpJudas_BuyClr;
   if(t == -1) return InpJudas_SellClr;
   return clrSilver;
}

//============================================================
//  UTILIDADES HORARIAS
//============================================================

int ParseMin(const string s)
{
   string p[];
   if(StringSplit(s, ':', p) < 2) return 0;
   return (int)StringToInteger(p[0]) * 60 + (int)StringToInteger(p[1]);
}

int NY2Brk(int nyMin)
{
   return ((nyMin + InpNYOffset * 60) % 1440 + 1440) % 1440;
}

bool InSession(int barMin, int s, int e)
{
   return (s < e) ? (barMin >= s && barMin < e)
                  : (barMin >= s || barMin < e);
}

//============================================================
//  ESCANEO DE BLOQUES
//============================================================

void ScanBlocks(const int      startBrk,
                const int      endBrk,
                const int      total,
                const datetime &time[],
                const double   &high[],
                const double   &low[],
                SessBlock      &blocks[])
{
   ArrayResize(blocks, 0);
   int from = MathMax(0, total - MathMin(InpLookback, total - 1) - 1);

   bool   inSess = false;
   double hi = 0, lo = DBL_MAX;
   int    idx_s = 0;

   for(int i = from; i < total; i++)
   {
      MqlDateTime dt;
      TimeToStruct(time[i], dt);
      bool inside = InSession(dt.hour * 60 + dt.min, startBrk, endBrk);

      if(inside && !inSess)
      {
         inSess = true;
         idx_s  = i;
         hi     = high[i];
         lo     = low[i];
      }
      else if(inside && inSess)
      {
         if(high[i] > hi) hi = high[i];
         if(low[i]  < lo) lo = low[i];
      }
      else if(!inside && inSess)
      {
         inSess = false;
         int n  = ArraySize(blocks);
         ArrayResize(blocks, n + 1);
         blocks[n].t_start   = time[idx_s];
         blocks[n].t_end     = time[i];
         blocks[n].idx_start = idx_s;
         blocks[n].idx_end   = i;
         blocks[n].hi        = hi;
         blocks[n].lo        = lo;
         blocks[n].is_open   = false;
         hi = 0; lo = DBL_MAX;
      }
   }
   if(inSess)
   {
      int n = ArraySize(blocks);
      ArrayResize(blocks, n + 1);
      blocks[n].t_start   = time[idx_s];
      blocks[n].t_end     = time[total-1] + (datetime)PeriodSeconds();
      blocks[n].idx_start = idx_s;
      blocks[n].idx_end   = -1;
      blocks[n].hi        = hi;
      blocks[n].lo        = lo;
      blocks[n].is_open   = true;
   }
}

//============================================================
//  DETECCIÓN JUDAS SWING + FILTRO EMA
//============================================================

// Encuentra el bar donde ocurrió el high (wantHi=true) o low del bloque
int FindExtremumBar(const SessBlock &blk,
                    bool wantHi,
                    const int total,
                    const double &high[],
                    const double &low[])
{
   int end_i = (blk.idx_end < 0) ? (total-1)
                                  : MathMin(blk.idx_end-1, total-1);
   double target = wantHi ? blk.hi : blk.lo;
   for(int i = blk.idx_start; i <= end_i; i++)
   {
      double val = wantHi ? high[i] : low[i];
      if(MathAbs(val - target) < _Point) return i;
   }
   return blk.idx_start;
}

// ──────────────────────────────────────────────────────────────────
//  Lógica completa:
//    1. Detecta si hubo barrido de liquidez (Judas Sweep)
//    2. Filtra por alineación de EMAs (tendencia)
//    3. Verifica retroceso a EMA (toque de media)
//    4. Confirma reversión con vela en dirección de tendencia
// ──────────────────────────────────────────────────────────────────
int DetectJudas(const SessBlock &blk,
                const int        total,
                const double    &high[],
                const double    &low[],
                const double    &open[],
                const double    &close[])
{
   if(!InpJudas_Enable || blk.is_open) return 0;

   // ── 1. Sweep: ¿barrió la sesión mínimos/máximos pre-sesión? ──
   int preStart = MathMax(0, blk.idx_start - InpJudas_PreBars);
   if(blk.idx_start <= preStart) return 0;

   double pre_hi = 0, pre_lo = DBL_MAX;
   for(int j = preStart; j < blk.idx_start; j++)
   {
      if(high[j] > pre_hi) pre_hi = high[j];
      if(low[j]  < pre_lo) pre_lo = low[j];
   }

   bool swept_hi = blk.hi > pre_hi + _Point;
   bool swept_lo = blk.lo < pre_lo - _Point;

   // Ambiguo o sin sweep → no hay señal
   if((!swept_hi && !swept_lo) || (swept_hi && swept_lo)) return 0;

   int raw = swept_lo ? 1 : -1;   // 1=BUY  -1=SELL (sin filtrar)

   // ── 2. Filtro de tendencia EMA ────────────────────────────────
   if(InpEMA_Enable)
   {
      int trend = GetTrendDir(blk.idx_start);
      if(trend == 0)        return 0;   // Tendencia neutral → no operar
      if(raw != trend)      return 0;   // Señal contra tendencia → ignorar

      // ── 3. Retroceso: ¿tocó precio la EMA durante la sesión? ──
      if(InpEMA_RequireTouch)
      {
         double tol = InpEMA_TouchPips * _Point;

         if(raw == 1)   // BUY: low debe haber tocado EMA20 o EMA50
         {
            int bar_lo = FindExtremumBar(blk, false, total, high, low);
            double e1  = bufEMA20[bar_lo];
            double e2  = bufEMA50[bar_lo];
            bool touched = (e1 != EMPTY_VALUE && blk.lo <= e1 + tol) ||
                           (e2 != EMPTY_VALUE && blk.lo <= e2 + tol);
            if(!touched) return 0;
         }
         else           // SELL: high debe haber tocado EMA20 o EMA50
         {
            int bar_hi = FindExtremumBar(blk, true, total, high, low);
            double e1  = bufEMA20[bar_hi];
            double e2  = bufEMA50[bar_hi];
            bool touched = (e1 != EMPTY_VALUE && blk.hi >= e1 - tol) ||
                           (e2 != EMPTY_VALUE && blk.hi >= e2 - tol);
            if(!touched) return 0;
         }
      }

      // ── 4. Confirmación: vela de reversión después del sweep ──
      if(InpEMA_RequireRev)
      {
         int sweep_bar = (raw == 1)
                         ? FindExtremumBar(blk, false, total, high, low)
                         : FindExtremumBar(blk, true,  total, high, low);

         int end_bar = (blk.idx_end < 0) ? (total-1)
                                          : MathMin(blk.idx_end-1, total-1);
         bool confirmed = false;
         for(int i = sweep_bar + 1; i <= end_bar; i++)
         {
            if(raw ==  1 && close[i] > open[i]) { confirmed = true; break; }
            if(raw == -1 && close[i] < open[i]) { confirmed = true; break; }
         }
         if(!confirmed) return 0;
      }
   }

   return raw;
}

//============================================================
//  PRIMITIVAS GRÁFICAS
//============================================================

void PaintRect(const string nm,
               datetime t1, datetime t2,
               double top, double bot,
               color clr, int opacityPct)
{
   uchar alpha   = (uchar)(opacityPct * 255 / 100);
   uint  argbClr = ColorToARGB(clr, alpha);

   if(ObjectFind(0, nm) < 0)
      ObjectCreate(0, nm, OBJ_RECTANGLE, 0, t1, top, t2, bot);
   else
   {
      ObjectSetInteger(0, nm, OBJPROP_TIME,  0, t1);
      ObjectSetDouble (0, nm, OBJPROP_PRICE, 0, top);
      ObjectSetInteger(0, nm, OBJPROP_TIME,  1, t2);
      ObjectSetDouble (0, nm, OBJPROP_PRICE, 1, bot);
   }
   ObjectSetInteger(0, nm, OBJPROP_COLOR,      argbClr);
   ObjectSetInteger(0, nm, OBJPROP_STYLE,      STYLE_SOLID);
   ObjectSetInteger(0, nm, OBJPROP_WIDTH,      1);
   ObjectSetInteger(0, nm, OBJPROP_FILL,       true);
   ObjectSetInteger(0, nm, OBJPROP_BACK,       true);
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nm, OBJPROP_HIDDEN,     true);
}

void PaintHRay(const string nm,
               datetime t_from, double price,
               color clr, ENUM_LINE_STYLE lstyle, int lw)
{
   datetime t2 = t_from + (datetime)PeriodSeconds() * 5;
   if(ObjectFind(0, nm) < 0)
      ObjectCreate(0, nm, OBJ_TREND, 0, t_from, price, t2, price);
   else
   {
      ObjectSetInteger(0, nm, OBJPROP_TIME,  0, t_from);
      ObjectSetDouble (0, nm, OBJPROP_PRICE, 0, price);
      ObjectSetInteger(0, nm, OBJPROP_TIME,  1, t2);
      ObjectSetDouble (0, nm, OBJPROP_PRICE, 1, price);
   }
   ObjectSetInteger(0, nm, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, nm, OBJPROP_STYLE,      lstyle);
   ObjectSetInteger(0, nm, OBJPROP_WIDTH,      lw);
   ObjectSetInteger(0, nm, OBJPROP_RAY_RIGHT,  true);
   ObjectSetInteger(0, nm, OBJPROP_RAY_LEFT,   false);
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nm, OBJPROP_HIDDEN,     true);
   ObjectSetInteger(0, nm, OBJPROP_BACK,       true);
}

void PaintArrow(const string nm,
                datetime t, double price,
                bool isBuy, color clr, int sz)
{
   if(ObjectFind(0, nm) < 0)
      ObjectCreate(0, nm, OBJ_ARROW, 0, t, price);
   else
   {
      ObjectSetInteger(0, nm, OBJPROP_TIME,  0, t);
      ObjectSetDouble (0, nm, OBJPROP_PRICE, 0, price);
   }
   ObjectSetInteger(0, nm, OBJPROP_ARROWCODE,  isBuy ? 233 : 234);  // ▲ / ▼
   ObjectSetInteger(0, nm, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, nm, OBJPROP_WIDTH,      sz);
   ObjectSetInteger(0, nm, OBJPROP_ANCHOR,     isBuy ? ANCHOR_TOP : ANCHOR_BOTTOM);
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nm, OBJPROP_HIDDEN,     true);
}

void DeletePfx(const string pfx) { ObjectsDeleteAll(0, pfx); }

//============================================================
//  PROCESAMIENTO POR SESIÓN
//============================================================

int ProcessSession(const string pfx_r,
                   const string pfx_h,
                   const string pfx_m,
                   const string pfx_a,
                   const int    startBrk,
                   const int    endBrk,
                   const color  clr,
                   const int    opacity,
                   const int    total,
                   const datetime &time[],
                   const double   &open[],
                   const double   &high[],
                   const double   &low[],
                   const double   &close[])
{
   SessBlock blocks[];
   ScanBlocks(startBrk, endBrk, total, time, high, low, blocks);
   int nBlocks = ArraySize(blocks);

   DeletePfx(pfx_r); DeletePfx(pfx_h);
   DeletePfx(pfx_m); DeletePfx(pfx_a);

   if(nBlocks == 0) return 0;

   // Rectángulos para todos los bloques
   for(int i = 0; i < nBlocks; i++)
      PaintRect(pfx_r + IntegerToString(i),
                blocks[i].t_start, blocks[i].t_end,
                blocks[i].hi, blocks[i].lo, clr, opacity);

   // Líneas y flechas para los últimos N bloques
   int maxL     = (InpLinesCount <= 0) ? nBlocks : MathMin(InpLinesCount, nBlocks);
   int lineFrom = nBlocks - maxL;
   int last_j   = 0;

   for(int i = lineFrom; i < nBlocks; i++)
   {
      double mid = (blocks[i].hi + blocks[i].lo) * 0.5;

      PaintHRay(pfx_h + IntegerToString(i), blocks[i].t_end, blocks[i].hi,
                clr, InpHighLineStyle, InpLineWidth);
      PaintHRay(pfx_m + IntegerToString(i), blocks[i].t_end, mid,
                clr, InpMidLineStyle,  InpLineWidth);

      if(!blocks[i].is_open)
      {
         int jType = DetectJudas(blocks[i], total, high, low, open, close);
         last_j    = jType;

         if(jType == -1)
         {
            int barHi = FindExtremumBar(blocks[i], true,  total, high, low);
            PaintArrow(pfx_a + IntegerToString(i),
                       time[barHi], high[barHi],
                       false, InpJudas_SellClr, InpJudas_ArrSize);
         }
         else if(jType == 1)
         {
            int barLo = FindExtremumBar(blocks[i], false, total, high, low);
            PaintArrow(pfx_a + IntegerToString(i),
                       time[barLo], low[barLo],
                       true, InpJudas_BuyClr, InpJudas_ArrSize);
         }
      }
   }
   return last_j;
}

// ─── Orquesta las 4 sesiones ──────────────────────────────────────
void ProcessAll(const int      total,
                const datetime &time[],
                const double   &open[],
                const double   &high[],
                const double   &low[],
                const double   &close[])
{
   if(g_S1_On)
      g_S1_Judas = ProcessSession(PFX_R1,PFX_H1,PFX_M1,PFX_A1,
         NY2Brk(ParseMin(InpS1_StartNY)), NY2Brk(ParseMin(InpS1_EndNY)),
         InpS1_Color, InpS1_Opacity, total, time, open, high, low, close);
   else
   { DeletePfx(PFX_R1); DeletePfx(PFX_H1); DeletePfx(PFX_M1); DeletePfx(PFX_A1); g_S1_Judas=0; }

   if(g_S2_On)
      g_S2_Judas = ProcessSession(PFX_R2,PFX_H2,PFX_M2,PFX_A2,
         NY2Brk(ParseMin(InpS2_StartNY)), NY2Brk(ParseMin(InpS2_EndNY)),
         InpS2_Color, InpS2_Opacity, total, time, open, high, low, close);
   else
   { DeletePfx(PFX_R2); DeletePfx(PFX_H2); DeletePfx(PFX_M2); DeletePfx(PFX_A2); g_S2_Judas=0; }

   if(g_S3_On)
      g_S3_Judas = ProcessSession(PFX_R3,PFX_H3,PFX_M3,PFX_A3,
         NY2Brk(ParseMin(InpS3_StartNY)), NY2Brk(ParseMin(InpS3_EndNY)),
         InpS3_Color, InpS3_Opacity, total, time, open, high, low, close);
   else
   { DeletePfx(PFX_R3); DeletePfx(PFX_H3); DeletePfx(PFX_M3); DeletePfx(PFX_A3); g_S3_Judas=0; }

   if(g_S4_On)
      g_S4_Judas = ProcessSession(PFX_R4,PFX_H4,PFX_M4,PFX_A4,
         NY2Brk(ParseMin(InpS4_StartNY)), NY2Brk(ParseMin(InpS4_EndNY)),
         InpS4_Color, InpS4_Opacity, total, time, open, high, low, close);
   else
   { DeletePfx(PFX_R4); DeletePfx(PFX_H4); DeletePfx(PFX_M4); DeletePfx(PFX_A4); g_S4_Judas=0; }

   UI_RefreshButtons();
}

// ─── Redibuja usando CopyRates (desde OnChartEvent) ───────────────
void RedrawFromRates()
{
   MqlRates r[];
   int n = CopyRates(_Symbol, _Period, 0,
                     MathMin(InpLookback + 20, Bars(_Symbol, _Period)), r);
   if(n < 2) return;

   datetime t[]; double op[], hi[], lo[], cl[];
   ArrayResize(t,  n); ArrayResize(op, n);
   ArrayResize(hi, n); ArrayResize(lo, n); ArrayResize(cl, n);
   for(int i = 0; i < n; i++)
   {
      t[i]=r[i].time; op[i]=r[i].open;
      hi[i]=r[i].high; lo[i]=r[i].low; cl[i]=r[i].close;
   }
   ProcessAll(n, t, op, hi, lo, cl);
   ChartRedraw();
}

//============================================================
//  INTERFAZ DE USUARIO
//============================================================

void UI_Build()
{
   int y = InpPanelY;
   MakeLabel(LBL_TITLE, 10, y,      "  NY SESSIONS  XM  ", clrGold,   9, true);
   MakeLabel(LBL_CLOCK, 10, y + 15, "NY --:--:--  |  XM --:--:--", clrSilver, 8, false);
   MakeLabel(LBL_TREND, 10, y + 27, "TENDENCIA — NEUTRAL", clrSilver, 8, true);

   MakeButton(BTN_S1,  10, y + 42,  190, 23, "", InpS1_Color);
   MakeButton(BTN_S2,  10, y + 69,  190, 23, "", InpS2_Color);
   MakeButton(BTN_S3,  10, y + 96,  190, 23, "", InpS3_Color);
   MakeButton(BTN_S4,  10, y + 123, 190, 23, "", InpS4_Color);
   MakeButton(BTN_EMA, 10, y + 151, 190, 20, "", clrSlateBlue);
}

string JudasTag(int jType)
{
   if(jType ==  1) return " ▲BUY";
   if(jType == -1) return " ▼SELL";
   return "";
}

void UI_RefreshButtons()
{
   struct BI { string btn; bool on; string nm, sNY, eNY; color col; int judas; };
   BI b[4];
   b[0].btn=BTN_S1; b[0].on=g_S1_On; b[0].nm=InpS1_Name;
   b[0].sNY=InpS1_StartNY; b[0].eNY=InpS1_EndNY; b[0].col=InpS1_Color; b[0].judas=g_S1_Judas;
   b[1].btn=BTN_S2; b[1].on=g_S2_On; b[1].nm=InpS2_Name;
   b[1].sNY=InpS2_StartNY; b[1].eNY=InpS2_EndNY; b[1].col=InpS2_Color; b[1].judas=g_S2_Judas;
   b[2].btn=BTN_S3; b[2].on=g_S3_On; b[2].nm=InpS3_Name;
   b[2].sNY=InpS3_StartNY; b[2].eNY=InpS3_EndNY; b[2].col=InpS3_Color; b[2].judas=g_S3_Judas;
   b[3].btn=BTN_S4; b[3].on=g_S4_On; b[3].nm=InpS4_Name;
   b[3].sNY=InpS4_StartNY; b[3].eNY=InpS4_EndNY; b[3].col=InpS4_Color; b[3].judas=g_S4_Judas;

   for(int i = 0; i < 4; i++)
   {
      int bs = NY2Brk(ParseMin(b[i].sNY));
      int be = NY2Brk(ParseMin(b[i].eNY));
      string xm  = StringFormat("%02d:%02d-%02d:%02d XM", bs/60,bs%60, be/60,be%60);
      string lbl = (b[i].on ? "ON " : "OFF") + " " + b[i].nm + " | " + xm + JudasTag(b[i].judas);

      color bg;
      if(!b[i].on)             bg = clrDimGray;
      else if(b[i].judas ==  1) bg = InpJudas_BuyClr;
      else if(b[i].judas == -1) bg = InpJudas_SellClr;
      else                      bg = b[i].col;

      ObjectSetString (0, b[i].btn, OBJPROP_TEXT,    lbl);
      ObjectSetInteger(0, b[i].btn, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(0, b[i].btn, OBJPROP_COLOR,   clrWhite);
   }

   // Botón EMA
   string emaLbl = "EMA " + IntegerToString(InpEMA1) + "/" +
                   IntegerToString(InpEMA2) + "/" +
                   IntegerToString(InpEMA3) +
                   (g_EMA_On ? " [VISIBLE]" : " [OCULTO]");
   ObjectSetString (0, BTN_EMA, OBJPROP_TEXT,    emaLbl);
   ObjectSetInteger(0, BTN_EMA, OBJPROP_BGCOLOR, g_EMA_On ? clrSlateBlue : clrDimGray);
   ObjectSetInteger(0, BTN_EMA, OBJPROP_COLOR,   clrWhite);

   // Label de tendencia
   ObjectSetString (0, LBL_TREND, OBJPROP_TEXT,  TrendText(g_GlobalTrend));
   ObjectSetInteger(0, LBL_TREND, OBJPROP_COLOR, TrendColor(g_GlobalTrend));

   ChartRedraw();
}

void UI_UpdateClock()
{
   datetime tBrk = TimeCurrent();
   datetime tNY  = tBrk - (datetime)(InpNYOffset * 3600);
   MqlDateTime dB, dN;
   TimeToStruct(tBrk, dB);
   TimeToStruct(tNY,  dN);
   string txt = StringFormat("NY %02d:%02d:%02d  |  XM %02d:%02d:%02d",
                              dN.hour,dN.min,dN.sec, dB.hour,dB.min,dB.sec);
   ObjectSetString(0, LBL_CLOCK, OBJPROP_TEXT, txt);

   // Actualizar tendencia actual también en el timer
   g_GlobalTrend = GetTrendDir(ArraySize(bufEMA20) - 1);
   ObjectSetString (0, LBL_TREND, OBJPROP_TEXT,  TrendText(g_GlobalTrend));
   ObjectSetInteger(0, LBL_TREND, OBJPROP_COLOR, TrendColor(g_GlobalTrend));

   ChartRedraw();
}

//--- Helpers de objetos UI

void MakeButton(const string name, int x, int y, int w, int h, string txt, color bg)
{
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,    x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,    y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE,        w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE,        h);
   ObjectSetString (0, name, OBJPROP_TEXT,         txt);
   ObjectSetInteger(0, name, OBJPROP_COLOR,        clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR,      bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrGray);
   ObjectSetInteger(0, name, OBJPROP_CORNER,       CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,     8);
   ObjectSetString (0, name, OBJPROP_FONT,         "Arial Bold");
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE,   false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,       true);
}

void MakeLabel(const string name, int x, int y, string txt, color clr, int fs, bool bold)
{
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,  y);
   ObjectSetString (0, name, OBJPROP_TEXT,       txt);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, name, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,   fs);
   ObjectSetString (0, name, OBJPROP_FONT,       bold ? "Arial Bold" : "Arial");
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
}

void Cleanup()
{
   string pfx[] = { PFX_R1,PFX_R2,PFX_R3,PFX_R4,
                    PFX_H1,PFX_H2,PFX_H3,PFX_H4,
                    PFX_M1,PFX_M2,PFX_M3,PFX_M4,
                    PFX_A1,PFX_A2,PFX_A3,PFX_A4 };
   for(int i = 0; i < ArraySize(pfx); i++) DeletePfx(pfx[i]);
   ObjectDelete(0, BTN_S1); ObjectDelete(0, BTN_S2);
   ObjectDelete(0, BTN_S3); ObjectDelete(0, BTN_S4);
   ObjectDelete(0, BTN_EMA);
   ObjectDelete(0, LBL_TITLE); ObjectDelete(0, LBL_CLOCK); ObjectDelete(0, LBL_TREND);
   ChartRedraw();
}
//+------------------------------------------------------------------+
