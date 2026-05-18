//+------------------------------------------------------------------+
//|                                              Smart_FVG_MTF.mq5   |
//|   Smart Multi-Timeframe Fair Value Gap indicator                 |
//|                                                                  |
//|   Reglas:                                                        |
//|     - Detecta FVG alcistas y bajistas en cualquier temporalidad. |
//|     - Filtro por tendencia (EMA rapida vs EMA lenta) en el TF    |
//|       analizado: solo dibuja FVG alcistas si la tendencia esta   |
//|       alcista en ese momento; FVG bajistas si esta bajista.      |
//|     - Si la tendencia cambia (bull->bear o bear->bull), a partir |
//|       de ese instante se marcan FVG de la nueva direccion.       |
//|     - Inteligente: descarta FVG mitigados; resalta los que       |
//|       siguen sin mitigar despues de N swings o cuando el precio  |
//|       se aproxima a 1-2 pips de la zona.                         |
//|     - Boton ON/OFF en pantalla para activar/desactivar.          |
//|     - Selector de temporalidad (con opcion de forzar >= H4).     |
//+------------------------------------------------------------------+
#property copyright "Smart FVG MTF"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_plots 0

//==================================================================
//  INPUTS
//==================================================================
input group "=== General ==="
input bool             InpEnabled        = true;            // Activar indicador al inicio
input ENUM_TIMEFRAMES  InpTimeframe      = PERIOD_H4;       // Temporalidad de analisis FVG
input bool             InpEnforceMin4H   = false;           // Forzar TF minimo H4
input int              InpMaxBarsBack    = 1500;            // Maximo de barras a escanear
input int              InpMaxFVGs        = 60;              // Maximo de FVG visibles
input int              InpExtendBars     = 25;              // Barras de extension hacia el futuro

input group "=== Filtro de Tendencia ==="
input int              InpEmaFast        = 20;              // EMA rapida
input int              InpEmaSlow        = 50;              // EMA lenta
input bool             InpShowTrendLabel = true;            // Mostrar etiqueta de tendencia

input group "=== Inteligencia / Mitigacion ==="
input double           InpProximityPips  = 2.0;             // Distancia (pips) para alerta de proximidad
input int              InpUnmitSwings    = 2;               // Swings sin mitigar para resaltar
input int              InpSwingLookback  = 5;               // Barras a izq/der para definir swing
input bool             InpHideMitigated  = true;            // Ocultar FVG ya mitigados

input group "=== Visual ==="
input color            InpBullColor      = clrDodgerBlue;   // Color FVG alcista
input color            InpBearColor      = clrCrimson;      // Color FVG bajista
input color            InpHighlightColor = clrGold;         // Color FVG sin mitigar resaltado
input bool             InpFillZone       = true;            // Rellenar zona
input bool             InpShow50         = true;            // Mostrar linea 50% (CE) del FVG
input color            InpMid50Color     = clrSilver;       // Color linea 50%
input ENUM_LINE_STYLE  InpMid50Style     = STYLE_DOT;       // Estilo linea 50%
input int              InpMid50Width     = 1;               // Grosor linea 50%

input group "=== Boton ON/OFF ==="
input ENUM_BASE_CORNER InpBtnCorner      = CORNER_LEFT_UPPER;
input int              InpBtnX           = 10;
input int              InpBtnY           = 30;
input int              InpBtnW           = 130;
input int              InpBtnH           = 24;
input color            InpBtnOn          = clrSeaGreen;
input color            InpBtnOff         = clrDarkRed;

//==================================================================
//  TIPOS
//==================================================================
enum ENUM_TREND { TREND_NONE = 0, TREND_BULL = 1, TREND_BEAR = -1 };

struct FVG {
   string   name;
   datetime time1;        // tiempo de la barra mas antigua del trio
   datetime time3;        // tiempo de la barra mas reciente del trio
   double   upper;        // borde superior de la zona
   double   lower;        // borde inferior de la zona
   int      direction;    // +1 alcista, -1 bajista
   bool     mitigated;
   bool     highlighted;
   int      swingsPassed;
};

//==================================================================
//  GLOBALES
//==================================================================
string          g_prefix   = "SFVG_";
string          g_btnName;
string          g_lblName;
bool            g_enabled;
int             g_emaFastH = INVALID_HANDLE;
int             g_emaSlowH = INVALID_HANDLE;
ENUM_TIMEFRAMES g_tf;
ENUM_TREND      g_trend     = TREND_NONE;
datetime        g_lastBar   = 0;
FVG             g_fvgs[];

