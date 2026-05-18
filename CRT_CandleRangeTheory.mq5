//+------------------------------------------------------------------+
//|                                      CRT_CandleRangeTheory.mq5   |
//|                Candle Range Theory (CRT) - MT5 Indicator          |
//|              Multi-Temporalidad | ICT / Smart Money Concepts       |
//+------------------------------------------------------------------+
//
//  TEORIA CRT - PATRON DE 3 VELAS:
//  ─────────────────────────────────────────────────────────────────
//  C1 (Acumulacion) : Vela de referencia que define el rango
//  C2 (Manipulacion): Barre la liquidez por encima del RH o por
//                     debajo del RL de C1, pero CIERRA de vuelta
//                     dentro del rango (regla del wick).
//  C3 (Distribucion): El movimiento real hacia el extremo opuesto.
//
//  NIVELES CLAVE:
//  ─────────────────────────────────────────────────────────────────
//  RH  = Range High  (maximo C1 - liquidez vendedora)
//  RL  = Range Low   (minimo C1 - liquidez compradora)
//  EQ  = Equilibrium (50% - primer objetivo / zona de entrada)
//  Q3  = 75% del rango (zona premium)
//  Q1  = 25% del rango (zona descuento)
//
//  MULTI-TEMPORALIDAD:
//  ─────────────────────────────────────────────────────────────────
//  Selecciona un Timeframe de referencia distinto al grafico actual.
//  Los niveles CRT se calculan en el TF seleccionado y se pintan
//  sobre el grafico actual. Los sweeps se marcan con flechas en
//  la vela del grafico actual donde ocurrio la barrida en el HTF.
//
//  LOGICA DE ENTRADA:
//  ─────────────────────────────────────────────────────────────────
//  Sweep Alcista : C2 rompe bajo RL y cierra sobre RL → LONG @ EQ
//  Sweep Bajista : C2 rompe sobre RH y cierra bajo RH → SHORT @ EQ
//
//+------------------------------------------------------------------+
#property copyright   "CRT - Candle Range Theory"
#property link        ""
#property version     "2.00"
#property description "CRT (Candle Range Theory) - Multi-Temporalidad"
#property description "C1: Rango | C2: Sweep de liquidez | C3: Distribucion"
#property description "Soporta cualquier Timeframe de referencia (HTF/LTF)."
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

// Buffer 0: Flecha alcista (bajo la vela C2, sweep del minimo)
#property indicator_label1  "CRT Sweep Alcista (RL barrido)"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLime
#property indicator_width1  2

// Buffer 1: Flecha bajista (sobre la vela C2, sweep del maximo)
#property indicator_label2  "CRT Sweep Bajista (RH barrido)"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_width2  2

//+------------------------------------------------------------------+
//|  PARAMETROS DE ENTRADA                                           |
//+------------------------------------------------------------------+

input group "══════════ Multi-Temporalidad ══════════"
input ENUM_TIMEFRAMES InpRefTF = PERIOD_CURRENT; // Timeframe de referencia CRT

input group "══════════ Configuracion CRT ══════════"
input int  InpC1Bars        = 1;     // Lookback C1 (velas antes de C2)
input int  InpMaxRanges     = 20;    // Max rangos CRT a mostrar
input int  InpExtBars       = 50;    // Extension de lineas (velas TF ref. a la derecha)
input bool InpShowAllRanges = false; // Mostrar todos los rangos (sin filtro de sweep)

input group "══════════ Niveles a Mostrar ══════════"
input bool InpShowRH      = true;    // Range High  (RH)
input bool InpShowRL      = true;    // Range Low   (RL)
input bool InpShowEQ      = true;    // Equilibrium (EQ 50%)
input bool InpShowQ3      = false;   // Q3 (75%)
input bool InpShowQ1      = false;   // Q1 (25%)
input bool InpShowBox     = true;    // Caja del rango C1
input bool InpShowLabels  = true;    // Etiquetas de niveles
input bool InpShowTarget  = true;    // Mostrar objetivo C3

