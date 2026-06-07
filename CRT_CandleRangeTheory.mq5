//+------------------------------------------------------------------+
//|                                     CRT_CandleRangeTheory.mq5   |
//|                         Candle Range Theory (CRT) Indicator      |
//|                                                                  |
//|  AMD Framework: Accumulation → Manipulation → Distribution       |
//|                                                                  |
//|  FLECHAS DE ENTRADA exactas en el nivel de compra/venta         |
//|  Filtro de sesiones: NY, Londres, Asia + Kill Zones             |
//|  Niveles SL y TP automáticos                                    |
//|  Señales NO REPINTAN (solo velas cerradas)                      |
//+------------------------------------------------------------------+
#property copyright   "CRT - Candle Range Theory v3.0"
#property version     "3.00"
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   6

//--- Plot 0: BUY ENTRY arrow  ▲ (large, at entry price)
#property indicator_label1  "CRT BUY ENTRY"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLime
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

//--- Plot 1: SELL ENTRY arrow ▼ (large, at entry price)
#property indicator_label2  "CRT SELL ENTRY"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  3

//--- Plot 2: Manipulation LOW sweep marker
#property indicator_label3  "Manip LOW (Bullish Trap)"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrDeepSkyBlue
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

//--- Plot 3: Manipulation HIGH sweep marker
#property indicator_label4  "Manip HIGH (Bearish Trap)"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrOrangeRed
#property indicator_style4  STYLE_SOLID
#property indicator_width4  2

//--- Plot 4: TP1 marker (50% level)
#property indicator_label5  "CRT TP1 (50%)"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrGold
#property indicator_style5  STYLE_SOLID
#property indicator_width5  1

//--- Plot 5: TP2 marker (full target)
#property indicator_label6  "CRT TP2 (Full target)"
#property indicator_type6   DRAW_ARROW
#property indicator_color6  clrAqua
#property indicator_style6  STYLE_SOLID
#property indicator_width6  1

//==================================================================
//  INPUTS
//==================================================================

input group "=== CRT Core ==="
input ENUM_TIMEFRAMES InpHTF        = PERIOD_H4;  // Anchor HTF Timeframe
input int             InpLookback   = 80;         // HTF bars to scan
input int             InpAtrPeriod  = 14;         // ATR Period
input double          InpMinATR     = 0.25;       // Min range (× ATR)
input double          InpMaxATR     = 6.0;        // Max range (× ATR)
input bool            InpReqClose   = true;       // Require manipulation candle to CLOSE back inside

input group "=== Sesiones / Session Filter ==="
input bool   InpFilterSession  = true;   // Filtrar señales por sesión activa
input int    InpGMTOffset      = 0;      // Offset GMT del servidor broker (ej: 2 para EET)
input bool   InpUseNYSession   = true;   // Nueva York  (08:00–17:00 EST = 13–22 UTC)
input bool   InpUseNYKillZone  = true;   // NY Kill Zone (08:30–11:00 EST = 13:30–16 UTC) ← Mejor
input bool   InpUseLondon      = true;   // Londres (03:00–12:00 EST = 08–17 UTC)
input bool   InpUseLondonKZ    = true;   // London Kill Zone (02:00–05:00 EST = 07–10 UTC) ← Mejor
input bool   InpUseAsian       = false;  // Sesión Asia (18:00–02:00 EST = 23–07 UTC)
input bool   InpHighlightSess  = true;   // Dibujar cajas de sesión en el chart
input color  InpNYColor        = C'0,50,100';     // Color caja NY
input color  InpNYKZColor      = C'0,80,160';     // Color caja NY Kill Zone
input color  InpLondonColor    = C'0,80,0';       // Color caja Londres
input color  InpLondonKZColor  = C'0,130,0';      // Color caja London Kill Zone
input color  InpAsianColor     = C'60,40,0';      // Color caja Asia
input int    InpSessAlpha      = 18;              // Opacidad cajas de sesión

input group "=== Señales / Signals ==="
input bool   InpShowBuy        = true;   // Mostrar señales BUY
input bool   InpShowSell       = true;   // Mostrar señales SELL
input bool   InpShowManip      = true;   // Mostrar marcadores de manipulación
input bool   InpAlerts         = false;  // Alertas en señal nueva
input bool   InpPushNotif      = false;  // Notificación push móvil

