//+------------------------------------------------------------------+
//|                                      CRT_CandleRangeTheory.mq5   |
//|       Candle Range Theory - Multi-Temporalidad Simultanea         |
//|              ICT / Smart Money Concepts  v3.00                    |
//+------------------------------------------------------------------+
//
//  TEORIA CRT - PATRON DE 3 VELAS:
//  ─────────────────────────────────────────────────────────────────
//  C1 (Acumulacion) : Vela de referencia que define el rango
//  C2 (Manipulacion): Barre liquidez sobre RH o bajo RL de C1
//                     pero CIERRA de vuelta dentro del rango.
//  C3 (Distribucion): Movimiento real hacia el extremo opuesto.
//
//  NIVELES CLAVE:
//  ─────────────────────────────────────────────────────────────────
//  RH = Range High  | RL = Range Low | EQ = Equilibrium 50%
//  Q3 = 75%         | Q1 = 25%
//
//  MULTI-TEMPORALIDAD:
//  ─────────────────────────────────────────────────────────────────
//  Activa independientemente cada TF: M1 M5 M15 M30 H1 H4 D1 W1 MN
//  Cada TF tiene su propio color. Todos se muestran simultaneamente
//  sobre cualquier grafico, con etiquetas que identifican el TF.
//
//+------------------------------------------------------------------+
#property copyright   "CRT - Candle Range Theory"
#property link        ""
#property version     "3.00"
#property description "CRT Multi-TF: muestra patrones de varias temporalidades"
#property description "a la vez. Activa M1..MN individualmente con colores propios."
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//+------------------------------------------------------------------+
//|  PARAMETROS DE ENTRADA                                           |
//+------------------------------------------------------------------+

input group "══════════ Temporalidades Activas ══════════"
input bool InpUsM1  = false; // M1  - 1 Minuto
input bool InpUsM5  = false; // M5  - 5 Minutos
input bool InpUsM15 = false; // M15 - 15 Minutos
input bool InpUsM30 = false; // M30 - 30 Minutos
input bool InpUsH1  = false; // H1  - 1 Hora
input bool InpUsH4  = true;  // H4  - 4 Horas
input bool InpUsD1  = true;  // D1  - Diario
input bool InpUsW1  = false; // W1  - Semanal
input bool InpUsMN  = false; // MN  - Mensual

input group "══════════ Colores por Temporalidad ══════════"
input color InpClrM1  = clrSilver;      // Color M1
input color InpClrM5  = clrAqua;        // Color M5
input color InpClrM15 = clrDodgerBlue;  // Color M15
input color InpClrM30 = clrMediumOrchid;// Color M30
input color InpClrH1  = clrGold;        // Color H1
input color InpClrH4  = clrOrange;      // Color H4
input color InpClrD1  = clrOrangeRed;   // Color D1
input color InpClrW1  = clrMagenta;     // Color W1
input color InpClrMN  = clrPlum;        // Color MN

input group "══════════ Configuracion CRT ══════════"
input int  InpC1Bars        = 1;     // Lookback C1 (velas antes de C2)
input int  InpMaxRanges     = 10;    // Max rangos por temporalidad
input int  InpExtBars       = 40;    // Extension de lineas (velas del TF ref.)
input bool InpShowAllRanges = false; // Mostrar todos los rangos (sin sweep)

input group "══════════ Niveles a Mostrar ══════════"
input bool InpShowRH     = true;  // Range High  (RH)
input bool InpShowRL     = true;  // Range Low   (RL)
input bool InpShowEQ     = true;  // Equilibrium (EQ 50%)
input bool InpShowQ3     = false; // Q3 (75%)
input bool InpShowQ1     = false; // Q1 (25%)
input bool InpShowBox    = true;  // Caja del rango C1
input bool InpShowLabels = true;  // Etiquetas con TF
input bool InpShowTarget = true;  // Objetivo C3

input group "══════════ Estilo de Lineas ══════════"
input int             InpWidthHL = 2;           // Ancho RH / RL
input ENUM_LINE_STYLE InpStyleHL = STYLE_SOLID; // Estilo RH / RL
input int             InpWidthEQ = 1;           // Ancho EQ / Q
input ENUM_LINE_STYLE InpStyleEQ = STYLE_DASH;  // Estilo EQ / Q

input group "══════════ Deteccion de Sweep ══════════"
input bool InpCloseConfirm = true; // C2 debe cerrar dentro del rango
input int  InpArrowSize    = 2;    // Tamano de flecha de sweep