input group "══════════ Colores ══════════"
input color InpClrRH       = clrCrimson;        // Color RH
input color InpClrRL       = clrLimeGreen;      // Color RL
input color InpClrEQ       = clrGold;           // Color EQ
input color InpClrQ1       = clrCornflowerBlue; // Color Q1
input color InpClrQ3       = clrOrangeRed;      // Color Q3
input color InpClrBoxBull  = clrForestGreen;    // Color caja C1 alcista
input color InpClrBoxBear  = clrFireBrick;      // Color caja C1 bajista
input color InpClrTgtBull  = clrLime;           // Color objetivo C3 alcista
input color InpClrTgtBear  = clrRed;            // Color objetivo C3 bajista

input group "══════════ Estilo de Lineas ══════════"
input int             InpWidthHL  = 2;           // Ancho RH / RL
input ENUM_LINE_STYLE InpStyleHL  = STYLE_SOLID; // Estilo RH / RL
input int             InpWidthEQ  = 1;           // Ancho EQ / Q
input ENUM_LINE_STYLE InpStyleEQ  = STYLE_DASH;  // Estilo EQ / Q

input group "══════════ Deteccion de Sweep ══════════"
input bool  InpCloseConfirm = true;    // C2 debe cerrar dentro del rango (regla del wick)
input color InpClrSwpBull   = clrLime; // Color flecha sweep alcista
input color InpClrSwpBear   = clrRed;  // Color flecha sweep bajista
input int   InpArrowSize    = 2;       // Tamano de la flecha

input group "══════════ Alertas ══════════"
input bool InpAlertPopup  = false;  // Alerta emergente
input bool InpAlertEmail  = false;  // Alerta por email
input bool InpAlertPush   = false;  // Notificacion push

//+------------------------------------------------------------------+
//|  BUFFERS E INDICADORES INTERNOS                                  |
//+------------------------------------------------------------------+
double BullBuf[];  // Flechas sweep alcistas
double BearBuf[];  // Flechas sweep bajistas

const string OBJ_PREF = "CRT_";
datetime     g_lastAlert = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, BullBuf, INDICATOR_DATA);
   SetIndexBuffer(1, BearBuf, INDICATOR_DATA);

   PlotIndexSetInteger(0, PLOT_ARROW, 241); // ▲
   PlotIndexSetInteger(1, PLOT_ARROW, 242); // ▼

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpClrSwpBull);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpClrSwpBear);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpArrowSize);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpArrowSize);

   // Nombre corto con el TF de referencia
   string tfName = (InpRefTF == PERIOD_CURRENT)
                   ? EnumToString((ENUM_TIMEFRAMES)Period())
                   : EnumToString(InpRefTF);
   IndicatorSetString(INDICATOR_SHORTNAME,
      StringFormat("CRT(%d)[%s]", InpC1Bars, tfName));

   ObjectsDeleteAll(0, OBJ_PREF);
   return INIT_SUCCEEDED;
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
   if(rates_total < InpC1Bars + 2)
      return 0;

   bool fullCalc = (prev_calculated == 0);

   if(fullCalc)
   {
      ArrayInitialize(BullBuf, EMPTY_VALUE);
      ArrayInitialize(BearBuf, EMPTY_VALUE);
      ObjectsDeleteAll(0, OBJ_PREF);
   }

   // Determinar si se usa el TF actual o uno de referencia diferente
   bool useCurrentTF = (InpRefTF == PERIOD_CURRENT) ||
                       ((int)InpRefTF == Period());

   if(useCurrentTF)
      ScanCurrentTF(rates_total, prev_calculated, fullCalc,
                    time, open, high, low, close);
   else
      ScanHTF(rates_total, fullCalc, time, high, low);

   ChartRedraw(0);
   return rates_total;
}