input group "=== Niveles SL / TP ==="
input bool   InpShowSL         = true;   // Trazar línea de Stop Loss
input bool   InpShowTP1        = true;   // Trazar TP1 (50% del rango)
input bool   InpShowTP2        = true;   // Trazar TP2 (objetivo completo)
input double InpSLBuffer       = 0.3;   // Buffer SL extra (× ATR)
input color  InpSLColor        = C'180,0,0';    // Color SL
input color  InpTP1Color       = clrGold;       // Color TP1
input color  InpTP2Color       = clrAqua;       // Color TP2

input group "=== Visual: Cajas ==="
input bool   InpShowAnchorBox  = true;          // Caja del Anchor Candle
input bool   InpShowManipBox   = true;          // Caja del candle de manipulación
input color  InpBullColor      = C'0,70,160';   // Color Bullish CRT
input color  InpBearColor      = C'160,40,0';   // Color Bearish CRT
input int    InpBoxAlpha       = 35;            // Opacidad caja (0–255)
input bool   InpShow50Line     = true;          // Línea EQ 50%
input bool   InpShowHTFOverlay = true;          // Overlay HTF en chart
input int    InpHTFAlpha       = 12;            // Opacidad overlay HTF

input group "=== Visual: Flechas ==="
input int    InpArrowSize      = 3;    // Tamaño flecha entrada (1–5)
input int    InpManipSize      = 2;    // Tamaño flecha manipulación
input int    InpArrowPips      = 10;   // Distancia flecha en pips

input group "=== Dashboard ==="
input bool            InpDash      = true;                // Mostrar panel
input ENUM_BASE_CORNER InpDashCorner = CORNER_LEFT_UPPER; // Posición panel

//==================================================================
//  BUFFERS
//==================================================================
double BuyBuf[];
double SellBuf[];
double ManipLowBuf[];
double ManipHighBuf[];
double TP1Buf[];
double TP2Buf[];

//==================================================================
//  GLOBALS
//==================================================================
int      g_atr    = INVALID_HANDLE;
string   g_pfx;
datetime g_last_alert = 0;

//==================================================================
//  SESIÓN: horas en UTC
//==================================================================
struct SessionTime { int h_start; int h_end; };

// NY Full:        13:00–22:00 UTC  (08:00–17:00 EST)
// NY Kill Zone:   13:30–16:00 UTC  (08:30–11:00 EST)
// London Full:    08:00–17:00 UTC  (03:00–12:00 EST)
// London KZ:      07:00–10:00 UTC  (02:00–05:00 EST)
// Asian Full:     23:00–08:00 UTC  (18:00–03:00 EST)  <-- wraps midnight

bool IsInSession(datetime bar_time, int utc_h_start, int utc_h_end)
  {
   // Adjust bar_time by broker GMT offset to get UTC
   datetime utc = bar_time - InpGMTOffset * 3600;
   MqlDateTime mdt;
   TimeToStruct(utc, mdt);
   int h = mdt.hour;
   int m = mdt.min;
   double hf = h + m / 60.0;

   if(utc_h_start < utc_h_end)
      return (hf >= utc_h_start && hf < utc_h_end);
   else  // wraps midnight
      return (hf >= utc_h_start || hf < utc_h_end);
  }

bool IsActiveSession(datetime bar_time)
  {
   if(!InpFilterSession) return true;

   if(InpUseNYKillZone && IsInSession(bar_time, 13,  16))  return true;  // 13:30–16 UTC approx
   if(InpUseNYSession   && IsInSession(bar_time, 13,  22))  return true;
   if(InpUseLondonKZ    && IsInSession(bar_time,  7,  10))  return true;
   if(InpUseLondon      && IsInSession(bar_time,  8,  17))  return true;
   if(InpUseAsian       && IsInSession(bar_time, 23,   8))  return true;

   return false;
  }