//==================================================================
//  INIT / DEINIT
//==================================================================
int OnInit()
{
   g_btnName = g_prefix + "BTN";
   g_lblName = g_prefix + "TRENDLBL";
   g_enabled = InpEnabled;

   g_tf = InpTimeframe;
   if(InpEnforceMin4H && PeriodSeconds(g_tf) < PeriodSeconds(PERIOD_H4))
      g_tf = PERIOD_H4;

   g_emaFastH = iMA(_Symbol, g_tf, InpEmaFast, 0, MODE_EMA, PRICE_CLOSE);
   g_emaSlowH = iMA(_Symbol, g_tf, InpEmaSlow, 0, MODE_EMA, PRICE_CLOSE);
   if(g_emaFastH == INVALID_HANDLE || g_emaSlowH == INVALID_HANDLE)
   {
      Print("Smart_FVG_MTF: no se pudieron crear los handles EMA");
      return INIT_FAILED;
   }

   ArrayResize(g_fvgs, 0);
   CreateButton();
   IndicatorSetString(INDICATOR_SHORTNAME,
                      "Smart FVG MTF (" + EnumToString(g_tf) + ")");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_emaFastH != INVALID_HANDLE) IndicatorRelease(g_emaFastH);
   if(g_emaSlowH != INVALID_HANDLE) IndicatorRelease(g_emaSlowH);
   ObjectsDeleteAll(0, g_prefix);
   ChartRedraw();
}

//==================================================================
//  ONCALCULATE
//==================================================================
int OnCalculate(const int        rates_total,
                const int        prev_calculated,
                const datetime  &time[],
                const double    &open[],
                const double    &high[],
                const double    &low[],
                const double    &close[],
                const long      &tick_volume[],
                const long      &volume[],
                const int       &spread[])
{
   if(!g_enabled)
      return rates_total;

   int barsTF = Bars(_Symbol, g_tf);
   if(barsTF < InpEmaSlow + 5)
      return rates_total;

   datetime curBar = (datetime)SeriesInfoInteger(_Symbol, g_tf, SERIES_LASTBAR_DATE);

   // Solo re-escaneo cuando hay nueva barra en el TF analizado.
   if(curBar != g_lastBar)
   {
      g_lastBar = curBar;
      ScanFVGs();
   }

   // Actualizaciones continuas (mitigacion / proximidad / etiquetas).
   UpdateMitigations();
   DetermineTrend(0);
   UpdateTrendLabel();

   return rates_total;
}

//==================================================================
//  TENDENCIA
//==================================================================
void DetermineTrend(int shift)
{
   double fast[1], slow[1];
   if(CopyBuffer(g_emaFastH, 0, shift, 1, fast) != 1) return;
   if(CopyBuffer(g_emaSlowH, 0, shift, 1, slow) != 1) return;

   if(fast[0] > slow[0])      g_trend = TREND_BULL;
   else if(fast[0] < slow[0]) g_trend = TREND_BEAR;
   else                       g_trend = TREND_NONE;
}

int TrendAtBar(int shift)
{
   double fast[1], slow[1];
   if(CopyBuffer(g_emaFastH, 0, shift, 1, fast) != 1) return 0;
   if(CopyBuffer(g_emaSlowH, 0, shift, 1, slow) != 1) return 0;
   if(fast[0] > slow[0]) return 1;
   if(fast[0] < slow[0]) return -1;
   return 0;
}

//==================================================================
//  ESCANEO DE FVG (alineados con la tendencia EN EL MOMENTO de formacion)
//==================================================================
void ScanFVGs()
{
   int totalBars = MathMin(InpMaxBarsBack, Bars(_Symbol, g_tf) - 3);
   if(totalBars < 3) return;

   // i = mas antigua del trio; i-1 = central; i-2 = mas reciente.
   for(int i = totalBars; i >= 2; i--)
   {
      double high_i   = iHigh(_Symbol, g_tf, i);
      double low_i    = iLow (_Symbol, g_tf, i);
      double high_im2 = iHigh(_Symbol, g_tf, i - 2);
      double low_im2  = iLow (_Symbol, g_tf, i - 2);

      int trendHere = TrendAtBar(i - 2);
      if(trendHere == 0) continue;

      // FVG alcista: low(reciente) > high(antigua) y tendencia alcista.
      if(trendHere == 1 && low_im2 > high_i)
      {
         AddFVG(iTime(_Symbol, g_tf, i),
                iTime(_Symbol, g_tf, i - 2),
                high_i, low_im2, 1);
      }
      // FVG bajista: high(reciente) < low(antigua) y tendencia bajista.
      else if(trendHere == -1 && high_im2 < low_i)
      {
         AddFVG(iTime(_Symbol, g_tf, i),
                iTime(_Symbol, g_tf, i - 2),
                high_im2, low_i, -1);
      }
   }
}

