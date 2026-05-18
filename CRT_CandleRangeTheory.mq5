//+------------------------------------------------------------------+
//|                                      CRT_CandleRangeTheory.mq5   |
//|                Candle Range Theory (CRT) - MT5 Indicator          |
//|                   Basado en conceptos ICT / Smart Money           |
//+------------------------------------------------------------------+
//
//  TEORIA CRT - PATRON DE 3 VELAS:
//  ─────────────────────────────────────────────────────────────────
//  C1 (Acumulacion) : Vela de referencia que define el rango
//  C2 (Manipulacion): Barre la liquidez por encima del maximo (RH)
//                     o por debajo del minimo (RL) de C1,
//                     pero CIERRA de vuelta dentro del rango.
//  C3 (Distribucion): El movimiento real hacia el extremo opuesto.
//
//  NIVELES CLAVE:
//  ─────────────────────────────────────────────────────────────────
//  RH  = Range High  (maximo de C1 - zona de liquidez vendedora)
//  RL  = Range Low   (minimo de C1 - zona de liquidez compradora)
//  EQ  = Equilibrium (50% del rango - primer objetivo / entrada)
//  Q3  = 75% del rango (zona premium)
//  Q1  = 25% del rango (zona descuento)
//
//  LOGICA DE ENTRADA:
//  ─────────────────────────────────────────────────────────────────
//  Sweep Alcista : C2 rompe por debajo de RL y cierra sobre RL
//                  → entrada LONG en EQ, objetivo RH
//  Sweep Bajista : C2 rompe por encima de RH y cierra bajo RH
//                  → entrada SHORT en EQ, objetivo RL
//
//+------------------------------------------------------------------+
#property copyright   "CRT - Candle Range Theory"
#property link        ""
#property version     "1.00"
#property description "CRT (Candle Range Theory) basado en ICT/SMC."
#property description "C1: Rango | C2: Sweep de liquidez | C3: Distribucion"
#property description "Marca RH, RL, EQ (50%), Q1 (25%), Q3 (75%) y detecta barridas."
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

input group "══════════ Configuracion CRT ══════════"
input int  InpC1Bars       = 1;      // Lookback C1 (velas antes de C2)
input int  InpMaxRanges    = 20;     // Max rangos CRT a mostrar
input int  InpExtBars      = 50;     // Extension de lineas (velas a la derecha)
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
input bool  InpCloseConfirm = true;   // C2 debe cerrar dentro del rango (regla del wick)
input color InpClrSwpBull   = clrLime; // Color flecha sweep alcista
input color InpClrSwpBear   = clrRed;  // Color flecha sweep bajista
input int   InpArrowSize    = 2;        // Tamano de la flecha

input group "══════════ Alertas ══════════"
input bool InpAlertPopup  = false;  // Alerta emergente
input bool InpAlertEmail  = false;  // Alerta por email
input bool InpAlertPush   = false;  // Notificacion push

//+------------------------------------------------------------------+
//|  BUFFERS E INDICADORES INTERNOS                                  |
//+------------------------------------------------------------------+
double BullBuf[];  // Flechas sweep alcistas
double BearBuf[];  // Flechas sweep bajistas

const string OBJ_PREF    = "CRT_";  // Prefijo de objetos en el grafico
datetime     g_lastAlert = 0;       // Control de ultima alerta enviada