//==================================================================
//  INIT
//==================================================================
int OnInit()
  {
   g_pfx = "CRT_" + Symbol() + IntegerToString(Period()) + "_";

   SetIndexBuffer(0, BuyBuf,       INDICATOR_DATA);
   SetIndexBuffer(1, SellBuf,      INDICATOR_DATA);
   SetIndexBuffer(2, ManipLowBuf,  INDICATOR_DATA);
   SetIndexBuffer(3, ManipHighBuf, INDICATOR_DATA);
   SetIndexBuffer(4, TP1Buf,       INDICATOR_DATA);
   SetIndexBuffer(5, TP2Buf,       INDICATOR_DATA);

   //--- Arrow codes (Wingdings font)
   PlotIndexSetInteger(0, PLOT_ARROW, 241);  // Fat UP arrow  ➊ BUY ENTRY
   PlotIndexSetInteger(1, PLOT_ARROW, 242);  // Fat DOWN arrow ➋ SELL ENTRY
   PlotIndexSetInteger(2, PLOT_ARROW, 233);  // Filled triangle up   (manip low)
   PlotIndexSetInteger(3, PLOT_ARROW, 234);  // Filled triangle down (manip high)
   PlotIndexSetInteger(4, PLOT_ARROW, 167);  // Circle  TP1
   PlotIndexSetInteger(5, PLOT_ARROW, 167);  // Circle  TP2

   //--- Sizes
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpArrowSize);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpArrowSize);
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, InpManipSize);
   PlotIndexSetInteger(3, PLOT_LINE_WIDTH, InpManipSize);
   PlotIndexSetInteger(4, PLOT_LINE_WIDTH, 1);
   PlotIndexSetInteger(5, PLOT_LINE_WIDTH, 1);

   //--- Colors
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, clrLime);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, clrRed);
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, clrDeepSkyBlue);
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, clrOrangeRed);
   PlotIndexSetInteger(4, PLOT_LINE_COLOR, clrGold);
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, clrAqua);

   //--- Empty sentinel
   for(int i = 0; i < 6; i++)
      PlotIndexSetDouble(i, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   g_atr = iATR(Symbol(), Period(), InpAtrPeriod);
   if(g_atr == INVALID_HANDLE) { Print("CRT: ATR error"); return INIT_FAILED; }

   IndicatorSetString(INDICATOR_SHORTNAME, "CRT [" + EnumToString(InpHTF) + "]");
   return INIT_SUCCEEDED;
  }

//==================================================================
//  DEINIT
//==================================================================
void OnDeinit(const int reason)
  {
   CleanObjects();
   if(g_atr != INVALID_HANDLE) IndicatorRelease(g_atr);
  }

//==================================================================
//  OBJECT HELPERS
//==================================================================
void CleanObjects()
  {
   for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--)
     {
      string n = ObjectName(0, i, 0, -1);
      if(StringFind(n, g_pfx) == 0) ObjectDelete(0, n);
     }
  }

color Blend(color c, int alpha)  // alpha 0=black, 255=full color
  {
   alpha = MathMax(0, MathMin(255, alpha));
   int r = (int)(((c >> 16) & 0xFF) * alpha / 255);
   int g = (int)(((c >> 8)  & 0xFF) * alpha / 255);
   int b = (int)( (c & 0xFF)        * alpha / 255);
   return (color)((r << 16) | (g << 8) | b);
  }

void Box(string n, datetime t1, datetime t2, double hi, double lo, color c, int a)
  {
   if(ObjectFind(0, n) >= 0) ObjectDelete(0, n);
   if(!ObjectCreate(0, n, OBJ_RECTANGLE, 0, t1, hi, t2, lo)) return;
   ObjectSetInteger(0, n, OBJPROP_COLOR,      Blend(c, a));
   ObjectSetInteger(0, n, OBJPROP_FILL,       true);
   ObjectSetInteger(0, n, OBJPROP_BACK,       true);
   ObjectSetInteger(0, n, OBJPROP_WIDTH,      1);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN,     true);
  }

void HLine(string n, datetime t1, datetime t2, double p, color c, int w, ENUM_LINE_STYLE s)
  {
   if(ObjectFind(0, n) >= 0) ObjectDelete(0, n);
   if(!ObjectCreate(0, n, OBJ_TREND, 0, t1, p, t2, p)) return;
   ObjectSetInteger(0, n, OBJPROP_COLOR,      c);
   ObjectSetInteger(0, n, OBJPROP_WIDTH,      w);
   ObjectSetInteger(0, n, OBJPROP_STYLE,      s);
   ObjectSetInteger(0, n, OBJPROP_RAY_RIGHT,  false);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN,     true);
  }

void Txt(string n, datetime t, double p, string txt, color c, int fsz = 8)
  {
   if(ObjectFind(0, n) >= 0) ObjectDelete(0, n);
   if(!ObjectCreate(0, n, OBJ_TEXT, 0, t, p)) return;
   ObjectSetString(0,  n, OBJPROP_TEXT,       txt);
   ObjectSetInteger(0, n, OBJPROP_COLOR,      c);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE,   fsz);
   ObjectSetString(0,  n, OBJPROP_FONT,       "Arial Bold");
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN,     true);
  }

