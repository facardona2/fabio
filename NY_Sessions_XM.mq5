//+------------------------------------------------------------------+
//|                       NY_Sessions_XM.mq5                         |
//|          Indicador de Sesiones Nueva York para Broker XM         |
//|                                                                  |
//|  Offset por defecto: Broker XM = Hora NY + 7 horas              |
//|  Ejemplo: NY 15:16  ->  XM 22:16                                 |
//|                                                                  |
//|  Sesiones NY predefinidas:                                       |
//|    S1: 20:30 - 21:00  =>  XM 03:30 - 04:00                      |
//|    S2: 01:30 - 02:00  =>  XM 08:30 - 09:00                      |
//|    S3: 06:30 - 07:00  =>  XM 13:30 - 14:00                      |
//|    S4: 13:30 - 14:00  =>  XM 20:30 - 21:00                      |
//+------------------------------------------------------------------+
#property copyright   "2024"
#property version     "1.00"
#property description "Sesiones NY con botones ON/OFF para broker XM"
#property indicator_chart_window
#property indicator_plots 0

//--- Separadores visuales en el panel de inputs
sinput string  _sep0 = "════ CONFIGURACIÓN HORARIA ════";   // ──────────────────────
input  int     InpNYOffset  = 7;     // Diferencia horaria Broker vs NY (horas)
input  int     InpLookback  = 500;   // Barras históricas a analizar

//--- Sesión 1
sinput string  _sep1 = "════ SESIÓN 1 ════";                // ──────────────────────
input  bool    InpS1_Enable  = true;         // S1: Activa al iniciar
input  string  InpS1_Name    = "NY 20:30";   // S1: Etiqueta
input  string  InpS1_StartNY = "20:30";      // S1: Inicio (hora Nueva York)
input  string  InpS1_EndNY   = "21:00";      // S1: Fin    (hora Nueva York)
input  color   InpS1_Color   = clrDodgerBlue;// S1: Color del rectángulo
input  int     InpS1_Opacity = 60;           // S1: Opacidad % (0=transparente, 100=sólido)

//--- Sesión 2
sinput string  _sep2 = "════ SESIÓN 2 ════";
input  bool    InpS2_Enable  = true;
input  string  InpS2_Name    = "NY 01:30";
input  string  InpS2_StartNY = "01:30";
input  string  InpS2_EndNY   = "02:00";
input  color   InpS2_Color   = clrLimeGreen;
input  int     InpS2_Opacity = 60;

//--- Sesión 3
sinput string  _sep3 = "════ SESIÓN 3 ════";
input  bool    InpS3_Enable  = true;
input  string  InpS3_Name    = "NY 06:30";
input  string  InpS3_StartNY = "06:30";
input  string  InpS3_EndNY   = "07:00";
input  color   InpS3_Color   = clrOrange;
input  int     InpS3_Opacity = 60;

//--- Sesión 4
sinput string  _sep4 = "════ SESIÓN 4 ════";
input  bool    InpS4_Enable  = true;
input  string  InpS4_Name    = "NY 13:30";
input  string  InpS4_StartNY = "13:30";
input  string  InpS4_EndNY   = "14:00";
input  color   InpS4_Color   = clrMagenta;
input  int     InpS4_Opacity = 60;

//--- Estado ON/OFF de cada sesión (runtime)
bool g_S1_On, g_S2_On, g_S3_On, g_S4_On;

//--- Nombres de objetos UI (prefijos y IDs fijos)
#define OBJ_PREFIX   "NYS_"
#define BTN_S1       "NYS_BTN_1"
#define BTN_S2       "NYS_BTN_2"
#define BTN_S3       "NYS_BTN_3"
#define BTN_S4       "NYS_BTN_4"
#define LBL_TITLE    "NYS_TITLE"
#define LBL_CLOCK    "NYS_CLOCK"
#define RECT_PFX_S1  "NYS_R1_"
#define RECT_PFX_S2  "NYS_R2_"
#define RECT_PFX_S3  "NYS_R3_"
#define RECT_PFX_S4  "NYS_R4_"

//+------------------------------------------------------------------+
//| INIT                                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   g_S1_On = InpS1_Enable;
   g_S2_On = InpS2_Enable;
   g_S3_On = InpS3_Enable;
   g_S4_On = InpS4_Enable;

   UI_Build();
   UI_RefreshButtons();
   EventSetTimer(1);   // Actualizar reloj cada segundo
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINIT                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   Cleanup();
}

//+------------------------------------------------------------------+
//| CALCULATE                                                        |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double   &open[],
                const double   &high[],
                const double   &low[],
                const double   &close[],
                const long     &tick_volume[],
                const long     &volume[],
                const int      &spread[])
{
   DrawAllSessions(rates_total, time, high, low);
   UI_UpdateClock();
   return rates_total;
}

//+------------------------------------------------------------------+
//| TIMER – actualiza el reloj cada segundo                          |
//+------------------------------------------------------------------+
void OnTimer()
{
   UI_UpdateClock();
}

