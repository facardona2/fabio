//+------------------------------------------------------------------+
//|                       NY_Sessions_XM.mq5                         |
//|   Sesiones NY · Líneas Hi/Mid · Judas Swing · Botones ON/OFF     |
//|                                                                  |
//|  Offset defecto: Broker XM = NY + 7h  (NY 15:16 → XM 22:16)    |
//|  S1: NY 20:30-21:00  →  XM 03:30-04:00                          |
//|  S2: NY 01:30-02:00  →  XM 08:30-09:00                          |
//|  S3: NY 06:30-07:00  →  XM 13:30-14:00                          |
//|  S4: NY 13:30-14:00  →  XM 20:30-21:00                          |
//+------------------------------------------------------------------+
#property copyright   "2024"
#property version     "2.00"
#property description "Sesiones NY · Líneas Hi/Mid · Judas Swing · XM"
#property indicator_chart_window
#property indicator_plots 0

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
input  int     InpS1_Opacity = 60;         // Opacidad rectángulo %

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
input  int              InpLinesCount    = 3;           // Sesiones con líneas (0=todas)
input  int              InpLineWidth     = 1;           // Grosor de las líneas
input  ENUM_LINE_STYLE  InpHighLineStyle = STYLE_DASH;  // Estilo línea HIGH
input  ENUM_LINE_STYLE  InpMidLineStyle  = STYLE_DOT;   // Estilo línea MID 50%

sinput string  _s6 = "════ JUDAS SWING ════";
input  bool    InpJudas_Enable  = true;   // Activar detección Judas Swing
input  int     InpJudas_PreBars = 10;     // Barras previas para detectar sweep
input  int     InpJudas_ArrSize = 3;      // Tamaño flechas (1-5)
input  color   InpJudas_BuyClr  = clrAqua;// Color flecha BUY  ▲
input  color   InpJudas_SellClr = clrRed; // Color flecha SELL ▼

//============================================================
//  ESTRUCTURA PARA BLOQUES DE SESIÓN
//============================================================

struct SessBlock
{
   datetime t_start;
   datetime t_end;
   int      idx_start;   // índice en time[]
   int      idx_end;     // índice en time[] del primer bar FUERA; -1 si aún abierta
   double   hi;
   double   lo;
   bool     is_open;
};

//============================================================
//  NOMBRES DE OBJETOS (constantes y prefijos)
//============================================================

#define BTN_S1    "NYS_B1"
#define BTN_S2    "NYS_B2"
#define BTN_S3    "NYS_B3"
#define BTN_S4    "NYS_B4"
#define LBL_TITLE "NYS_TT"
#define LBL_CLOCK "NYS_CK"

// R=Rect, H=Hi line, M=Mid line, A=Arrow; 1-4=sesión
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

bool g_S1_On, g_S2_On, g_S3_On, g_S4_On;

// Judas de la sesión más reciente:  0=ninguno  1=BUY  -1=SELL
int g_S1_Judas, g_S2_Judas, g_S3_Judas, g_S4_Judas;

//============================================================
//  INIT / DEINIT / CALCULATE / TIMER / CHARTEVENT
//============================================================

int OnInit()
{
   g_S1_On = InpS1_Enable;
   g_S2_On = InpS2_Enable;
   g_S3_On = InpS3_Enable;
   g_S4_On = InpS4_Enable;
   g_S1_Judas = g_S2_Judas = g_S3_Judas = g_S4_Judas = 0;

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
   ProcessAll(rates_total, time, high, low);
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
         int n = ArraySize(blocks);
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
      blocks[n].t_end     = time[total - 1] + (datetime)PeriodSeconds();
      blocks[n].idx_start = idx_s;
      blocks[n].idx_end   = -1;
      blocks[n].hi        = hi;
      blocks[n].lo        = lo;
      blocks[n].is_open   = true;
   }
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