input group "══════════ Alertas ══════════"
input bool InpAlertPopup = false; // Alerta emergente
input bool InpAlertEmail = false; // Alerta por email
input bool InpAlertPush  = false; // Notificacion push

//+------------------------------------------------------------------+
//|  ESTRUCTURA Y GLOBALES                                           |
//+------------------------------------------------------------------+
struct TFConfig
{
   ENUM_TIMEFRAMES tf;
   color           clr;
   string          label;
};

TFConfig g_tfs[];
int      g_tfCount  = 0;

const string OBJ_PREF  = "CRT_";
datetime     g_lastAlert = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   // Construir lista de TFs activos
   g_tfCount = 0;
   ArrayResize(g_tfs, 0);

   AddTF(InpUsM1,  PERIOD_M1,  InpClrM1,  "M1");
   AddTF(InpUsM5,  PERIOD_M5,  InpClrM5,  "M5");
   AddTF(InpUsM15, PERIOD_M15, InpClrM15, "M15");
   AddTF(InpUsM30, PERIOD_M30, InpClrM30, "M30");
   AddTF(InpUsH1,  PERIOD_H1,  InpClrH1,  "H1");
   AddTF(InpUsH4,  PERIOD_H4,  InpClrH4,  "H4");
   AddTF(InpUsD1,  PERIOD_D1,  InpClrD1,  "D1");
   AddTF(InpUsW1,  PERIOD_W1,  InpClrW1,  "W1");
   AddTF(InpUsMN,  PERIOD_MN1, InpClrMN,  "MN");

   // Nombre del indicador con TFs activos
   string tfNames = "";
   for(int k = 0; k < g_tfCount; k++)
      tfNames += (k > 0 ? "," : "") + g_tfs[k].label;
   if(tfNames == "") tfNames = "ninguno";
   IndicatorSetString(INDICATOR_SHORTNAME,
      StringFormat("CRT(%d)[%s]", InpC1Bars, tfNames));

   ObjectsDeleteAll(0, OBJ_PREF);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void AddTF(bool enabled, ENUM_TIMEFRAMES tf, color clr, string label)
{
   if(!enabled) return;
   int idx = g_tfCount++;
   ArrayResize(g_tfs, g_tfCount);
   g_tfs[idx].tf    = tf;
   g_tfs[idx].clr   = clr;
   g_tfs[idx].label = label;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, OBJ_PREF);
   ChartRedraw(0);
}

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
   if(rates_total < InpC1Bars + 2 || g_tfCount == 0)
      return 0;

   bool fullCalc = (prev_calculated == 0);
   if(fullCalc)
      ObjectsDeleteAll(0, OBJ_PREF);

   // Escanear cada temporalidad activa
   for(int k = 0; k < g_tfCount; k++)
   {
      bool isCurrent = ((int)g_tfs[k].tf == Period());

      if(isCurrent)
         ScanCurrentTF(rates_total, prev_calculated, fullCalc,
                       time, open, high, low, close,
                       g_tfs[k].clr, g_tfs[k].label);
      else
         ScanHTF(rates_total, fullCalc,
                 time, open, high, low, close,
                 g_tfs[k].tf, g_tfs[k].clr, g_tfs[k].label);
   }

   ChartRedraw(0);
   return rates_total;
}