//--- Draw large entry arrow as a chart object (more visible than buffer arrows)
void EntryArrow(string n, datetime t, double price, bool bull, string label_txt)
  {
   if(ObjectFind(0, n) >= 0) ObjectDelete(0, n);
   if(!ObjectCreate(0, n, OBJ_ARROW, 0, t, price)) return;
   ObjectSetInteger(0, n, OBJPROP_ARROWCODE,  bull ? 241 : 242);  // fat arrow up/down
   ObjectSetInteger(0, n, OBJPROP_COLOR,      bull ? clrLime : clrRed);
   ObjectSetInteger(0, n, OBJPROP_WIDTH,      InpArrowSize + 1);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN,     false);
   // Label next to arrow
   string ln = n + "_L";
   if(ObjectFind(0, ln) >= 0) ObjectDelete(0, ln);
   ObjectCreate(0, ln, OBJ_TEXT, 0, t, price);
   ObjectSetString(0,  ln, OBJPROP_TEXT,    "  " + label_txt);
   ObjectSetInteger(0, ln, OBJPROP_COLOR,   bull ? clrLime : clrRed);
   ObjectSetInteger(0, ln, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0,  ln, OBJPROP_FONT,    "Arial Bold");
   ObjectSetInteger(0, ln, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, ln, OBJPROP_HIDDEN,  false);
  }

//==================================================================
//  SESSION BOXES DRAWN ON CHART
//==================================================================
void DrawSessionBoxes(const datetime &time[], int rates_total)
  {
   if(!InpHighlightSess) return;

   // We draw one box per day per session, covering visible bars
   // Find unique dates in the time array
   datetime processed_days[];
   int day_count = 0;

   for(int i = rates_total - 1; i >= 0; i--)
     {
      MqlDateTime mdt;
      datetime utc = time[i] - InpGMTOffset * 3600;
      TimeToStruct(utc, mdt);

      // Build a date key (start of day)
      datetime day_start = (datetime)(utc - mdt.hour * 3600 - mdt.min * 60 - mdt.sec);
      datetime day_broker = day_start + InpGMTOffset * 3600; // back to broker time

      // Check if already processed
      bool found = false;
      for(int d = 0; d < day_count; d++)
         if(processed_days[d] == day_broker) { found = true; break; }
      if(found) continue;

      // Add to processed list
      ArrayResize(processed_days, day_count + 1);
      processed_days[day_count++] = day_broker;

      //--- Draw session boxes for this day
      // NY Full: 13–22 UTC
      if(InpUseNYSession)
        {
         datetime s = day_broker + (13 - InpGMTOffset) * 3600;
         datetime e = day_broker + (22 - InpGMTOffset) * 3600;
         string sn = g_pfx + "SES_NY_" + IntegerToString((int)day_broker);
         Box(sn, s, e, 99999, 0, InpNYColor, InpSessAlpha);
         Txt(sn + "_L", s, 0, "NY", InpNYColor, 7);
        }
      // NY Kill Zone: 13:30–16 UTC
      if(InpUseNYKillZone)
        {
         datetime s = day_broker + (13 - InpGMTOffset) * 3600 + 1800;
         datetime e = day_broker + (16 - InpGMTOffset) * 3600;
         string sn = g_pfx + "SES_NYKZ_" + IntegerToString((int)day_broker);
         Box(sn, s, e, 99999, 0, InpNYKZColor, InpSessAlpha + 10);
         Txt(sn + "_L", s, 0, "NY KZ", InpNYKZColor, 7);
        }
      // London Full: 08–17 UTC
      if(InpUseLondon)
        {
         datetime s = day_broker + (8 - InpGMTOffset) * 3600;
         datetime e = day_broker + (17 - InpGMTOffset) * 3600;
         string sn = g_pfx + "SES_LON_" + IntegerToString((int)day_broker);
         Box(sn, s, e, 99999, 0, InpLondonColor, InpSessAlpha);
         Txt(sn + "_L", s, 0, "LON", InpLondonColor, 7);
        }
      // London Kill Zone: 07–10 UTC
      if(InpUseLondonKZ)
        {
         datetime s = day_broker + (7 - InpGMTOffset) * 3600;
         datetime e = day_broker + (10 - InpGMTOffset) * 3600;
         string sn = g_pfx + "SES_LONKZ_" + IntegerToString((int)day_broker);
         Box(sn, s, e, 99999, 0, InpLondonKZColor, InpSessAlpha + 10);
         Txt(sn + "_L", s, 0, "LON KZ", InpLondonKZColor, 7);
        }
      // Asian: 23–08 UTC (wraps midnight → split in two)
      if(InpUseAsian)
        {
         datetime s1 = day_broker + (23 - InpGMTOffset) * 3600;
         datetime e1 = day_broker + (32 - InpGMTOffset) * 3600; // 08 next day = 23+9
         string sn = g_pfx + "SES_ASIA_" + IntegerToString((int)day_broker);
         Box(sn, s1, e1, 99999, 0, InpAsianColor, InpSessAlpha);
         Txt(sn + "_L", s1, 0, "ASIA", InpAsianColor, 7);
        }
     }
  }