//+------------------------------------------------------------------+
//| CHARTEVENT – detecta clics en botones                            |
//+------------------------------------------------------------------+
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

   // Redibujar rectángulos con el estado nuevo
   MqlRates r[];
   int n = CopyRates(_Symbol, _Period, 0, MathMin(InpLookback + 20, Bars(_Symbol, _Period)), r);
   if(n > 1)
   {
      datetime t[]; double hi[], lo[];
      ArrayResize(t, n); ArrayResize(hi, n); ArrayResize(lo, n);
      for(int i = 0; i < n; i++) { t[i] = r[i].time; hi[i] = r[i].high; lo[i] = r[i].low; }
      DrawAllSessions(n, t, hi, lo);
   }
   ChartRedraw();
}

//+------------------------------------------------------------------+
//============================================================
//  LÓGICA HORARIA
//============================================================

// Parsea "HH:MM" y devuelve minutos desde medianoche
int ParseMin(const string s)
{
   string p[];
   if(StringSplit(s, ':', p) < 2) return 0;
   return (int)StringToInteger(p[0]) * 60 + (int)StringToInteger(p[1]);
}

// Convierte minutos NY a minutos broker
int NY2Brk(int nyMin)
{
   return ((nyMin + InpNYOffset * 60) % 1440 + 1440) % 1440;
}

// Decide si barMin (minutos broker) cae dentro de [startBrk, endBrk)
bool InSession(int barMin, int startBrk, int endBrk)
{
   if(startBrk < endBrk)
      return (barMin >= startBrk && barMin < endBrk);
   // Sesión cruza medianoche broker
   return (barMin >= startBrk || barMin < endBrk);
}

//============================================================
//  DIBUJO DE RECTÁNGULOS
//============================================================

// Dibuja (o actualiza) un rectángulo OBJ_RECTANGLE relleno
void PaintRect(const string name,
               const datetime t1,  const datetime t2,
               const double   top, const double   bot,
               const color    clr, const int      opacityPct)
{
   uchar alpha    = (uchar)(opacityPct * 255 / 100);
   uint  argbColor = ColorToARGB(clr, alpha);

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, top, t2, bot);
   else
   {
      ObjectSetInteger(0, name, OBJPROP_TIME,  0, t1);
      ObjectSetDouble (0, name, OBJPROP_PRICE, 0, top);
      ObjectSetInteger(0, name, OBJPROP_TIME,  1, t2);
      ObjectSetDouble (0, name, OBJPROP_PRICE, 1, bot);
   }
   ObjectSetInteger(0, name, OBJPROP_COLOR,      argbColor);
   ObjectSetInteger(0, name, OBJPROP_STYLE,      STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH,      1);
   ObjectSetInteger(0, name, OBJPROP_FILL,       true);
   ObjectSetInteger(0, name, OBJPROP_BACK,       true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
}

// Elimina todos los rectángulos de una sesión (por prefijo + índice secuencial)
void DeleteRects(const string pfx)
{
   for(int i = 0; i < 10000; i++)
   {
      string nm = pfx + IntegerToString(i);
      if(ObjectFind(0, nm) >= 0) ObjectDelete(0, nm);
      else                       break;
   }
}

// Dibuja los rectángulos de UNA sesión
void DrawSession(const string   pfx,
                 const int      startBrk,
                 const int      endBrk,
                 const color    clr,
                 const int      opacity,
                 const int      total,
                 const datetime &time[],
                 const double   &high[],
                 const double   &low[])
{
   int lookback = MathMin(InpLookback, total - 1);
   int from     = total - lookback - 1;
   if(from < 0) from = 0;

   bool     inSess  = false;
   int      idx     = 0;
   datetime t0      = 0;
   double   hi      = 0;
   double   lo      = DBL_MAX;

   for(int i = from; i < total; i++)
   {
      MqlDateTime dt;
      TimeToStruct(time[i], dt);
      int barMin = dt.hour * 60 + dt.min;
      bool inside = InSession(barMin, startBrk, endBrk);

      if(inside && !inSess)
      {
         inSess = true;
         t0 = time[i];
         hi = high[i];
         lo = low[i];
      }
      else if(inside && inSess)
      {
         if(high[i] > hi) hi = high[i];
         if(low[i]  < lo) lo = low[i];
      }
      else if(!inside && inSess)
      {
         inSess = false;
         PaintRect(pfx + IntegerToString(idx++), t0, time[i], hi, lo, clr, opacity);
         hi = 0; lo = DBL_MAX;
      }
   }
   // Sesión aún abierta al final del buffer
   if(inSess)
   {
      datetime tEnd = time[total - 1] + (datetime)PeriodSeconds();
      PaintRect(pfx + IntegerToString(idx), t0, tEnd, hi, lo, clr, opacity);
   }
}