void AddFVG(datetime t1, datetime t3, double lower, double upper, int dir)
{
   int n = ArraySize(g_fvgs);
   for(int k = 0; k < n; k++)
      if(g_fvgs[k].time1 == t1 && g_fvgs[k].direction == dir)
         return; // ya existe

   ArrayResize(g_fvgs, n + 1);
   g_fvgs[n].time1        = t1;
   g_fvgs[n].time3        = t3;
   g_fvgs[n].lower        = lower;
   g_fvgs[n].upper        = upper;
   g_fvgs[n].direction    = dir;
   g_fvgs[n].mitigated    = false;
   g_fvgs[n].highlighted  = false;
   g_fvgs[n].swingsPassed = 0;
   g_fvgs[n].name = StringFormat("%sZ_%d_%I64d",
                                 g_prefix, dir, (long)t1);
   DrawFVG(g_fvgs[n]);
   TrimOldFVGs();
}

void TrimOldFVGs()
{
   int n = ArraySize(g_fvgs);
   if(n <= InpMaxFVGs) return;
   int toRemove = n - InpMaxFVGs;
   for(int k = 0; k < toRemove; k++)
   {
      ObjectDelete(0, g_fvgs[k].name);
      ObjectDelete(0, g_fvgs[k].name + "_M50");
   }
   for(int k = 0; k < n - toRemove; k++)
      g_fvgs[k] = g_fvgs[k + toRemove];
   ArrayResize(g_fvgs, n - toRemove);
}

//==================================================================
//  MITIGACION / PROXIMIDAD / SWINGS
//==================================================================
void UpdateMitigations()
{
   double pip = PipSize();
   double curPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   for(int k = ArraySize(g_fvgs) - 1; k >= 0; k--)
   {
      int startShift = iBarShift(_Symbol, g_tf, g_fvgs[k].time3, false) - 1;
      if(startShift < 0) startShift = 0;

      bool mitigated = false;
      int  swings    = 0;

      for(int b = startShift; b >= 0; b--)
      {
         double bh = iHigh(_Symbol, g_tf, b);
         double bl = iLow (_Symbol, g_tf, b);

         if(g_fvgs[k].direction == 1)
         {
            if(bl <= g_fvgs[k].upper) { mitigated = true; break; }
         }
         else
         {
            if(bh >= g_fvgs[k].lower) { mitigated = true; break; }
         }
         if(IsSwing(b)) swings++;
      }

      g_fvgs[k].mitigated    = mitigated;
      g_fvgs[k].swingsPassed = swings;

      bool prox   = (!mitigated) && ProximityToPrice(g_fvgs[k], curPrice, pip);
      bool hilite = (!mitigated) && (swings >= InpUnmitSwings || prox);
      g_fvgs[k].highlighted = hilite;

      if(mitigated && InpHideMitigated)
      {
         ObjectDelete(0, g_fvgs[k].name);
         ObjectDelete(0, g_fvgs[k].name + "_M50");
         int n = ArraySize(g_fvgs);
         for(int m = k; m < n - 1; m++) g_fvgs[m] = g_fvgs[m + 1];
         ArrayResize(g_fvgs, n - 1);
      }
      else
      {
         DrawFVG(g_fvgs[k]);
      }
   }
}

bool ProximityToPrice(const FVG &f, double price, double pip)
{
   if(price >= f.lower && price <= f.upper) return true;
   double dist = (price > f.upper) ? (price - f.upper) : (f.lower - price);
   return dist <= InpProximityPips * pip;
}

bool IsSwing(int shift)
{
   int N = InpSwingLookback;
   int barsTF = Bars(_Symbol, g_tf);
   if(shift - N < 0)         return false;
   if(shift + N >= barsTF)   return false;

   double h = iHigh(_Symbol, g_tf, shift);
   double l = iLow (_Symbol, g_tf, shift);
   bool isHigh = true, isLow = true;
   for(int s = 1; s <= N; s++)
   {
      if(iHigh(_Symbol, g_tf, shift + s) >= h) isHigh = false;
      if(iHigh(_Symbol, g_tf, shift - s) >= h) isHigh = false;
      if(iLow (_Symbol, g_tf, shift + s) <= l) isLow  = false;
      if(iLow (_Symbol, g_tf, shift - s) <= l) isLow  = false;
      if(!isHigh && !isLow) return false;
   }
   return (isHigh || isLow);
}