//+------------------------------------------------------------------+
//|  ESCANEO - TEMPORALIDAD ACTUAL DEL GRAFICO                       |
//+------------------------------------------------------------------+
void ScanCurrentTF(int rates_total, int prev_calculated, bool fullCalc,
                   const datetime &time[],
                   const double   &open[],
                   const double   &high[],
                   const double   &low[],
                   const double   &close[],
                   color tfClr, string tfLabel)
{
   int startBar = fullCalc
                  ? InpC1Bars
                  : MathMax(InpC1Bars, prev_calculated - 1);
   int minC1 = MathMax(0, rates_total - 2 - InpMaxRanges);

   for(int i = startBar; i < rates_total; i++)
   {
      int c1 = i - InpC1Bars;
      double c1H = high[c1], c1L = low[c1];
      double c1O = open[c1], c1C = close[c1];
      double c1R = c1H - c1L;
      if(c1R <= 0.0) continue;

      bool bullSwp, bearSwp;
      DetectSweep(high[i], low[i], close[i], c1H, c1L, bullSwp, bearSwp);

      double offset = MathMax(_Point * 5.0, (high[i] - low[i]) * 0.05);

      if(bullSwp && !bearSwp)
      {
         PlaceSweepArrow(OBJ_PREF + tfLabel + "_SWP_B_" + IntegerToString((int)time[i]),
                         time[i], low[i] - offset, true, tfClr);
         if(i == rates_total - 1 && time[i] != g_lastAlert)
            FireAlert("Sweep ALCISTA", c1L, time[i], tfLabel);
      }
      else if(bearSwp && !bullSwp)
      {
         PlaceSweepArrow(OBJ_PREF + tfLabel + "_SWP_S_" + IntegerToString((int)time[i]),
                         time[i], high[i] + offset, false, tfClr);
         if(i == rates_total - 1 && time[i] != g_lastAlert)
            FireAlert("Sweep BAJISTA", c1H, time[i], tfLabel);
      }

      if((bullSwp || bearSwp || InpShowAllRanges) && c1 >= minC1)
      {
         datetime tEnd;
         int extIdx = i + InpExtBars;
         if(extIdx < rates_total)
            tEnd = time[extIdx];
         else
            tEnd = time[rates_total-1] + (datetime)((extIdx - rates_total + 1) * PeriodSeconds());

         string sid = tfLabel + "_" + IntegerToString((int)time[c1]);
         DrawCRTLevels(time[c1], time[i], tEnd,
                       bullSwp, bearSwp,
                       c1H, c1L, c1O, c1C, c1R,
                       sid, tfClr, tfLabel);
      }
   }
}

//+------------------------------------------------------------------+
//|  ESCANEO - TEMPORALIDAD DE REFERENCIA (CopyRates)                |
//+------------------------------------------------------------------+
void ScanHTF(int rates_total, bool fullCalc,
             const datetime &time[],
             const double   &open[],
             const double   &high[],
             const double   &low[],
             const double   &close[],
             ENUM_TIMEFRAMES tf, color tfClr, string tfLabel)
{
   MqlRates htf[];
   ArraySetAsSeries(htf, false);

   int numGet = InpMaxRanges + InpC1Bars + 10;
   int copied = CopyRates(Symbol(), tf, 0, numGet, htf);
   if(copied < InpC1Bars + 2) return;

   int minC1    = MathMax(0, copied - InpMaxRanges - InpC1Bars);
   long tfSecs  = PeriodSeconds(tf);

   for(int i = InpC1Bars; i < copied; i++)
   {
      int c1 = i - InpC1Bars;
      if(c1 < minC1) continue;

      double c1H = htf[c1].high, c1L = htf[c1].low;
      double c1O = htf[c1].open, c1C = htf[c1].close;
      double c1R = c1H - c1L;
      if(c1R <= 0.0) continue;

      bool bullSwp, bearSwp;
      DetectSweep(htf[i].high, htf[i].low, htf[i].close, c1H, c1L, bullSwp, bearSwp);

      double offset = MathMax(_Point * 5.0, c1R * 0.05);

      if(bullSwp && !bearSwp)
      {
         PlaceSweepArrow(OBJ_PREF + tfLabel + "_SWP_B_" + IntegerToString((int)htf[i].time),
                         htf[i].time, htf[i].low - offset, true, tfClr);
         if(i == copied - 1 && htf[i].time != g_lastAlert)
            FireAlert("Sweep ALCISTA", c1L, htf[i].time, tfLabel);
      }
      else if(bearSwp && !bullSwp)
      {
         PlaceSweepArrow(OBJ_PREF + tfLabel + "_SWP_S_" + IntegerToString((int)htf[i].time),
                         htf[i].time, htf[i].high + offset, false, tfClr);
         if(i == copied - 1 && htf[i].time != g_lastAlert)
            FireAlert("Sweep BAJISTA", c1H, htf[i].time, tfLabel);
      }

      if(bullSwp || bearSwp || InpShowAllRanges)
      {
         datetime tC2  = htf[i].time;
         datetime tEnd = tC2 + (datetime)(InpExtBars * tfSecs);
         string   sid  = tfLabel + "_" + IntegerToString((int)htf[c1].time);

         DrawCRTLevels(htf[c1].time, tC2, tEnd,
                       bullSwp, bearSwp,
                       c1H, c1L, c1O, c1C, c1R,
                       sid, tfClr, tfLabel);
      }
   }
}

