//+------------------------------------------------------------------+
//|                                      CRT_CandleRangeTheory.mq5   |
//|       Candle Range Theory - Multi-Temporalidad Total              |
//|              ICT / Smart Money Concepts  v4.00                    |
//+------------------------------------------------------------------+
//
//  PATRON CRT (3 velas):
//  C1 = Rango de referencia  |  C2 = Sweep de liquidez
//  C3 = Distribucion hacia el extremo opuesto
//
//  NIVELES: RH (max) | RL (min) | EQ 50% | Q3 75% | Q1 25%
//
//  TEMPORALIDADES MT5 DISPONIBLES:
//  Minutos : M1 M2 M3 M4 M5 M6 M10 M12 M15 M20 M30
//  Horas   : H1 H2 H3 H4 H6 H8 H12
//  Mayores : D1 W1 MN
//  NOTA: H5, H7, H9, H10, H11 NO existen en MT5 como TF estandar.
//
//  CADA TF TIENE:  ON/OFF | Color propio | Cantidad de CRT a mostrar
//
//+------------------------------------------------------------------+
#property copyright   "CRT - Candle Range Theory"
#property link        ""
#property version     "4.00"
#property description "CRT Multi-TF Total | Todas las temporalidades MT5"
#property description "ON/OFF + Color + Cantidad de rangos por cada TF"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//+------------------------------------------------------------------+
//|  TEMPORALIDADES - MINUTOS                                        |
//+------------------------------------------------------------------+
input group "══ Minutos ══  [ ON/OFF | Color | Cantidad CRT ]"
input bool  InpUsM1  = false;        // M1  Activo
input color InpClrM1 = clrSilver;   // M1  Color
input int   InpNumM1 = 5;           // M1  Rangos a mostrar

input bool  InpUsM2  = false;        // M2  Activo
input color InpClrM2 = clrLightCyan; // M2  Color
input int   InpNumM2 = 5;            // M2  Rangos a mostrar

input bool  InpUsM3  = false;        // M3  Activo
input color InpClrM3 = clrCyan;     // M3  Color
input int   InpNumM3 = 5;           // M3  Rangos a mostrar

input bool  InpUsM4  = false;         // M4  Activo
input color InpClrM4 = clrTurquoise; // M4  Color
input int   InpNumM4 = 5;            // M4  Rangos a mostrar

input bool  InpUsM5  = false;          // M5  Activo
input color InpClrM5 = clrDodgerBlue; // M5  Color
input int   InpNumM5 = 5;             // M5  Rangos a mostrar

input bool  InpUsM6  = false;              // M6  Activo
input color InpClrM6 = clrCornflowerBlue; // M6  Color
input int   InpNumM6 = 5;                 // M6  Rangos a mostrar

input bool  InpUsM10  = false;         // M10 Activo
input color InpClrM10 = clrMediumBlue; // M10 Color
input int   InpNumM10 = 5;             // M10 Rangos a mostrar

input bool  InpUsM12  = false;          // M12 Activo
input color InpClrM12 = clrBlueViolet; // M12 Color
input int   InpNumM12 = 5;             // M12 Rangos a mostrar

input bool  InpUsM15  = false;           // M15 Activo
input color InpClrM15 = clrMediumOrchid; // M15 Color
input int   InpNumM15 = 5;              // M15 Rangos a mostrar

input bool  InpUsM20  = false;       // M20 Activo
input color InpClrM20 = clrOrchid;   // M20 Color
input int   InpNumM20 = 5;           // M20 Rangos a mostrar

input bool  InpUsM30  = false;      // M30 Activo
input color InpClrM30 = clrHotPink; // M30 Color
input int   InpNumM30 = 5;          // M30 Rangos a mostrar

//+------------------------------------------------------------------+
//|  TEMPORALIDADES - HORAS                                          |
//+------------------------------------------------------------------+
input group "══ Horas ══  [ ON/OFF | Color | Cantidad CRT ]"
input bool  InpUsH1  = false;      // H1  Activo
input color InpClrH1 = clrGold;   // H1  Color
input int   InpNumH1 = 5;         // H1  Rangos a mostrar

input bool  InpUsH2  = false;          // H2  Activo
input color InpClrH2 = clrGoldenrod;  // H2  Color
input int   InpNumH2 = 5;             // H2  Rangos a mostrar

input bool  InpUsH3  = false;          // H3  Activo
input color InpClrH3 = clrDarkOrange; // H3  Color
input int   InpNumH3 = 5;             // H3  Rangos a mostrar