//+------------------------------------------------------------------+
//|  ESCANEO EN TEMPORALIDAD ACTUAL                                  |
//+------------------------------------------------------------------+
void ScanCurrentTF(int rates_total, int prev_calculated, bool fullCalc,
                   const datetime &time[],
                   const double   &open[],
                   const double   &high[],
                   const double   &low[],
                   const double   &close[])
{
   int startBar = fullCalc
                  ? InpC1Bars
                  : MathMax(InpC1Bars, prev_calculated - 1);

   int minC1 = MathMax(0, rates_total - 2 - InpMaxRanges);

   for(int i = startBar; i < rates_total; i++)
   {
      int c1 = i - InpC1Bars;

      double c1H = high[c1];
      double c1L = low[c1];
      double c1O = open[c1];
      double c1C = close[c1];
      double c1R = c1H - c1L;

      if(c1R <= 0.0)
      {
         BullBuf[i] = EMPTY_VALUE;
         BearBuf[i] = EMPTY_VALUE;
         continue;
      }

      bool bullSwp, bearSwp;
      DetectSweep(high[i], low[i], close[i], c1H, c1L,
                  bullSwp, bearSwp);

      double offset = MathMax(_Point * 5.0, (high[i] - low[i]) * 0.05);

      if(bullSwp && !bearSwp)
      {
         BullBuf[i] = low[i]  - offset;
         BearBuf[i] = EMPTY_VALUE;
         if(i == rates_total - 1 && time[i] != g_lastAlert)
            FireAlert("Sweep ALCISTA", c1L, time[i], PERIOD_CURRENT);
      }
      else if(bearSwp && !bullSwp)
      {
         BearBuf[i] = high[i] + offset;
         BullBuf[i] = EMPTY_VALUE;
         if(i == rates_total - 1 && time[i] != g_lastAlert)
            FireAlert("Sweep BAJISTA", c1H, time[i], PERIOD_CURRENT);
      }
      else
      {
         BullBuf[i] = EMPTY_VALUE;
         BearBuf[i] = EMPTY_VALUE;
      }

      if((bullSwp || bearSwp || InpShowAllRanges) && c1 >= minC1)
      {
         // Calcular tEnd en el TF actual
         datetime tEnd;
         int extIdx = i + InpExtBars;
         if(extIdx < rates_total)
            tEnd = time[extIdx];
         else
         {
            int extra = extIdx - (rates_total - 1);
            tEnd = time[rates_total - 1] + (datetime)(extra * PeriodSeconds());
         }

         string sid = IntegerToString((int)time[c1]);
         DrawCRTLevels(time[c1], time[i], tEnd,
                       bullSwp, bearSwp,
                       c1H, c1L, c1O, c1C, c1R, sid);
      }
   }
}