//+------------------------------------------------------------------+
//|  Logica de deteccion de sweep (compartida)                       |
//+------------------------------------------------------------------+
void DetectSweep(double c2H, double c2L, double c2C,
                 double c1H, double c1L,
                 bool &outBull, bool &outBear)
{
   if(InpCloseConfirm)
   {
      outBull = (c2L < c1L && c2C > c1L);
      outBear = (c2H > c1H && c2C < c1H);
   }
   else
   {
      outBull = (c2L < c1L);
      outBear = (c2H > c1H);
   }
}

//+------------------------------------------------------------------+
//|  Dibuja el conjunto completo de niveles CRT para un C1           |
//+------------------------------------------------------------------+
void DrawCRTLevels(datetime tC1,   datetime tC2,
                   datetime tEnd,
                   bool isBull,    bool isBear,
                   double rH,      double rL,
                   double rO,      double rC,
                   double rRange,  string sid,
                   color  tfClr,   string tfLabel)
{
   double eq = rL + rRange * 0.50;
   double q1 = rL + rRange * 0.25;
   double q3 = rL + rRange * 0.75;

   bool c1Bull = (rC >= rO);

   //--- Caja del rango
   if(InpShowBox)
   {
      color bc = c1Bull ? tfClr : BlendColor(tfClr, clrBlack, 40);
      CreateBox(OBJ_PREF + "BOX_" + sid, tC1, rH, tEnd, rL, bc);
   }

   //--- Range High
   if(InpShowRH)
   {
      string lbl = InpShowLabels ? " RH [" + tfLabel + "]" : "";
      CreateLine(OBJ_PREF + "RH_" + sid,
                 tC1, rH, tEnd, rH, tfClr, InpStyleHL, InpWidthHL);
      if(InpShowLabels)
         CreateLabel(OBJ_PREF + "RHL_" + sid,
                     tEnd, rH + rRange * 0.010, lbl, tfClr, 7);
   }

   //--- Range Low
   if(InpShowRL)
   {
      string lbl = InpShowLabels ? " RL [" + tfLabel + "]" : "";
      CreateLine(OBJ_PREF + "RL_" + sid,
                 tC1, rL, tEnd, rL, tfClr, InpStyleHL, InpWidthHL);
      if(InpShowLabels)
         CreateLabel(OBJ_PREF + "RLL_" + sid,
                     tEnd, rL - rRange * 0.025, lbl, tfClr, 7);
   }

   //--- Equilibrium (EQ 50%)
   if(InpShowEQ)
   {
      string lbl = InpShowLabels ? " EQ [" + tfLabel + "]" : "";
      CreateLine(OBJ_PREF + "EQ_" + sid,
                 tC1, eq, tEnd, eq, tfClr, InpStyleEQ, InpWidthEQ);
      if(InpShowLabels)
         CreateLabel(OBJ_PREF + "EQL_" + sid,
                     tEnd, eq, lbl, tfClr, 7);
   }

   //--- Q1 (25%)
   if(InpShowQ1)
   {
      string lbl = InpShowLabels ? " Q1 [" + tfLabel + "]" : "";
      CreateLine(OBJ_PREF + "Q1_" + sid,
                 tC1, q1, tEnd, q1, tfClr, STYLE_DOT, 1);
      if(InpShowLabels)
         CreateLabel(OBJ_PREF + "Q1L_" + sid,
                     tEnd, q1, lbl, tfClr, 7);
   }

   //--- Q3 (75%)
   if(InpShowQ3)
   {
      string lbl = InpShowLabels ? " Q3 [" + tfLabel + "]" : "";
      CreateLine(OBJ_PREF + "Q3_" + sid,
                 tC1, q3, tEnd, q3, tfClr, STYLE_DOT, 1);
      if(InpShowLabels)
         CreateLabel(OBJ_PREF + "Q3L_" + sid,
                     tEnd, q3, lbl, tfClr, 7);
   }

   //--- Objetivo C3
   if(InpShowTarget)
   {
      if(isBull && !isBear)
      {
         CreateLine(OBJ_PREF + "C3T_" + sid,
                    tC2, rH, tEnd, rH, tfClr, STYLE_DOT, 1);
         if(InpShowLabels)
            CreateLabel(OBJ_PREF + "C3L_" + sid,
                        tEnd, rH + rRange * 0.030,
                        " C3 ▲ [" + tfLabel + "]", tfClr, 7);
      }
      else if(isBear && !isBull)
      {
         CreateLine(OBJ_PREF + "C3T_" + sid,
                    tC2, rL, tEnd, rL, tfClr, STYLE_DOT, 1);
         if(InpShowLabels)
            CreateLabel(OBJ_PREF + "C3L_" + sid,
                        tEnd, rL - rRange * 0.045,
                        " C3 ▼ [" + tfLabel + "]", tfClr, 7);
      }
   }
}