double PipSize()
{
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble (_Symbol, SYMBOL_POINT);
   return ((digits == 3 || digits == 5) ? point * 10.0 : point);
}

//==================================================================
//  DIBUJADO
//==================================================================
void DrawFVG(const FVG &f)
{
   color c = (f.direction == 1) ? InpBullColor : InpBearColor;
   if(f.highlighted) c = InpHighlightColor;

   datetime tEnd = iTime(_Symbol, g_tf, 0)
                 + (datetime)(PeriodSeconds(g_tf) * InpExtendBars);

   if(ObjectFind(0, f.name) < 0)
   {
      ObjectCreate(0, f.name, OBJ_RECTANGLE, 0,
                   f.time1, f.lower, tEnd, f.upper);
   }
   else
   {
      ObjectSetInteger(0, f.name, OBJPROP_TIME,  0, f.time1);
      ObjectSetDouble (0, f.name, OBJPROP_PRICE, 0, f.lower);
      ObjectSetInteger(0, f.name, OBJPROP_TIME,  1, tEnd);
      ObjectSetDouble (0, f.name, OBJPROP_PRICE, 1, f.upper);
   }

   ObjectSetInteger(0, f.name, OBJPROP_COLOR,      c);
   ObjectSetInteger(0, f.name, OBJPROP_FILL,       InpFillZone);
   ObjectSetInteger(0, f.name, OBJPROP_BACK,       !f.highlighted);
   ObjectSetInteger(0, f.name, OBJPROP_WIDTH,      f.highlighted ? 2 : 1);
   ObjectSetInteger(0, f.name, OBJPROP_STYLE,      STYLE_SOLID);
   ObjectSetInteger(0, f.name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, f.name, OBJPROP_HIDDEN,     true);
   ObjectSetString (0, f.name, OBJPROP_TOOLTIP,
      StringFormat("FVG %s\nTF: %s\n[%.5f - %.5f]\n50%%: %.5f\nSwings sin mitigar: %d%s",
                   (f.direction==1 ? "ALCISTA" : "BAJISTA"),
                   EnumToString(g_tf),
                   f.lower, f.upper,
                   (f.lower + f.upper) * 0.5,
                   f.swingsPassed,
                   (f.highlighted ? "\n** SIN MITIGAR / CERCA DEL PRECIO **" : "")));

   // Linea del 50% (Consequent Encroachment)
   string midName = f.name + "_M50";
   if(InpShow50)
   {
      double mid = (f.lower + f.upper) * 0.5;
      if(ObjectFind(0, midName) < 0)
         ObjectCreate(0, midName, OBJ_TREND, 0, f.time1, mid, tEnd, mid);
      else
      {
         ObjectSetInteger(0, midName, OBJPROP_TIME,  0, f.time1);
         ObjectSetDouble (0, midName, OBJPROP_PRICE, 0, mid);
         ObjectSetInteger(0, midName, OBJPROP_TIME,  1, tEnd);
         ObjectSetDouble (0, midName, OBJPROP_PRICE, 1, mid);
      }
      ObjectSetInteger(0, midName, OBJPROP_COLOR,      InpMid50Color);
      ObjectSetInteger(0, midName, OBJPROP_STYLE,      InpMid50Style);
      ObjectSetInteger(0, midName, OBJPROP_WIDTH,      InpMid50Width);
      ObjectSetInteger(0, midName, OBJPROP_RAY_LEFT,   false);
      ObjectSetInteger(0, midName, OBJPROP_RAY_RIGHT,  false);
      ObjectSetInteger(0, midName, OBJPROP_BACK,       false);
      ObjectSetInteger(0, midName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, midName, OBJPROP_HIDDEN,     true);
      ObjectSetString (0, midName, OBJPROP_TOOLTIP,
         StringFormat("FVG 50%% (CE): %.5f", (f.lower + f.upper) * 0.5));
   }
   else
   {
      ObjectDelete(0, midName);
   }
}