//+------------------------------------------------------------------+
int OnInit()
{
   //--- Asignar buffers
   SetIndexBuffer(0, BullBuf, INDICATOR_DATA);
   SetIndexBuffer(1, BearBuf, INDICATOR_DATA);

   //--- Codigos de flechas (Wingdings)
   PlotIndexSetInteger(0, PLOT_ARROW, 241); // ▲ flecha arriba
   PlotIndexSetInteger(1, PLOT_ARROW, 242); // ▼ flecha abajo

   //--- Valor vacio (sin dibujo)
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   //--- Colores y tamanos de flechas
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpClrSwpBull);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpClrSwpBear);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpArrowSize);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpArrowSize);

   //--- Nombre corto en el panel del indicador
   IndicatorSetString(INDICATOR_SHORTNAME,
      StringFormat("CRT(%d) Candle Range Theory", InpC1Bars));

   //--- Limpiar objetos previos
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

   //--- Barra de inicio del escaneo
   int startBar = fullCalc
                  ? InpC1Bars
                  : MathMax(InpC1Bars, prev_calculated - 1);

   //--- Limite inferior de C1 para controlar la cantidad de rangos mostrados
   int minC1 = MathMax(0, rates_total - 2 - InpMaxRanges);

   //--- Bucle principal
   for(int i = startBar; i < rates_total; i++)
   {
      int c1 = i - InpC1Bars;  // Indice de la vela C1

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

      //--- Deteccion del sweep en C2 (barra actual i) ---

      bool bullSwp, bearSwp;

      if(InpCloseConfirm)
      {
         // Regla estricta: mecha rompe el nivel pero el cuerpo cierra dentro
         bullSwp = (low[i]  < c1L && close[i] > c1L);
         bearSwp = (high[i] > c1H && close[i] < c1H);
      }
      else
      {
         // Regla relajada: cualquier mecha que rompa el nivel
         bullSwp = (low[i]  < c1L);
         bearSwp = (high[i] > c1H);
      }

      //--- Ajuste de offset para flechas (adaptativo al instrumento)
      double arrowOffset = MathMax(_Point * 5.0, (high[i] - low[i]) * 0.05);

      //--- Actualizar buffers de flechas
      if(bullSwp && !bearSwp)
      {
         BullBuf[i] = low[i]  - arrowOffset;
         BearBuf[i] = EMPTY_VALUE;

         // Alerta solo en la vela activa
         if(i == rates_total - 1 && time[i] != g_lastAlert)
            FireAlert("Sweep ALCISTA (RL barrido)", c1L, time[i]);
      }
      else if(bearSwp && !bullSwp)
      {
         BearBuf[i] = high[i] + arrowOffset;
         BullBuf[i] = EMPTY_VALUE;

         if(i == rates_total - 1 && time[i] != g_lastAlert)
            FireAlert("Sweep BAJISTA (RH barrido)", c1H, time[i]);
      }
      else
      {
         BullBuf[i] = EMPTY_VALUE;
         BearBuf[i] = EMPTY_VALUE;
      }

      //--- Dibujar niveles CRT si hay sweep o si se activo "mostrar todo"
      bool shouldDraw = (bullSwp || bearSwp || InpShowAllRanges) && (c1 >= minC1);

      if(shouldDraw)
      {
         DrawCRTLevels(c1, i,
                       bullSwp, bearSwp,
                       c1H, c1L, c1O, c1C, c1R,
                       time, rates_total);
      }
   }

   ChartRedraw(0);
   return rates_total;
}