// Línea horizontal con rayo a la derecha (OBJ_TREND + RAY_RIGHT)
void PaintHRay(const string nm,
               datetime t_from, double price,
               color clr, ENUM_LINE_STYLE lstyle, int lw)
{
   // Dos puntos con el mismo precio → línea horizontal
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

// Flecha de Judas (▲ compra / ▼ venta)
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
   // 233 = ▲  241 = flecha arriba sólida  |  234 = ▼  242 = flecha abajo sólida
   ObjectSetInteger(0, nm, OBJPROP_ARROWCODE, isBuy ? 233 : 234);
   ObjectSetInteger(0, nm, OBJPROP_COLOR,     clr);
   ObjectSetInteger(0, nm, OBJPROP_WIDTH,     sz);
   // BUY: ancla en TOP → la punta superior del glifo queda en el low (flecha cuelga abajo)
   // SELL: ancla en BOTTOM → la punta inferior del glifo queda en el high (flecha apunta abajo)
   ObjectSetInteger(0, nm, OBJPROP_ANCHOR,    isBuy ? ANCHOR_TOP : ANCHOR_BOTTOM);
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0, nm, OBJPROP_HIDDEN,    true);
}

// Borra todos los objetos cuyo nombre empieza con pfx
void DeletePfx(const string pfx)
{
   ObjectsDeleteAll(0, pfx);
}

//============================================================
//  DETECCIÓN JUDAS SWING
//============================================================

// Devuelve: 1=BUY (swept lows→espera alza)  -1=SELL (swept highs→espera baja)  0=ninguno
int DetectJudas(const SessBlock &blk,
                const int total,
                const double &high[],
                const double &low[])
{
   if(!InpJudas_Enable || blk.is_open) return 0;
   int preStart = MathMax(0, blk.idx_start - InpJudas_PreBars);
   int preEnd   = blk.idx_start;
   if(preEnd <= preStart) return 0;

   double pre_hi = 0, pre_lo = DBL_MAX;
   for(int j = preStart; j < preEnd; j++)
   {
      if(high[j] > pre_hi) pre_hi = high[j];
      if(low[j]  < pre_lo) pre_lo = low[j];
   }

   bool swept_hi = blk.hi > pre_hi + _Point;
   bool swept_lo = blk.lo < pre_lo - _Point;

   if(swept_hi && !swept_lo) return -1;  // Barrió máximos → SELL (Judas alcista falso)
   if(swept_lo && !swept_hi) return  1;  // Barrió mínimos → BUY  (Judas bajista falso)
   return 0;
}

// Encuentra el índice de barra donde ocurrió el high/low extremo del bloque
int FindExtremumBar(const SessBlock &blk,
                    bool wantHi,
                    const int total,
                    const double &high[],
                    const double &low[])
{
   int end_i = (blk.idx_end < 0) ? (total - 1) : MathMin(blk.idx_end - 1, total - 1);
   double target = wantHi ? blk.hi : blk.lo;
   for(int i = blk.idx_start; i <= end_i; i++)
   {
      double val = wantHi ? high[i] : low[i];
      if(MathAbs(val - target) < _Point) return i;
   }
   return blk.idx_start;
}

//============================================================
//  PROCESAMIENTO POR SESIÓN
//============================================================