//+------------------------------------------------------------------+
//|  ESCANEO EN TEMPORALIDAD DE REFERENCIA (HTF / LTF)              |
//+------------------------------------------------------------------+
void ScanHTF(int rates_total, bool fullCalc,
             const datetime &time[],
             const double   &high[],
             const double   &low[])
{
   // Obtener datos del TF de referencia
   MqlRates htf[];
   ArraySetAsSeries(htf, false); // indice 0 = mas antiguo

   int numGet = InpMaxRanges + InpC1Bars + 10;
   int copied = CopyRates(Symbol(), InpRefTF, 0, numGet, htf);
   if(copied < InpC1Bars + 2) return;

   // En recalculo completo, reiniciar flechas
   if(fullCalc)
   {
      ArrayInitialize(BullBuf, EMPTY_VALUE);
      ArrayInitialize(BearBuf, EMPTY_VALUE);
   }

   int minC1 = MathMax(0, copied - InpMaxRanges - InpC1Bars);
   long tfSeconds = PeriodSeconds(InpRefTF);

   for(int i = InpC1Bars; i < copied; i++)
   {
      int c1 = i - InpC1Bars;
      if(c1 < minC1) continue;

      double c1H = htf[c1].high;
      double c1L = htf[c1].low;
      double c1O = htf[c1].open;
      double c1C = htf[c1].close;
      double c1R = c1H - c1L;

      if(c1R <= 0.0) continue;

      bool bullSwp, bearSwp;
      DetectSweep(htf[i].high, htf[i].low, htf[i].close, c1H, c1L,
                  bullSwp, bearSwp);

      double offset = MathMax(_Point * 5.0, c1R * 0.05);

      if(bullSwp && !bearSwp)
      {
         // Buscar la vela del grafico actual donde ocurrio el sweep
         int barIdx = FindBarByTime(time, rates_total, htf[i].time);
         if(barIdx >= 0 && barIdx < rates_total)
            BullBuf[barIdx] = htf[i].low - offset;

         if(i == copied - 1 && htf[i].time != g_lastAlert)
            FireAlert("Sweep ALCISTA HTF", c1L, htf[i].time, InpRefTF);
      }
      else if(bearSwp && !bullSwp)
      {
         int barIdx = FindBarByTime(time, rates_total, htf[i].time);
         if(barIdx >= 0 && barIdx < rates_total)
            BearBuf[barIdx] = htf[i].high + offset;

         if(i == copied - 1 && htf[i].time != g_lastAlert)
            FireAlert("Sweep BAJISTA HTF", c1H, htf[i].time, InpRefTF);
      }

      if(bullSwp || bearSwp || InpShowAllRanges)
      {
         datetime tC2  = htf[i].time;
         datetime tEnd = tC2 + (datetime)(InpExtBars * tfSeconds);
         string   sid  = IntegerToString((int)htf[c1].time);

         DrawCRTLevels(htf[c1].time, tC2, tEnd,
                       bullSwp, bearSwp,
                       c1H, c1L, c1O, c1C, c1R, sid);
      }
   }
}

//+------------------------------------------------------------------+
//|  Logica comun de deteccion de sweep (C2)                         |
//+------------------------------------------------------------------+
void DetectSweep(double c2High, double c2Low, double c2Close,
                 double c1High, double c1Low,
                 bool &outBull,  bool &outBear)
{
   if(InpCloseConfirm)
   {
      outBull = (c2Low  < c1Low  && c2Close > c1Low);
      outBear = (c2High > c1High && c2Close < c1High);
   }
   else
   {
      outBull = (c2Low  < c1Low);
      outBear = (c2High > c1High);
   }
}