//+------------------------------------------------------------------+
//|  Dibuja todos los niveles del rango CRT para una vela C1         |
//+------------------------------------------------------------------+
void DrawCRTLevels(int c1Idx,   int c2Idx,
                   bool isBull, bool isBear,
                   double rH,   double rL,
                   double rO,   double rC,
                   double rRange,
                   const datetime &time[],
                   int rates_total)
{
   //--- Calcular niveles porcentuales
   double eq = rL + rRange * 0.50;
   double q1 = rL + rRange * 0.25;
   double q3 = rL + rRange * 0.75;

   //--- Tiempos de inicio y fin de las lineas
   datetime tStart = time[c1Idx];
   datetime tEnd;

   int extIdx = c2Idx + InpExtBars;
   if(extIdx < rates_total)
      tEnd = time[extIdx];
   else
   {
      // Extender hacia el futuro si se agotaron las velas históricas
      int extra = extIdx - (rates_total - 1);
      tEnd = time[rates_total - 1] + (datetime)(extra * PeriodSeconds(PERIOD_CURRENT));
   }

   bool c1Bull = (rC >= rO);
   string sid  = IntegerToString(c1Idx);

   //--- Caja del rango C1
   if(InpShowBox)
   {
      color bc = c1Bull ? InpClrBoxBull : InpClrBoxBear;
      CreateBox(OBJ_PREF + "BOX_" + sid, tStart, rH, tEnd, rL, bc);
   }

   //--- Range High (RH)
   if(InpShowRH)
   {
      CreateLine(OBJ_PREF + "RH_" + sid,
                 tStart, rH, tEnd, rH,
                 InpClrRH, InpStyleHL, InpWidthHL);
      if(InpShowLabels)
         CreateLabel(OBJ_PREF + "RH_L_" + sid,
                     tEnd, rH + rRange * 0.010, " RH", InpClrRH, 8);
   }

   //--- Range Low (RL)
   if(InpShowRL)
   {
      CreateLine(OBJ_PREF + "RL_" + sid,
                 tStart, rL, tEnd, rL,
                 InpClrRL, InpStyleHL, InpWidthHL);
      if(InpShowLabels)
         CreateLabel(OBJ_PREF + "RL_L_" + sid,
                     tEnd, rL - rRange * 0.025, " RL", InpClrRL, 8);
   }

   //--- Equilibrium (EQ 50%)
   if(InpShowEQ)
   {
      CreateLine(OBJ_PREF + "EQ_" + sid,
                 tStart, eq, tEnd, eq,
                 InpClrEQ, InpStyleEQ, InpWidthEQ);
      if(InpShowLabels)
         CreateLabel(OBJ_PREF + "EQ_L_" + sid,
                     tEnd, eq, " EQ 50%", InpClrEQ, 7);
   }

   //--- Q1 (25%)
   if(InpShowQ1)
   {
      CreateLine(OBJ_PREF + "Q1_" + sid,
                 tStart, q1, tEnd, q1,
                 InpClrQ1, InpStyleEQ, InpWidthEQ);
      if(InpShowLabels)
         CreateLabel(OBJ_PREF + "Q1_L_" + sid,
                     tEnd, q1, " Q1 25%", InpClrQ1, 7);
   }

   //--- Q3 (75%)
   if(InpShowQ3)
   {
      CreateLine(OBJ_PREF + "Q3_" + sid,
                 tStart, q3, tEnd, q3,
                 InpClrQ3, InpStyleEQ, InpWidthEQ);
      if(InpShowLabels)
         CreateLabel(OBJ_PREF + "Q3_L_" + sid,
                     tEnd, q3, " Q3 75%", InpClrQ3, 7);
   }

   //--- Objetivo C3 (extremo opuesto al sweep)
   if(InpShowTarget)
   {
      if(isBull && !isBear && c2Idx < rates_total)
      {
         // Sweep alcista → C3 apunta al RH
         CreateLine(OBJ_PREF + "C3T_" + sid,
                    time[c2Idx], rH, tEnd, rH,
                    InpClrTgtBull, STYLE_DOT, 1);
         if(InpShowLabels)
            CreateLabel(OBJ_PREF + "C3L_" + sid,
                        tEnd, rH + rRange * 0.025,
                        " Obj C3 ▲", InpClrTgtBull, 7);
      }
      else if(isBear && !isBull && c2Idx < rates_total)
      {
         // Sweep bajista → C3 apunta al RL
         CreateLine(OBJ_PREF + "C3T_" + sid,
                    time[c2Idx], rL, tEnd, rL,
                    InpClrTgtBear, STYLE_DOT, 1);
         if(InpShowLabels)
            CreateLabel(OBJ_PREF + "C3L_" + sid,
                        tEnd, rL - rRange * 0.040,
                        " Obj C3 ▼", InpClrTgtBear, 7);
      }
   }
}

//+------------------------------------------------------------------+
//|  Crea o actualiza una linea de tendencia (OBJ_TREND)             |
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
//|  Crea o actualiza un rectangulo (caja del rango)                 |
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
void FireAlert(string sweepType, double level, datetime alertTime)
{
   g_lastAlert = alertTime;

   string msg = StringFormat("CRT %s | %s %s | Nivel: %s",
                              sweepType,
                              Symbol(),
                              EnumToString(Period()),
                              DoubleToString(level, _Digits));

   if(InpAlertPopup) Alert(msg);
   if(InpAlertEmail) SendMail("CRT Alerta - " + Symbol(), msg);
   if(InpAlertPush)  SendNotification(msg);
}
//+------------------------------------------------------------------+