//+------------------------------------------------------------------+
//|  Coloca una flecha de sweep en el grafico                        |
//+------------------------------------------------------------------+
void PlaceSweepArrow(string name, datetime t, double price,
                     bool isUp, color clr)
{
   if(ObjectFind(0, name) >= 0) return; // ya existe

   ObjectCreate(0, name, OBJ_ARROW, 0, t, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, isUp ? 241 : 242);
   ObjectSetInteger(0, name, OBJPROP_COLOR,     clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH,     InpArrowSize);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,    true);
}

//+------------------------------------------------------------------+
//|  Mezcla dos colores (para variaciones de caja)                   |
//|  En MQL5 el color se almacena como 0x00BBGGRR                    |
//+------------------------------------------------------------------+
color BlendColor(color c1, color c2, int pct)
{
   int r = (int)(c1 & 0xFF)        * (100 - pct) / 100
         + (int)(c2 & 0xFF)        * pct / 100;
   int g = (int)((c1 >> 8)  & 0xFF) * (100 - pct) / 100
         + (int)((c2 >> 8)  & 0xFF) * pct / 100;
   int b = (int)((c1 >> 16) & 0xFF) * (100 - pct) / 100
         + (int)((c2 >> 16) & 0xFF) * pct / 100;
   return (color)(r | (g << 8) | (b << 16));
}

//+------------------------------------------------------------------+
//|  Crea o actualiza una linea de tendencia                         |
//+------------------------------------------------------------------+
void CreateLine(string name,
                datetime t1, double p1,
                datetime t2, double p2,
                color clr, ENUM_LINE_STYLE style, int width)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT,  false);
      ObjectSetInteger(0, name, OBJPROP_RAY_LEFT,   false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
   }
   else
   {
      ObjectSetInteger(0, name, OBJPROP_TIME,  1, t2);
      ObjectSetDouble( 0, name, OBJPROP_PRICE, 1, p2);
   }
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
}

//+------------------------------------------------------------------+
//|  Crea o actualiza un rectangulo                                  |
//+------------------------------------------------------------------+
void CreateBox(string name,
               datetime t1, double pTop,
               datetime t2, double pBot,
               color clr)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, pTop, t2, pBot);
      ObjectSetInteger(0, name, OBJPROP_COLOR,      clr);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR,    clr);
      ObjectSetInteger(0, name, OBJPROP_FILL,       true);
      ObjectSetInteger(0, name, OBJPROP_BACK,       true);
      ObjectSetInteger(0, name, OBJPROP_STYLE,      STYLE_SOLID);
      ObjectSetInteger(0, name, OBJPROP_WIDTH,      1);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
   }
   else
      ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
}

//+------------------------------------------------------------------+
//|  Crea o actualiza una etiqueta de texto                          |
//+------------------------------------------------------------------+
void CreateLabel(string name, datetime t, double price,
                 string text, color clr, int fontSize)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, 0, t, price);
   else
   {
      ObjectSetInteger(0, name, OBJPROP_TIME,  0, t);
      ObjectSetDouble( 0, name, OBJPROP_PRICE, 0, price);
   }
   ObjectSetString( 0, name, OBJPROP_TEXT,       text);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,   fontSize);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
}

//+------------------------------------------------------------------+
//|  Envia alertas                                                   |
//+------------------------------------------------------------------+
void FireAlert(string sweepType, double level,
               datetime alertTime, string tfLabel)
{
   g_lastAlert = alertTime;
   string msg  = StringFormat("CRT %s [%s] | %s | Nivel: %s",
                               sweepType, tfLabel, Symbol(),
                               DoubleToString(level, _Digits));
   if(InpAlertPopup) Alert(msg);
   if(InpAlertEmail) SendMail("CRT Alerta [" + tfLabel + "] - " + Symbol(), msg);
   if(InpAlertPush)  SendNotification(msg);
}
//+------------------------------------------------------------------+