//+------------------------------------------------------------------+
//|  Dibuja todos los niveles del rango CRT                          |
//|  Acepta datetime directamente (compatible con cualquier TF)      |
//+------------------------------------------------------------------+
void DrawCRTLevels(datetime tC1,   datetime tC2,
                   datetime tEnd,
                   bool isBull,    bool isBear,
                   double rH,      double rL,
                   double rO,      double rC,
                   double rRange,  string sid)
{
   double eq = rL + rRange * 0.50;
   double q1 = rL + rRange * 0.25;
   double q3 = rL + rRange * 0.75;

   bool c1Bull = (rC >= rO);

   //--- Caja del rango C1
   if(InpShowBox)
   {
      color bc = c1Bull ? InpClrBoxBull : InpClrBoxBear;
      CreateBox(OBJ_PREF + "BOX_" + sid, tC1, rH, tEnd, rL, bc);
   }

   //--- Range High (RH)
   if(InpShowRH)
   {
      CreateLine(OBJ_PREF + "RH_" + sid,
                 tC1, rH, tEnd, rH,
                 InpClrRH, InpStyleHL, InpWidthHL);
      if(InpShowLabels)
         CreateLabel(OBJ_PREF + "RH_L_" + sid,
                     tEnd, rH + rRange * 0.010, " RH", InpClrRH, 8);
   }

   //--- Range Low (RL)
   if(InpShowRL)
   {
      CreateLine(OBJ_PREF + "RL_" + sid,
                 tC1, rL, tEnd, rL,
                 InpClrRL, InpStyleHL, InpWidthHL);
      if(InpShowLabels)
         CreateLabel(OBJ_PREF + "RL_L_" + sid,
                     tEnd, rL - rRange * 0.025, " RL", InpClrRL, 8);
   }

   //--- Equilibrium (EQ 50%)
   if(InpShowEQ)
   {
      CreateLine(OBJ_PREF + "EQ_" + sid,
                 tC1, eq, tEnd, eq,
                 InpClrEQ, InpStyleEQ, InpWidthEQ);
      if(InpShowLabels)
         CreateLabel(OBJ_PREF + "EQ_L_" + sid,
                     tEnd, eq, " EQ 50%", InpClrEQ, 7);
   }

   //--- Q1 (25%)
   if(InpShowQ1)
   {
      CreateLine(OBJ_PREF + "Q1_" + sid,
                 tC1, q1, tEnd, q1,
                 InpClrQ1, InpStyleEQ, InpWidthEQ);
      if(InpShowLabels)
         CreateLabel(OBJ_PREF + "Q1_L_" + sid,
                     tEnd, q1, " Q1 25%", InpClrQ1, 7);
   }

   //--- Q3 (75%)
   if(InpShowQ3)
   {
      CreateLine(OBJ_PREF + "Q3_" + sid,
                 tC1, q3, tEnd, q3,
                 InpClrQ3, InpStyleEQ, InpWidthEQ);
      if(InpShowLabels)
         CreateLabel(OBJ_PREF + "Q3_L_" + sid,
                     tEnd, q3, " Q3 75%", InpClrQ3, 7);
   }

   //--- Objetivo C3 (extremo opuesto al sweep)
   if(InpShowTarget)
   {
      if(isBull && !isBear)
      {
         CreateLine(OBJ_PREF + "C3T_" + sid,
                    tC2, rH, tEnd, rH,
                    InpClrTgtBull, STYLE_DOT, 1);
         if(InpShowLabels)
            CreateLabel(OBJ_PREF + "C3L_" + sid,
                        tEnd, rH + rRange * 0.025,
                        " Obj C3 ▲", InpClrTgtBull, 7);
      }
      else if(isBear && !isBull)
      {
         CreateLine(OBJ_PREF + "C3T_" + sid,
                    tC2, rL, tEnd, rL,
                    InpClrTgtBear, STYLE_DOT, 1);
         if(InpShowLabels)
            CreateLabel(OBJ_PREF + "C3L_" + sid,
                        tEnd, rL - rRange * 0.040,
                        " Obj C3 ▼", InpClrTgtBear, 7);
      }
   }
}

//+------------------------------------------------------------------+
//|  Busca el indice de la vela del grafico actual mas cercana        |
//|  a un timestamp dado (busqueda binaria, time[] ordenado ASC)      |
//+------------------------------------------------------------------+
int FindBarByTime(const datetime &time[], int total, datetime target)
{
   if(total <= 0) return -1;

   int lo = 0, hi = total - 1;

   while(lo <= hi)
   {
      int mid = (lo + hi) / 2;
      if(time[mid] == target) return mid;
      if(time[mid] < target)  lo = mid + 1;
      else                    hi = mid - 1;
   }
   // Retorna la vela con tiempo <= target (floor)
   return MathMax(0, hi);
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
//|  Envia alertas al usuario                                        |
//+------------------------------------------------------------------+
void FireAlert(string sweepType, double level,
               datetime alertTime, ENUM_TIMEFRAMES tf)
{
   g_lastAlert = alertTime;

   string tfStr = (tf == PERIOD_CURRENT)
                  ? EnumToString((ENUM_TIMEFRAMES)Period())
                  : EnumToString(tf);

   string msg = StringFormat("CRT %s [%s] | %s | Nivel: %s",
                              sweepType, tfStr,
                              Symbol(),
                              DoubleToString(level, _Digits));

   if(InpAlertPopup) Alert(msg);
   if(InpAlertEmail) SendMail("CRT Alerta - " + Symbol(), msg);
   if(InpAlertPush)  SendNotification(msg);
}
//+------------------------------------------------------------------+