//==================================================================
//  BOTON Y EVENTOS
//==================================================================
void CreateButton()
{
   if(ObjectFind(0, g_btnName) < 0)
      ObjectCreate(0, g_btnName, OBJ_BUTTON, 0, 0, 0);

   ObjectSetInteger(0, g_btnName, OBJPROP_CORNER,       InpBtnCorner);
   ObjectSetInteger(0, g_btnName, OBJPROP_XDISTANCE,    InpBtnX);
   ObjectSetInteger(0, g_btnName, OBJPROP_YDISTANCE,    InpBtnY);
   ObjectSetInteger(0, g_btnName, OBJPROP_XSIZE,        InpBtnW);
   ObjectSetInteger(0, g_btnName, OBJPROP_YSIZE,        InpBtnH);
   ObjectSetInteger(0, g_btnName, OBJPROP_COLOR,        clrWhite);
   ObjectSetInteger(0, g_btnName, OBJPROP_BGCOLOR,      g_enabled ? InpBtnOn : InpBtnOff);
   ObjectSetInteger(0, g_btnName, OBJPROP_BORDER_COLOR, clrBlack);
   ObjectSetString (0, g_btnName, OBJPROP_TEXT,         g_enabled ? "FVG: ON" : "FVG: OFF");
   ObjectSetString (0, g_btnName, OBJPROP_FONT,         "Arial Bold");
   ObjectSetInteger(0, g_btnName, OBJPROP_FONTSIZE,     9);
   ObjectSetInteger(0, g_btnName, OBJPROP_SELECTABLE,   false);
   ObjectSetInteger(0, g_btnName, OBJPROP_STATE,        false);
}

void UpdateTrendLabel()
{
   if(!InpShowTrendLabel)
   {
      ObjectDelete(0, g_lblName);
      return;
   }
   if(ObjectFind(0, g_lblName) < 0)
      ObjectCreate(0, g_lblName, OBJ_LABEL, 0, 0, 0);

   string txt;
   color  c;
   switch(g_trend)
   {
      case TREND_BULL: txt = "TENDENCIA: ALCISTA (" + EnumToString(g_tf) + ")"; c = InpBullColor; break;
      case TREND_BEAR: txt = "TENDENCIA: BAJISTA (" + EnumToString(g_tf) + ")"; c = InpBearColor; break;
      default:         txt = "TENDENCIA: --";                                   c = clrGray;      break;
   }

   ObjectSetInteger(0, g_lblName, OBJPROP_CORNER,     InpBtnCorner);
   ObjectSetInteger(0, g_lblName, OBJPROP_XDISTANCE,  InpBtnX);
   ObjectSetInteger(0, g_lblName, OBJPROP_YDISTANCE,  InpBtnY + InpBtnH + 4);
   ObjectSetString (0, g_lblName, OBJPROP_TEXT,       txt);
   ObjectSetInteger(0, g_lblName, OBJPROP_COLOR,      c);
   ObjectSetString (0, g_lblName, OBJPROP_FONT,       "Arial Bold");
   ObjectSetInteger(0, g_lblName, OBJPROP_FONTSIZE,   10);
   ObjectSetInteger(0, g_lblName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, g_lblName, OBJPROP_HIDDEN,     true);
}

void OnChartEvent(const int id, const long &lparam,
                  const double &dparam, const string &sparam)
{
   if(id != CHARTEVENT_OBJECT_CLICK) return;
   if(sparam != g_btnName) return;

   g_enabled = !g_enabled;
   ObjectSetInteger(0, g_btnName, OBJPROP_BGCOLOR,
                    g_enabled ? InpBtnOn : InpBtnOff);
   ObjectSetString (0, g_btnName, OBJPROP_TEXT,
                    g_enabled ? "FVG: ON" : "FVG: OFF");
   ObjectSetInteger(0, g_btnName, OBJPROP_STATE, false);

   if(!g_enabled)
   {
      for(int k = 0; k < ArraySize(g_fvgs); k++)
      {
         ObjectSetInteger(0, g_fvgs[k].name,          OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
         ObjectSetInteger(0, g_fvgs[k].name + "_M50", OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
      }
      ObjectDelete(0, g_lblName);
   }
   else
   {
      for(int k = 0; k < ArraySize(g_fvgs); k++)
      {
         ObjectSetInteger(0, g_fvgs[k].name,          OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
         ObjectSetInteger(0, g_fvgs[k].name + "_M50", OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      }
      g_lastBar = 0; // forzar re-escaneo
   }
   ChartRedraw();
}
//+------------------------------------------------------------------+