// Orquesta las 4 sesiones
void DrawAllSessions(const int      total,
                     const datetime &time[],
                     const double   &high[],
                     const double   &low[])
{
   // Sesión 1
   if(g_S1_On)
      DrawSession(RECT_PFX_S1,
                  NY2Brk(ParseMin(InpS1_StartNY)), NY2Brk(ParseMin(InpS1_EndNY)),
                  InpS1_Color, InpS1_Opacity, total, time, high, low);
   else
      DeleteRects(RECT_PFX_S1);

   // Sesión 2
   if(g_S2_On)
      DrawSession(RECT_PFX_S2,
                  NY2Brk(ParseMin(InpS2_StartNY)), NY2Brk(ParseMin(InpS2_EndNY)),
                  InpS2_Color, InpS2_Opacity, total, time, high, low);
   else
      DeleteRects(RECT_PFX_S2);

   // Sesión 3
   if(g_S3_On)
      DrawSession(RECT_PFX_S3,
                  NY2Brk(ParseMin(InpS3_StartNY)), NY2Brk(ParseMin(InpS3_EndNY)),
                  InpS3_Color, InpS3_Opacity, total, time, high, low);
   else
      DeleteRects(RECT_PFX_S3);

   // Sesión 4
   if(g_S4_On)
      DrawSession(RECT_PFX_S4,
                  NY2Brk(ParseMin(InpS4_StartNY)), NY2Brk(ParseMin(InpS4_EndNY)),
                  InpS4_Color, InpS4_Opacity, total, time, high, low);
   else
      DeleteRects(RECT_PFX_S4);
}

//============================================================
//  INTERFAZ DE USUARIO
//============================================================

void UI_Build()
{
   // Título
   MakeLabel(LBL_TITLE, 10, 5,
             "  NY SESSIONS  XM  ", clrGold, 9, true);

   // Reloj
   MakeLabel(LBL_CLOCK, 10, 20,
             "NY --:--:--  |  XM --:--:--", clrSilver, 8, false);

   // Botones (x=10, y empieza en 38, paso de 28)
   MakeButton(BTN_S1, 10, 38,  170, 24, "", InpS1_Color);
   MakeButton(BTN_S2, 10, 66,  170, 24, "", InpS2_Color);
   MakeButton(BTN_S3, 10, 94,  170, 24, "", InpS3_Color);
   MakeButton(BTN_S4, 10, 122, 170, 24, "", InpS4_Color);
}

void UI_RefreshButtons()
{
   struct BInfo { string btn; bool on; string name; string sNY; string eNY; color col; };
   BInfo b[4];
   b[0].btn=BTN_S1; b[0].on=g_S1_On; b[0].name=InpS1_Name; b[0].sNY=InpS1_StartNY; b[0].eNY=InpS1_EndNY; b[0].col=InpS1_Color;
   b[1].btn=BTN_S2; b[1].on=g_S2_On; b[1].name=InpS2_Name; b[1].sNY=InpS2_StartNY; b[1].eNY=InpS2_EndNY; b[1].col=InpS2_Color;
   b[2].btn=BTN_S3; b[2].on=g_S3_On; b[2].name=InpS3_Name; b[2].sNY=InpS3_StartNY; b[2].eNY=InpS3_EndNY; b[2].col=InpS3_Color;
   b[3].btn=BTN_S4; b[3].on=g_S4_On; b[3].name=InpS4_Name; b[3].sNY=InpS4_StartNY; b[3].eNY=InpS4_EndNY; b[3].col=InpS4_Color;

   for(int i = 0; i < 4; i++)
   {
      // Calcular hora equivalente broker
      int bs = NY2Brk(ParseMin(b[i].sNY));
      int be = NY2Brk(ParseMin(b[i].eNY));
      string xmStr = StringFormat("%02d:%02d-%02d:%02d XM", bs/60, bs%60, be/60, be%60);
      string lbl   = (b[i].on ? "ON " : "OFF") + "  " + b[i].name + " | " + xmStr;

      ObjectSetString (0, b[i].btn, OBJPROP_TEXT,    lbl);
      ObjectSetInteger(0, b[i].btn, OBJPROP_BGCOLOR, b[i].on ? b[i].col : (color)clrDimGray);
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
                              dN.hour, dN.min, dN.sec,
                              dB.hour, dB.min, dB.sec);
   ObjectSetString(0, LBL_CLOCK, OBJPROP_TEXT, txt);
   ChartRedraw();
}

//--- Helpers de creación de objetos gráficos

void MakeButton(const string name,
                const int x, const int y,
                const int w, const int h,
                const string txt,
                const color  bg)
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
               const int x, const int y,
               const string txt,
               const color clr,
               const int   fs,
               const bool  bold)
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

//--- Limpieza total al cerrar
void Cleanup()
{
   DeleteRects(RECT_PFX_S1);
   DeleteRects(RECT_PFX_S2);
   DeleteRects(RECT_PFX_S3);
   DeleteRects(RECT_PFX_S4);
   ObjectDelete(0, BTN_S1);
   ObjectDelete(0, BTN_S2);
   ObjectDelete(0, BTN_S3);
   ObjectDelete(0, BTN_S4);
   ObjectDelete(0, LBL_TITLE);
   ObjectDelete(0, LBL_CLOCK);
   ChartRedraw();
}
//+------------------------------------------------------------------+