//==================================================================
//  DASHBOARD
//==================================================================
void Dash(string n, string txt, color c, int row, int col = 0)
  {
   if(ObjectFind(0, n) >= 0) ObjectDelete(0, n);
   ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0,  n, OBJPROP_TEXT,       txt);
   ObjectSetInteger(0, n, OBJPROP_COLOR,      c);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE,   9);
   ObjectSetString(0,  n, OBJPROP_FONT,       "Courier New");
   ObjectSetInteger(0, n, OBJPROP_CORNER,     InpDashCorner);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE,  10 + col * 160);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE,  15 + row * 14);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN,     false);
  }

void UpdateDash(int bull, int bear, int total, string last_sig, color lc,
                string active_sess)
  {
   if(!InpDash) return;
   string p = g_pfx + "D_";
   Dash(p+"r0", "╔═══════════════════════════╗",  clrGray,   0);
   Dash(p+"r1", "║   CRT  Candle Range Theory   ║", clrGold,   1);
   Dash(p+"r2", "║  HTF : "+StringFormat("%-21s",EnumToString(InpHTF))+"║", clrSilver, 2);
   Dash(p+"r3", "╠═══════════════════════════╣",  clrGray,   3);
   Dash(p+"r4", "║  Barras HTF : "+StringFormat("%-14d",total)+"║",  clrSilver, 4);
   Dash(p+"r5", "║  Setups BULL: "+StringFormat("%-14d",bull)+ "║",  clrLime,   5);
   Dash(p+"r6", "║  Setups BEAR: "+StringFormat("%-14d",bear)+ "║",  clrRed,    6);
   Dash(p+"r7", "╠═══════════════════════════╣",  clrGray,   7);
   Dash(p+"r8", "║  Sesión activa: "+StringFormat("%-12s",active_sess)+"║", clrAqua,   8);
   Dash(p+"r9", "║  Última señal : "+StringFormat("%-12s",last_sig)+"║",  lc,        9);
   Dash(p+"r10","╚═══════════════════════════╝", clrGray,   10);
  }