// Procesa una sesión completa y devuelve el Judas de la sesión más reciente cerrada
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
                   const double   &high[],
                   const double   &low[])
{
   // 1. Escanear bloques de esta sesión
   SessBlock blocks[];
   ScanBlocks(startBrk, endBrk, total, time, high, low, blocks);
   int nBlocks = ArraySize(blocks);

   // 2. Borrar todos los objetos previos de esta sesión
   DeletePfx(pfx_r);
   DeletePfx(pfx_h);
   DeletePfx(pfx_m);
   DeletePfx(pfx_a);

   if(nBlocks == 0) return 0;

   // 3. Rectángulos para todos los bloques
   for(int i = 0; i < nBlocks; i++)
      PaintRect(pfx_r + IntegerToString(i),
                blocks[i].t_start, blocks[i].t_end,
                blocks[i].hi,      blocks[i].lo,
                clr, opacity);

   // 4. Líneas Hi / Mid y flechas para los últimos InpLinesCount bloques
   int maxL    = (InpLinesCount <= 0) ? nBlocks : MathMin(InpLinesCount, nBlocks);
   int lineFrom = nBlocks - maxL;
   int last_judas = 0;

   for(int i = lineFrom; i < nBlocks; i++)
   {
      double mid = (blocks[i].hi + blocks[i].lo) * 0.5;

      // --- Línea HIGH → derecha infinita
      PaintHRay(pfx_h + IntegerToString(i),
                blocks[i].t_end, blocks[i].hi,
                clr, InpHighLineStyle, InpLineWidth);

      // --- Línea MID 50% → derecha infinita
      PaintHRay(pfx_m + IntegerToString(i),
                blocks[i].t_end, mid,
                clr, InpMidLineStyle, InpLineWidth);

      // --- Judas Swing: solo en bloques cerrados
      if(InpJudas_Enable && !blocks[i].is_open)
      {
         int jType = DetectJudas(blocks[i], total, high, low);
         last_judas = jType;   // el último bloque cerrado define el estado del panel

         if(jType == -1)
         {
            // SELL: swept máximos → flecha ▼ sobre el high de la sesión
            int barHi = FindExtremumBar(blocks[i], true,  total, high, low);
            PaintArrow(pfx_a + IntegerToString(i),
                       time[barHi], high[barHi],
                       false, InpJudas_SellClr, InpJudas_ArrSize);
         }
         else if(jType == 1)
         {
            // BUY: swept mínimos → flecha ▲ bajo el low de la sesión
            int barLo = FindExtremumBar(blocks[i], false, total, high, low);
            PaintArrow(pfx_a + IntegerToString(i),
                       time[barLo], low[barLo],
                       true, InpJudas_BuyClr, InpJudas_ArrSize);
         }
      }
   }
   return last_judas;
}

// Orquesta las 4 sesiones
void ProcessAll(const int      total,
                const datetime &time[],
                const double   &high[],
                const double   &low[])
{
   if(g_S1_On)
      g_S1_Judas = ProcessSession(PFX_R1,PFX_H1,PFX_M1,PFX_A1,
                     NY2Brk(ParseMin(InpS1_StartNY)), NY2Brk(ParseMin(InpS1_EndNY)),
                     InpS1_Color, InpS1_Opacity, total, time, high, low);
   else
   {
      DeletePfx(PFX_R1); DeletePfx(PFX_H1); DeletePfx(PFX_M1); DeletePfx(PFX_A1);
      g_S1_Judas = 0;
   }

   if(g_S2_On)
      g_S2_Judas = ProcessSession(PFX_R2,PFX_H2,PFX_M2,PFX_A2,
                     NY2Brk(ParseMin(InpS2_StartNY)), NY2Brk(ParseMin(InpS2_EndNY)),
                     InpS2_Color, InpS2_Opacity, total, time, high, low);
   else
   {
      DeletePfx(PFX_R2); DeletePfx(PFX_H2); DeletePfx(PFX_M2); DeletePfx(PFX_A2);
      g_S2_Judas = 0;
   }

   if(g_S3_On)
      g_S3_Judas = ProcessSession(PFX_R3,PFX_H3,PFX_M3,PFX_A3,
                     NY2Brk(ParseMin(InpS3_StartNY)), NY2Brk(ParseMin(InpS3_EndNY)),
                     InpS3_Color, InpS3_Opacity, total, time, high, low);
   else
   {
      DeletePfx(PFX_R3); DeletePfx(PFX_H3); DeletePfx(PFX_M3); DeletePfx(PFX_A3);
      g_S3_Judas = 0;
   }

   if(g_S4_On)
      g_S4_Judas = ProcessSession(PFX_R4,PFX_H4,PFX_M4,PFX_A4,
                     NY2Brk(ParseMin(InpS4_StartNY)), NY2Brk(ParseMin(InpS4_EndNY)),
                     InpS4_Color, InpS4_Opacity, total, time, high, low);
   else
   {
      DeletePfx(PFX_R4); DeletePfx(PFX_H4); DeletePfx(PFX_M4); DeletePfx(PFX_A4);
      g_S4_Judas = 0;
   }

   UI_RefreshButtons();
}