input bool  InpUsH4  = true;        // H4  Activo
input color InpClrH4 = clrOrange;  // H4  Color
input int   InpNumH4 = 8;          // H4  Rangos a mostrar

input bool  InpUsH6  = false;          // H6  Activo
input color InpClrH6 = clrOrangeRed;  // H6  Color
input int   InpNumH6 = 5;             // H6  Rangos a mostrar

input bool  InpUsH8  = false;      // H8  Activo
input color InpClrH8 = clrTomato; // H8  Color
input int   InpNumH8 = 5;         // H8  Rangos a mostrar

input bool  InpUsH12  = false;         // H12 Activo
input color InpClrH12 = clrFireBrick; // H12 Color
input int   InpNumH12 = 5;            // H12 Rangos a mostrar

//+------------------------------------------------------------------+
//|  TEMPORALIDADES - DIARIO / SEMANAL / MENSUAL                     |
//+------------------------------------------------------------------+
input group "══ Diario · Semanal · Mensual ══  [ ON/OFF | Color | Cantidad ]"
input bool  InpUsD1  = true;        // D1  Activo
input color InpClrD1 = clrCrimson; // D1  Color
input int   InpNumD1 = 5;          // D1  Rangos a mostrar

input bool  InpUsW1  = false;        // W1  Activo
input color InpClrW1 = clrMagenta;  // W1  Color
input int   InpNumW1 = 3;           // W1  Rangos a mostrar

input bool  InpUsMN  = false;       // MN  Activo
input color InpClrMN = clrPlum;    // MN  Color
input int   InpNumMN = 2;          // MN  Rangos a mostrar

//+------------------------------------------------------------------+
//|  CONFIGURACION CRT GENERAL                                       |
//+------------------------------------------------------------------+
input group "══ Configuracion CRT ══"
input int  InpC1Bars        = 1;     // Lookback C1 (velas antes de C2)
input int  InpExtBars       = 40;    // Extension lineas (velas del TF ref.)
input bool InpShowAllRanges = false; // Mostrar todos los rangos (sin sweep)

input group "══ Niveles a Mostrar ══"
input bool InpShowRH     = true;    // Range High  (RH)
input bool InpShowRL     = true;    // Range Low   (RL)
input bool InpShowEQ     = true;    // Equilibrium (EQ 50%)
input bool InpShowQ3     = false;   // Q3 (75%)
input bool InpShowQ1     = false;   // Q1 (25%)
input bool InpShowBox    = true;    // Caja del rango C1
input bool InpShowLabels = true;    // Etiquetas [TF]
input bool InpShowTarget = true;    // Objetivo C3

input group "══ Estilo de Lineas ══"
input int             InpWidthHL = 2;           // Ancho RH / RL
input ENUM_LINE_STYLE InpStyleHL = STYLE_SOLID; // Estilo RH / RL
input int             InpWidthEQ = 1;           // Ancho EQ / Q
input ENUM_LINE_STYLE InpStyleEQ = STYLE_DASH;  // Estilo EQ / Q

input group "══ Deteccion de Sweep ══"
input bool InpCloseConfirm = true;  // C2 debe cerrar dentro del rango
input int  InpArrowSize    = 2;     // Tamano de flecha de sweep

input group "══ Alertas ══"
input bool InpAlertPopup = false;   // Alerta emergente
input bool InpAlertEmail = false;   // Alerta por email
input bool InpAlertPush  = false;   // Notificacion push

//+------------------------------------------------------------------+
//|  ESTRUCTURA Y GLOBALES                                           |
//+------------------------------------------------------------------+
struct TFConfig
{
   ENUM_TIMEFRAMES tf;
   color           clr;
   string          label;
   int             maxRanges;
};

TFConfig g_tfs[];
int      g_tfCount  = 0;