//==================================================================
//  MAIN CALCULATE
//==================================================================
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
   if(rates_total < InpAtrPeriod + 3) return 0;

   if(prev_calculated == 0)
     {
      ArrayInitialize(BuyBuf,       EMPTY_VALUE);
      ArrayInitialize(SellBuf,      EMPTY_VALUE);
      ArrayInitialize(ManipLowBuf,  EMPTY_VALUE);
      ArrayInitialize(ManipHighBuf, EMPTY_VALUE);
      ArrayInitialize(TP1Buf,       EMPTY_VALUE);
      ArrayInitialize(TP2Buf,       EMPTY_VALUE);
      CleanObjects();
     }

   //--- ATR (series)
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(g_atr, 0, 0, rates_total, atr) <= 0) return 0;

   //--- HTF rates (series)
   MqlRates htf[];
   ArraySetAsSeries(htf, true);
   int htf_cnt = CopyRates(Symbol(), InpHTF, 0, InpLookback + 3, htf);
   if(htf_cnt < 3) return 0;

   //--- LTF arrays as series
   ArraySetAsSeries(time,  true);
   ArraySetAsSeries(open,  true);
   ArraySetAsSeries(high,  true);
   ArraySetAsSeries(low,   true);
   ArraySetAsSeries(close, true);

   double pip = InpArrowPips * _Point;

   int bull_cnt = 0, bear_cnt = 0;
   string last_sig = "ninguna";
   color  last_clr = clrSilver;

   //--- Draw session background boxes
   DrawSessionBoxes(time, rates_total);

   //--- Determine current session name for dashboard
   string cur_sess = "Fuera sesión";
   datetime now = TimeCurrent();
   if(IsInSession(now, 13, 16)) cur_sess = "NY Kill Zone";
   else if(IsInSession(now, 13, 22)) cur_sess = "Nueva York";
   else if(IsInSession(now, 7, 10)) cur_sess = "London KZ";
   else if(IsInSession(now, 8, 17)) cur_sess = "Londres";
   else if(IsInSession(now, 23, 8)) cur_sess = "Asia";

   //=================================================================
   // SCAN HTF CANDLES
   // htf[0] = forming candle (skip)
   // htf[h]   = anchor candle  (h >= 2)
   // htf[h-1] = manipulation candle
   //=================================================================
   for(int h = 2; h < htf_cnt - 1; h++)
     {
      //--- Anchor
      double a_hi  = htf[h].high,  a_lo  = htf[h].low;
      double a_op  = htf[h].open,  a_cl  = htf[h].close;
      double rng   = a_hi - a_lo;
      datetime a_t1 = htf[h].time, a_t2 = htf[h-1].time;

      //--- Manipulation
      double m_hi  = htf[h-1].high, m_lo  = htf[h-1].low;
      double m_cl  = htf[h-1].close;
      datetime m_t1 = htf[h-1].time;
      datetime m_t2 = (h >= 2) ? htf[h-2].time : time[0];

      //--- ATR at anchor bar
      int a_bar = iBarShift(Symbol(), Period(), a_t1, false);
      if(a_bar < 0 || a_bar >= rates_total) continue;
      double cur_atr = atr[MathMin(a_bar, (int)ArraySize(atr)-1)];
      if(cur_atr <= 0.0) continue;

      //--- Range filter
      if(rng < InpMinATR * cur_atr) continue;
      if(rng > InpMaxATR * cur_atr) continue;

      double mid    = a_lo + rng * 0.50;
      double sl_buf = InpSLBuffer * cur_atr;

      //--- Safe name prefix for objects of this setup
      string b = g_pfx + TimeToString(a_t1, TIME_DATE|TIME_MINUTES);
      StringReplace(b, ":", ""); StringReplace(b, " ", "_");

      //--- HTF Overlay
      if(InpShowHTFOverlay)
        {
         color oc = (a_cl >= a_op) ? C'0,55,0' : C'55,0,0';
         Box(b+"_htf", a_t1, a_t2, a_hi, a_lo, oc, InpHTFAlpha);
        }

      //================================================================
      // BULLISH CRT  ↑
      // Manipulation barre POR DEBAJO del anchor_low
      // y cierra de vuelta ARRIBA del anchor_low
      // → Señal de COMPRA, objetivo = anchor_high
      //================================================================
      bool b_sweep  = (m_lo < a_lo);
      bool b_reent  = InpReqClose ? (m_cl > a_lo) : b_sweep;

      if(b_sweep && b_reent)
        {
         // ─── Buscar barra LTF del sweep ───
         int mb_s = MathMin(iBarShift(Symbol(), Period(), m_t1, false), rates_total-1);
         int mb_e = MathMax(iBarShift(Symbol(), Period(), m_t2, false), 0);

         // Barra con el low más bajo (el sweep real)
         int sw_bar = mb_s;
         double sw_lo = low[mb_s];
         for(int b2 = mb_e; b2 <= mb_s; b2++)
            if(low[b2] < sw_lo) { sw_lo = low[b2]; sw_bar = b2; }

         // Primera barra que cierra de vuelta sobre anchor_low → SEÑAL BUY
         int sig_bar = -1;
         for(int b2 = sw_bar; b2 >= mb_e; b2--)
            if(close[b2] > a_lo) { sig_bar = b2; break; }
         if(sig_bar < 0) sig_bar = mb_e;

         // ── Filtro de sesión aplicado al bar de señal ──
         bool in_sess = IsActiveSession(time[sig_bar]);

         bull_cnt++;
         last_sig = "BUY CRT";
         last_clr = clrLime;

         //--- Dibujar setup visual (siempre, independiente de sesión)
         if(InpShowAnchorBox)
            Box(b+"_ab", a_t1, a_t2, a_hi, a_lo, InpBullColor, InpBoxAlpha);
         if(InpShowManipBox)
            Box(b+"_mb", m_t1, m_t2, m_hi, m_lo, InpBullColor, InpBoxAlpha - 12);
         if(InpShow50Line)
           {
            HLine(b+"_mid", a_t1, m_t2, mid, clrGold, 1, STYLE_DASH);
            Txt(b+"_midL", a_t1, mid+cur_atr*0.03, " EQ 50%", clrGold, 7);
           }
         // Línea de entrada (anchor_low)
         HLine(b+"_entry", m_t1, m_t2, a_lo, clrLime, 2, STYLE_SOLID);
         Txt(b+"_entL",   m_t1, a_lo + cur_atr*0.02,
             " ENTRY: "+DoubleToString(a_lo, _Digits), clrLime, 8);

         // Stop Loss debajo del sweep low
         if(InpShowSL)
           {
            double sl_p = sw_lo - sl_buf;
            HLine(b+"_sl", m_t1, m_t2, sl_p, InpSLColor, 1, STYLE_DOT);
            Txt(b+"_slL", m_t1, sl_p - cur_atr*0.04,
                " SL: "+DoubleToString(sl_p, _Digits), InpSLColor, 7);
           }
         // TP1 = 50%
         if(InpShowTP1)
           {
            HLine(b+"_tp1", m_t1, m_t2, mid, InpTP1Color, 1, STYLE_DASH);
            Txt(b+"_tp1L", m_t1, mid + cur_atr*0.03,
                " TP1: "+DoubleToString(mid, _Digits), InpTP1Color, 7);
           }
         // TP2 = anchor high
         if(InpShowTP2)
           {
            HLine(b+"_tp2", m_t1, m_t2, a_hi, InpTP2Color, 2, STYLE_DOT);
            Txt(b+"_tp2L", m_t1, a_hi + cur_atr*0.03,
                " TP2: "+DoubleToString(a_hi, _Digits), InpTP2Color, 8);
           }

         //--- Marcador sweep (siempre visible)
         if(InpShowManip && ManipLowBuf[sw_bar] == EMPTY_VALUE)
            ManipLowBuf[sw_bar] = low[sw_bar] - pip;

         //--- Flecha de entrada principal (solo en sesión activa o si filtro desactivado)
         if(in_sess || !InpFilterSession)
           {
            // Buffer arrow (legend)
            if(InpShowBuy && BuyBuf[sig_bar] == EMPTY_VALUE)
               BuyBuf[sig_bar] = a_lo - pip * 2;   // flecha en nivel de ENTRADA

            // Objeto flecha grande en el nivel de anchor_low
            if(InpShowBuy)
               EntryArrow(b+"_buy", time[sig_bar], a_lo - pip,
                          true, "BUY  @ "+DoubleToString(a_lo, _Digits));

            // TP1 buffer marker
            if(InpShowTP1 && TP1Buf[sig_bar] == EMPTY_VALUE)
               TP1Buf[sig_bar] = mid;
            // TP2 buffer marker
            if(InpShowTP2 && TP2Buf[sig_bar] == EMPTY_VALUE)
               TP2Buf[sig_bar] = a_hi;

            //--- Alertas
            if(InpAlerts && sig_bar <= 1 && TimeCurrent() != g_last_alert)
              {
               g_last_alert = TimeCurrent();
               string msg = "CRT BUY  " + Symbol() + " [" +
                            EnumToString(InpHTF) + "]  Entry:" +
                            DoubleToString(a_lo,_Digits) +
                            "  TP:" + DoubleToString(a_hi,_Digits) +
                            "  SL:" + DoubleToString(sw_lo - sl_buf,_Digits);
               Alert(msg);
               if(InpPushNotif) SendNotification(msg);
               PlaySound("alert.wav");
              }
           }
        }

      //================================================================
      // BEARISH CRT  ↓
      // Manipulation barre POR ENCIMA del anchor_high
      // y cierra de vuelta ABAJO del anchor_high
      // → Señal de VENTA, objetivo = anchor_low
      //================================================================
      bool s_sweep = (m_hi > a_hi);
      bool s_reent = InpReqClose ? (m_cl < a_hi) : s_sweep;

      if(s_sweep && s_reent)
        {
         int mb_s = MathMin(iBarShift(Symbol(), Period(), m_t1, false), rates_total-1);
         int mb_e = MathMax(iBarShift(Symbol(), Period(), m_t2, false), 0);

         int sw_bar = mb_s;
         double sw_hi = high[mb_s];
         for(int b2 = mb_e; b2 <= mb_s; b2++)
            if(high[b2] > sw_hi) { sw_hi = high[b2]; sw_bar = b2; }

         int sig_bar = -1;
         for(int b2 = sw_bar; b2 >= mb_e; b2--)
            if(close[b2] < a_hi) { sig_bar = b2; break; }
         if(sig_bar < 0) sig_bar = mb_e;

         bool in_sess = IsActiveSession(time[sig_bar]);

         bear_cnt++;
         last_sig = "SELL CRT";
         last_clr = clrRed;

         //--- Dibujar setup visual
         if(InpShowAnchorBox)
            Box(b+"_ab", a_t1, a_t2, a_hi, a_lo, InpBearColor, InpBoxAlpha);
         if(InpShowManipBox)
            Box(b+"_mb", m_t1, m_t2, m_hi, m_lo, InpBearColor, InpBoxAlpha - 12);
         if(InpShow50Line)
           {
            HLine(b+"_mid", a_t1, m_t2, mid, clrGold, 1, STYLE_DASH);
            Txt(b+"_midL", a_t1, mid+cur_atr*0.03, " EQ 50%", clrGold, 7);
           }
         // Línea de entrada (anchor_high)
         HLine(b+"_entry", m_t1, m_t2, a_hi, clrRed, 2, STYLE_SOLID);
         Txt(b+"_entL",   m_t1, a_hi + cur_atr*0.03,
             " ENTRY: "+DoubleToString(a_hi, _Digits), clrRed, 8);

         // Stop Loss encima del sweep high
         if(InpShowSL)
           {
            double sl_p = sw_hi + sl_buf;
            HLine(b+"_sl", m_t1, m_t2, sl_p, InpSLColor, 1, STYLE_DOT);
            Txt(b+"_slL", m_t1, sl_p + cur_atr*0.03,
                " SL: "+DoubleToString(sl_p, _Digits), InpSLColor, 7);
           }
         // TP1 = 50%
         if(InpShowTP1)
           {
            HLine(b+"_tp1", m_t1, m_t2, mid, InpTP1Color, 1, STYLE_DASH);
            Txt(b+"_tp1L", m_t1, mid - cur_atr*0.05,
                " TP1: "+DoubleToString(mid, _Digits), InpTP1Color, 7);
           }
         // TP2 = anchor low
         if(InpShowTP2)
           {
            HLine(b+"_tp2", m_t1, m_t2, a_lo, InpTP2Color, 2, STYLE_DOT);
            Txt(b+"_tp2L", m_t1, a_lo - cur_atr*0.05,
                " TP2: "+DoubleToString(a_lo, _Digits), InpTP2Color, 8);
           }

         if(InpShowManip && ManipHighBuf[sw_bar] == EMPTY_VALUE)
            ManipHighBuf[sw_bar] = high[sw_bar] + pip;

         if(in_sess || !InpFilterSession)
           {
            if(InpShowSell && SellBuf[sig_bar] == EMPTY_VALUE)
               SellBuf[sig_bar] = a_hi + pip * 2;  // flecha en nivel de ENTRADA

            if(InpShowSell)
               EntryArrow(b+"_sell", time[sig_bar], a_hi + pip,
                          false, "SELL @ "+DoubleToString(a_hi, _Digits));

            if(InpShowTP1 && TP1Buf[sig_bar] == EMPTY_VALUE)
               TP1Buf[sig_bar] = mid;
            if(InpShowTP2 && TP2Buf[sig_bar] == EMPTY_VALUE)
               TP2Buf[sig_bar] = a_lo;

            if(InpAlerts && sig_bar <= 1 && TimeCurrent() != g_last_alert)
              {
               g_last_alert = TimeCurrent();
               string msg = "CRT SELL " + Symbol() + " [" +
                            EnumToString(InpHTF) + "]  Entry:" +
                            DoubleToString(a_hi,_Digits) +
                            "  TP:" + DoubleToString(a_lo,_Digits) +
                            "  SL:" + DoubleToString(sw_hi + sl_buf,_Digits);
               Alert(msg);
               if(InpPushNotif) SendNotification(msg);
               PlaySound("alert.wav");
              }
           }
        }
     }

   UpdateDash(bull_cnt, bear_cnt, htf_cnt - 2, last_sig, last_clr, cur_sess);
   ChartRedraw(0);
   return rates_total;
  }
//+------------------------------------------------------------------+