// Obtiene datos vía CopyRates y fuerza redibujado (usado en OnChartEvent)
void RedrawFromRates()
{
   MqlRates r[];
   int n = CopyRates(_Symbol, _Period, 0,
                     MathMin(InpLookback + 20, Bars(_Symbol, _Period)), r);
   if(n < 2) return;

   datetime t[]; double hi[], lo[];
   ArrayResize(t, n); ArrayResize(hi, n); ArrayResize(lo, n);
   for(int i = 0; i < n; i++) { t[i]=r[i].time; hi[i]=r[i].high; lo[i]=r[i].low; }
   ProcessAll(n, t, hi, lo);
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
   MakeButton(BTN_S1, 10, y + 33,  185, 24, "", InpS1_Color);
   MakeButton(BTN_S2, 10, y + 61,  185, 24, "", InpS2_Color);
   MakeButton(BTN_S3, 10, y + 89,  185, 24, "", InpS3_Color);
   MakeButton(BTN_S4, 10, y + 117, 185, 24, "", InpS4_Color);
}

string JudasTag(int jType)
{
   if(jType ==  1) return " ▲BUY";
   if(jType == -1) return " ▼SELL";
   return "";
}

void UI_RefreshButtons()
{
   struct BI
   {
      string btn;
      bool   on;
      string name, sNY, eNY;
      color  col;
      int    judas;
   };
   BI b[4];
   b[0].btn=BTN_S1; b[0].on=g_S1_On; b[0].name=InpS1_Name;
   b[0].sNY=InpS1_StartNY; b[0].eNY=InpS1_EndNY; b[0].col=InpS1_Color; b[0].judas=g_S1_Judas;

   b[1].btn=BTN_S2; b[1].on=g_S2_On; b[1].name=InpS2_Name;
   b[1].sNY=InpS2_StartNY; b[1].eNY=InpS2_EndNY; b[1].col=InpS2_Color; b[1].judas=g_S2_Judas;

   b[2].btn=BTN_S3; b[2].on=g_S3_On; b[2].name=InpS3_Name;
   b[2].sNY=InpS3_StartNY; b[2].eNY=InpS3_EndNY; b[2].col=InpS3_Color; b[2].judas=g_S3_Judas;

   b[3].btn=BTN_S4; b[3].on=g_S4_On; b[3].name=InpS4_Name;
   b[3].sNY=InpS4_StartNY; b[3].eNY=InpS4_EndNY; b[3].col=InpS4_Color; b[3].judas=g_S4_Judas;

   for(int i = 0; i < 4; i++)
   {
      int bs = NY2Brk(ParseMin(b[i].sNY));
      int be = NY2Brk(ParseMin(b[i].eNY));
      string xm  = StringFormat("%02d:%02d-%02d:%02d XM", bs/60,bs%60, be/60,be%60);
      string lbl = (b[i].on ? "ON " : "OFF") + " " + b[i].name + " | " + xm + JudasTag(b[i].judas);

      // Color del botón: sesión OFF → gris; ON con Judas → color de la flecha; ON normal → color sesión
      color bg;
      if(!b[i].on)               bg = clrDimGray;
      else if(b[i].judas ==  1)  bg = InpJudas_BuyClr;
      else if(b[i].judas == -1)  bg = InpJudas_SellClr;
      else                       bg = b[i].col;

      ObjectSetString (0, b[i].btn, OBJPROP_TEXT,    lbl);
      ObjectSetInteger(0, b[i].btn, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(0, b[i].btn, OBJPROP_COLOR,   clrWhite);
   }
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
   ChartRedraw();
}

//--- Helpers UI

void MakeButton(const string name,
                int x, int y, int w, int h,
                string txt, color bg)
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

void MakeLabel(const string name,
               int x, int y,
               string txt, color clr, int fs, bool bold)
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
   ObjectDelete(0, LBL_TITLE); ObjectDelete(0, LBL_CLOCK);
   ChartRedraw();
}
//+------------------------------------------------------------------+