const string OBJ_PREF  = "CRT_";
datetime     g_lastAlert = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   g_tfCount = 0;
   ArrayResize(g_tfs, 0);

   // ── Minutos ──
   AddTF(InpUsM1,  PERIOD_M1,  InpClrM1,  "M1",  InpNumM1);
   AddTF(InpUsM2,  PERIOD_M2,  InpClrM2,  "M2",  InpNumM2);
   AddTF(InpUsM3,  PERIOD_M3,  InpClrM3,  "M3",  InpNumM3);
   AddTF(InpUsM4,  PERIOD_M4,  InpClrM4,  "M4",  InpNumM4);
   AddTF(InpUsM5,  PERIOD_M5,  InpClrM5,  "M5",  InpNumM5);
   AddTF(InpUsM6,  PERIOD_M6,  InpClrM6,  "M6",  InpNumM6);
   AddTF(InpUsM10, PERIOD_M10, InpClrM10, "M10", InpNumM10);
   AddTF(InpUsM12, PERIOD_M12, InpClrM12, "M12", InpNumM12);
   AddTF(InpUsM15, PERIOD_M15, InpClrM15, "M15", InpNumM15);
   AddTF(InpUsM20, PERIOD_M20, InpClrM20, "M20", InpNumM20);
   AddTF(InpUsM30, PERIOD_M30, InpClrM30, "M30", InpNumM30);

   // ── Horas ──
   AddTF(InpUsH1,  PERIOD_H1,  InpClrH1,  "H1",  InpNumH1);
   AddTF(InpUsH2,  PERIOD_H2,  InpClrH2,  "H2",  InpNumH2);
   AddTF(InpUsH3,  PERIOD_H3,  InpClrH3,  "H3",  InpNumH3);
   AddTF(InpUsH4,  PERIOD_H4,  InpClrH4,  "H4",  InpNumH4);
   AddTF(InpUsH6,  PERIOD_H6,  InpClrH6,  "H6",  InpNumH6);
   AddTF(InpUsH8,  PERIOD_H8,  InpClrH8,  "H8",  InpNumH8);
   AddTF(InpUsH12, PERIOD_H12, InpClrH12, "H12", InpNumH12);

   // ── Mayores ──
   AddTF(InpUsD1, PERIOD_D1,  InpClrD1, "D1", InpNumD1);
   AddTF(InpUsW1, PERIOD_W1,  InpClrW1, "W1", InpNumW1);
   AddTF(InpUsMN, PERIOD_MN1, InpClrMN, "MN", InpNumMN);

   // Nombre del indicador
   string names = "";
   for(int k = 0; k < g_tfCount; k++)
      names += (k > 0 ? "," : "") + g_tfs[k].label;
   if(names == "") names = "ninguno";
   IndicatorSetString(INDICATOR_SHORTNAME,
      StringFormat("CRT(%d)[%s]", InpC1Bars, names));

   ObjectsDeleteAll(0, OBJ_PREF);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void AddTF(bool enabled, ENUM_TIMEFRAMES tf, color clr,
           string label, int maxRanges)
{
   if(!enabled) return;
   int idx = g_tfCount++;
   ArrayResize(g_tfs, g_tfCount);
   g_tfs[idx].tf        = tf;
   g_tfs[idx].clr       = clr;
   g_tfs[idx].label     = label;
   g_tfs[idx].maxRanges = MathMax(1, maxRanges);
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

   for(int k = 0; k < g_tfCount; k++)
   {
      bool isCurrent = ((int)g_tfs[k].tf == Period());

      if(isCurrent)
         ScanCurrentTF(rates_total, prev_calculated, fullCalc,
                       time, open, high, low, close,
                       g_tfs[k].clr, g_tfs[k].label, g_tfs[k].maxRanges);
      else
         ScanHTF(rates_total, fullCalc,
                 time, open, high, low, close,
                 g_tfs[k].tf, g_tfs[k].clr, g_tfs[k].label, g_tfs[k].maxRanges);
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
                   color tfClr, string tfLabel, int maxRanges)
{
   int startBar = fullCalc
                  ? InpC1Bars
                  : MathMax(InpC1Bars, prev_calculated - 1);
   int minC1 = MathMax(0, rates_total - 2 - maxRanges);

   for(int i = startBar; i < rates_total; i++)
   {
      int c1 = i - InpC1Bars;
      double c1H = high[c1],  c1L = low[c1];
      double c1O = open[c1],  c1C = close[c1];
      double c1R = c1H - c1L;
      if(c1R <= 0.0) continue;

      bool bullSwp, bearSwp;
      DetectSweep(high[i], low[i], close[i], c1H, c1L, bullSwp, bearSwp);

      double offset = MathMax(_Point * 5.0, (high[i] - low[i]) * 0.05);

      if(bullSwp && !bearSwp)
      {
         PlaceSweepArrow(OBJ_PREF + tfLabel + "_B_" + IntegerToString((int)time[i]),
                         time[i], low[i] - offset, true, tfClr);
         if(i == rates_total - 1 && time[i] != g_lastAlert)
            FireAlert("Sweep ALCISTA", c1L, time[i], tfLabel);
      }
      else if(bearSwp && !bullSwp)
      {
         PlaceSweepArrow(OBJ_PREF + tfLabel + "_S_" + IntegerToString((int)time[i]),
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

         DrawCRTLevels(time[c1], time[i], tEnd, bullSwp, bearSwp,
                       c1H, c1L, c1O, c1C, c1R,
                       tfLabel + "_" + IntegerToString((int)time[c1]),
                       tfClr, tfLabel);
      }
   }
}

//+------------------------------------------------------------------+
//|  ESCANEO - OTRA TEMPORALIDAD (CopyRates)                         |
//+------------------------------------------------------------------+
void ScanHTF(int rates_total, bool fullCalc,
             const datetime &time[],
             const double   &open[],
             const double   &high[],
             const double   &low[],
             const double   &close[],
             ENUM_TIMEFRAMES tf, color tfClr, string tfLabel, int maxRanges)
{
   MqlRates htf[];
   ArraySetAsSeries(htf, false);

   int copied = CopyRates(Symbol(), tf, 0, maxRanges + InpC1Bars + 10, htf);
   if(copied < InpC1Bars + 2) return;

   int minC1   = MathMax(0, copied - maxRanges - InpC1Bars);
   long tfSecs = PeriodSeconds(tf);

   for(int i = InpC1Bars; i < copied; i++)
   {
      int c1 = i - InpC1Bars;
      if(c1 < minC1) continue;

      double c1H = htf[c1].high,  c1L = htf[c1].low;
      double c1O = htf[c1].open,  c1C = htf[c1].close;
      double c1R = c1H - c1L;
      if(c1R <= 0.0) continue;

      bool bullSwp, bearSwp;
      DetectSweep(htf[i].high, htf[i].low, htf[i].close, c1H, c1L, bullSwp, bearSwp);

      double offset = MathMax(_Point * 5.0, c1R * 0.05);

      if(bullSwp && !bearSwp)
      {
         PlaceSweepArrow(OBJ_PREF + tfLabel + "_B_" + IntegerToString((int)htf[i].time),
                         htf[i].time, htf[i].low - offset, true, tfClr);
         if(i == copied - 1 && htf[i].time != g_lastAlert)
            FireAlert("Sweep ALCISTA", c1L, htf[i].time, tfLabel);
      }
      else if(bearSwp && !bullSwp)
      {
         PlaceSweepArrow(OBJ_PREF + tfLabel + "_S_" + IntegerToString((int)htf[i].time),
                         htf[i].time, htf[i].high + offset, false, tfClr);
         if(i == copied - 1 && htf[i].time != g_lastAlert)
            FireAlert("Sweep BAJISTA", c1H, htf[i].time, tfLabel);
      }

      if(bullSwp || bearSwp || InpShowAllRanges)
      {
         datetime tEnd = htf[i].time + (datetime)(InpExtBars * tfSecs);
         DrawCRTLevels(htf[c1].time, htf[i].time, tEnd, bullSwp, bearSwp,
                       c1H, c1L, c1O, c1C, c1R,
                       tfLabel + "_" + IntegerToString((int)htf[c1].time),
                       tfClr, tfLabel);
      }
   }
}

//+------------------------------------------------------------------+
//|  Deteccion de sweep C2                                           |
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
//|  Dibuja todos los niveles CRT                                    |
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

   if(InpShowBox)
   {
      color bc = c1Bull ? tfClr : BlendColor(tfClr, clrBlack, 40);
      CreateBox(OBJ_PREF + "BOX_" + sid, tC1, rH, tEnd, rL, bc);
   }
   if(InpShowRH)
   {
      CreateLine(OBJ_PREF + "RH_" + sid, tC1, rH, tEnd, rH,
                 tfClr, InpStyleHL, InpWidthHL);
      if(InpShowLabels)
         CreateLabel(OBJ_PREF + "RHL_" + sid, tEnd, rH + rRange * 0.010,
                     " RH [" + tfLabel + "]", tfClr, 7);
   }
   if(InpShowRL)
   {
      CreateLine(OBJ_PREF + "RL_" + sid, tC1, rL, tEnd, rL,
                 tfClr, InpStyleHL, InpWidthHL);
      if(InpShowLabels)
         CreateLabel(OBJ_PREF + "RLL_" + sid, tEnd, rL - rRange * 0.025,
                     " RL [" + tfLabel + "]", tfClr, 7);
   }
   if(InpShowEQ)
   {
      CreateLine(OBJ_PREF + "EQ_" + sid, tC1, eq, tEnd, eq,
                 tfClr, InpStyleEQ, InpWidthEQ);
      if(InpShowLabels)
         CreateLabel(OBJ_PREF + "EQL_" + sid, tEnd, eq,
                     " EQ [" + tfLabel + "]", tfClr, 7);
   }
   if(InpShowQ1)
   {
      CreateLine(OBJ_PREF + "Q1_" + sid, tC1, q1, tEnd, q1,
                 tfClr, STYLE_DOT, 1);
      if(InpShowLabels)
         CreateLabel(OBJ_PREF + "Q1L_" + sid, tEnd, q1,
                     " Q1 [" + tfLabel + "]", tfClr, 7);
   }
   if(InpShowQ3)
   {
      CreateLine(OBJ_PREF + "Q3_" + sid, tC1, q3, tEnd, q3,
                 tfClr, STYLE_DOT, 1);
      if(InpShowLabels)
         CreateLabel(OBJ_PREF + "Q3L_" + sid, tEnd, q3,
                     " Q3 [" + tfLabel + "]", tfClr, 7);
   }
   if(InpShowTarget)
   {
      if(isBull && !isBear)
      {
         CreateLine(OBJ_PREF + "C3T_" + sid, tC2, rH, tEnd, rH,
                    tfClr, STYLE_DOT, 1);
         if(InpShowLabels)
            CreateLabel(OBJ_PREF + "C3L_" + sid, tEnd, rH + rRange * 0.030,
                        " C3 ▲ [" + tfLabel + "]", tfClr, 7);
      }
      else if(isBear && !isBull)
      {
         CreateLine(OBJ_PREF + "C3T_" + sid, tC2, rL, tEnd, rL,
                    tfClr, STYLE_DOT, 1);
         if(InpShowLabels)
            CreateLabel(OBJ_PREF + "C3L_" + sid, tEnd, rL - rRange * 0.045,
                        " C3 ▼ [" + tfLabel + "]", tfClr, 7);
      }
   }
}

//+------------------------------------------------------------------+
//|  Flecha de sweep                                                 |
//+------------------------------------------------------------------+
void PlaceSweepArrow(string name, datetime t, double price,
                     bool isUp, color clr)
{
   if(ObjectFind(0, name) >= 0) return;
   ObjectCreate(0, name, OBJ_ARROW, 0, t, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE,  isUp ? 241 : 242);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH,      InpArrowSize);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
}

//+------------------------------------------------------------------+
//|  Mezcla dos colores - formato MQL5: 0x00BBGGRR                   |
//+------------------------------------------------------------------+
color BlendColor(color c1, color c2, int pct)
{
   int r = (int)(c1 & 0xFF)         * (100 - pct) / 100
         + (int)(c2 & 0xFF)         * pct / 100;
   int g = (int)((c1 >> 8)  & 0xFF) * (100 - pct) / 100
         + (int)((c2 >> 8)  & 0xFF) * pct / 100;
   int b = (int)((c1 >> 16) & 0xFF) * (100 - pct) / 100
         + (int)((c2 >> 16) & 0xFF) * pct / 100;
   return (color)(r | (g << 8) | (b << 16));
}

//+------------------------------------------------------------------+
//|  Linea de tendencia                                              |
//+------------------------------------------------------------------+
void CreateLine(string name,
                datetime t1, double p1, datetime t2, double p2,
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
//|  Rectangulo                                                      |
//+------------------------------------------------------------------+
void CreateBox(string name,
               datetime t1, double pTop, datetime t2, double pBot,
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
//|  Etiqueta de texto                                               |
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
//|  Alertas                                                         |
//+------------------------------------------------------------------+
void FireAlert(string sweepType, double level,
               datetime alertTime, string tfLabel)
{
   g_lastAlert = alertTime;
   string msg  = StringFormat("CRT %s [%s] | %s | Nivel: %s",
                               sweepType, tfLabel, Symbol(),
                               DoubleToString(level, _Digits));
   if(InpAlertPopup) Alert(msg);
   if(InpAlertEmail) SendMail("CRT [" + tfLabel + "] - " + Symbol(), msg);
   if(InpAlertPush)  SendNotification(msg);
}
//+------------------------------------------------------------------+
