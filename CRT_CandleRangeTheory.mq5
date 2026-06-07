//+------------------------------------------------------------------+
//|                                     CRT_CandleRangeTheory.mq5   |
//|                         Candle Range Theory (CRT) Indicator      |
//|                                                                  |
//|  AMD Framework: Accumulation → Manipulation → Distribution       |
//|                                                                  |
//|  LOGIC:                                                          |
//|  1. ANCHOR candle = defines the range (High / Low)              |
//|  2. MANIPULATION candle = sweeps outside the range (trap)       |
//|     - Bullish: sweeps below anchor Low, closes back above it    |
//|     - Bearish: sweeps above anchor High, closes back below it   |
//|  3. DISTRIBUTION = price delivers to opposite side of range     |
//|                                                                  |
//|  Signals are NON-REPAINTING (only closed candles analyzed)      |
//+------------------------------------------------------------------+
#property copyright   "CRT Indicator - Candle Range Theory"
#property version     "2.10"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   4

//--- Plot 0: Buy signal arrow (bullish CRT confirmed)
#property indicator_label1  "CRT Buy"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLime
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 1: Sell signal arrow (bearish CRT confirmed)
#property indicator_label2  "CRT Sell"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- Plot 2: Bearish manipulation sweep (high sweep = expect drop)
#property indicator_label3  "Manip Sweep High"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrOrangeRed
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

//--- Plot 3: Bullish manipulation sweep (low sweep = expect rise)
#property indicator_label4  "Manip Sweep Low"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrDeepSkyBlue
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1

//==================================================================
//  INPUT PARAMETERS
//==================================================================

input group "=== CRT Core Settings ==="
input ENUM_TIMEFRAMES InpHTF           = PERIOD_H4;  // Anchor Candle Timeframe
input int             InpLookback      = 80;         // Number of HTF bars to scan
input int             InpAtrPeriod     = 14;         // ATR Period
input double          InpMinRangeATR   = 0.25;       // Min range size (× ATR)
input double          InpMaxRangeATR   = 6.0;        // Max range size (× ATR)

input group "=== Signal Filters ==="
input bool   InpRequireClose     = true;   // Manip candle must CLOSE back inside range
input bool   InpShowBuySignal    = true;   // Show Bullish CRT Signals
input bool   InpShowSellSignal   = true;   // Show Bearish CRT Signals
input bool   InpShowManipHigh    = true;   // Show Bearish Sweep Arrow
input bool   InpShowManipLow     = true;   // Show Bullish Sweep Arrow
input bool   InpAlertOnSignal    = false;  // Alert on new signal (current bar only)

input group "=== Anchor Range Box ==="
input bool   InpShowRangeBox     = true;          // Draw Anchor Range Box
input color  InpBullBoxColor     = C'0,80,180';   // Bullish CRT Box Color
input color  InpBearBoxColor     = C'180,40,0';   // Bearish CRT Box Color
input int    InpBoxAlpha         = 30;             // Box Opacity (0=invisible, 255=solid)

input group "=== Manipulation Box ==="
input bool   InpShowManipBox     = true;          // Draw Manipulation Candle Box
input color  InpManipBullColor   = C'0,100,220';  // Manip Box Bull Color
input color  InpManipBearColor   = C'220,60,0';   // Manip Box Bear Color
input int    InpManipAlpha       = 20;            // Manip Box Opacity

input group "=== Key Levels ==="
input bool   InpShow50pctLine    = true;      // Draw 50% Equilibrium Line
input bool   InpShowAnchorHigh   = true;      // Draw Anchor High Level
input bool   InpShowAnchorLow    = true;      // Draw Anchor Low Level
input color  InpLine50Color      = clrGold;   // 50% Line Color
input color  InpHighLineColor    = clrLime;   // Anchor High Line Color
input color  InpLowLineColor     = clrRed;    // Anchor Low Line Color
input int    InpLineWidth        = 1;         // Level Line Width

input group "=== HTF Overlay ==="
input bool   InpShowHTFOverlay   = true;         // Project HTF candles on chart
input color  InpHTFBullColor     = C'0,60,0';    // HTF Bullish Candle Overlay Color
input color  InpHTFBearColor     = C'60,0,0';    // HTF Bearish Candle Overlay Color
input int    InpHTFAlpha         = 15;           // HTF Overlay Opacity

input group "=== Arrow Visual ==="
input int    InpArrowSize        = 2;    // Arrow Size (1–5)
input int    InpArrowShiftPips   = 8;   // Arrow distance from candle (pips)

input group "=== Dashboard ==="
input bool   InpShowDashboard    = true;          // Show info panel
input color  InpDashBgColor      = C'10,10,30';   // Dashboard background color
input color  InpDashTextColor    = clrWhite;      // Dashboard text color
input ENUM_BASE_CORNER InpDashCorner = CORNER_LEFT_UPPER; // Dashboard corner

//==================================================================
//  BUFFERS
//==================================================================
double BuyBuffer[];
double SellBuffer[];
double ManipHighBuffer[];
double ManipLowBuffer[];

//==================================================================
//  GLOBALS
//==================================================================
int    g_atr_handle = INVALID_HANDLE;
string g_prefix;
int    g_last_bull_bar = -1;
int    g_last_bear_bar = -1;
datetime g_last_alert  = 0;

//==================================================================
//  INIT
//==================================================================
int OnInit()
  {
   g_prefix = "CRT_" + Symbol() + IntegerToString(Period()) + "_";

   //--- Buffer/plot setup
   SetIndexBuffer(0, BuyBuffer,       INDICATOR_DATA);
   SetIndexBuffer(1, SellBuffer,      INDICATOR_DATA);
   SetIndexBuffer(2, ManipHighBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, ManipLowBuffer,  INDICATOR_DATA);

   //--- Arrow glyphs (Wingdings)
   PlotIndexSetInteger(0, PLOT_ARROW, 233);  // solid up triangle  ▲
   PlotIndexSetInteger(1, PLOT_ARROW, 234);  // solid down triangle ▼
   PlotIndexSetInteger(2, PLOT_ARROW, 218);  // small up arrow
   PlotIndexSetInteger(3, PLOT_ARROW, 217);  // small down arrow

   //--- Arrow widths
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, MathMax(1, InpArrowSize));
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, MathMax(1, InpArrowSize));
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, MathMax(1, InpArrowSize - 1));
   PlotIndexSetInteger(3, PLOT_LINE_WIDTH, MathMax(1, InpArrowSize - 1));

   //--- Colors
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, clrLime);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, clrRed);
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, clrOrangeRed);
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, clrDeepSkyBlue);

   //--- Empty value sentinel
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   //--- ATR
   g_atr_handle = iATR(Symbol(), Period(), InpAtrPeriod);
   if(g_atr_handle == INVALID_HANDLE)
     {
      Print("CRT: ATR handle failed");
      return INIT_FAILED;
     }

   IndicatorSetString(INDICATOR_SHORTNAME,
                      "CRT [" + EnumToString(InpHTF) + "]");
   return INIT_SUCCEEDED;
  }

//==================================================================
//  DEINIT
//==================================================================
void OnDeinit(const int reason)
  {
   CleanObjects();
   if(g_atr_handle != INVALID_HANDLE)
      IndicatorRelease(g_atr_handle);
  }

//==================================================================
//  HELPERS
//==================================================================

void CleanObjects()
  {
   for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--)
     {
      string n = ObjectName(0, i, 0, -1);
      if(StringFind(n, g_prefix) == 0)
         ObjectDelete(0, n);
     }
  }

//--- Blend color toward black to simulate transparency on chart bg
color BlendColor(color clr, int alpha)
  {
   // alpha 0=transparent(black), 255=opaque
   alpha = MathMax(0, MathMin(255, alpha));
   int r = (int)(((clr >> 16) & 0xFF) * alpha / 255);
   int g = (int)(((clr >> 8)  & 0xFF) * alpha / 255);
   int b = (int)((clr & 0xFF)         * alpha / 255);
   return (color)((r << 16) | (g << 8) | b);
  }

void ObjBox(string name, datetime t1, datetime t2,
            double p_hi, double p_lo, color clr, int alpha)
  {
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
   if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, p_hi, t2, p_lo)) return;
   color fill = BlendColor(clr, alpha);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      fill);
   ObjectSetInteger(0, name, OBJPROP_FILL,       true);
   ObjectSetInteger(0, name, OBJPROP_BACK,       true);
   ObjectSetInteger(0, name, OBJPROP_WIDTH,      1);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
  }

void ObjHLine(string name, datetime t1, datetime t2, double price,
              color clr, int width, ENUM_LINE_STYLE style)
  {
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
   if(!ObjectCreate(0, name, OBJ_TREND, 0, t1, price, t2, price)) return;
   ObjectSetInteger(0, name, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH,      width);
   ObjectSetInteger(0, name, OBJPROP_STYLE,      style);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT,  false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
  }

void ObjText(string name, datetime t, double price, string txt,
             color clr, int fsz = 8)
  {
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
   if(!ObjectCreate(0, name, OBJ_TEXT, 0, t, price)) return;
   ObjectSetString(0,  name, OBJPROP_TEXT,       txt);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,   fsz);
   ObjectSetString(0,  name, OBJPROP_FONT,       "Arial Bold");
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
  }

//==================================================================
//  DASHBOARD LABEL HELPER
//==================================================================
void DashLabel(string name, string txt, color clr, int row)
  {
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0,  name, OBJPROP_TEXT,      txt);
   ObjectSetInteger(0, name, OBJPROP_COLOR,     clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,  9);
   ObjectSetString(0,  name, OBJPROP_FONT,      "Courier New");
   ObjectSetInteger(0, name, OBJPROP_CORNER,    InpDashCorner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 15 + row * 14);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,    false);
  }

void UpdateDashboard(int bull_count, int bear_count, int total_scanned,
                     string last_signal, color sig_color)
  {
   if(!InpShowDashboard) return;

   string p = g_prefix + "DASH_";
   DashLabel(p + "T0", "╔══════════════════════╗",             clrGray,    0);
   DashLabel(p + "T1", "║  CRT  Candle Range Theory   ║",     clrGold,    1);
   DashLabel(p + "T2", "║  HTF: " + StringFormat("%-16s", EnumToString(InpHTF)) + " ║", clrSilver, 2);
   DashLabel(p + "T3", "╠══════════════════════╣",             clrGray,    3);
   DashLabel(p + "T4", "║  Scanned : " + StringFormat("%-4d", total_scanned) + "             ║", clrSilver, 4);
   DashLabel(p + "T5", "║  Bull setups: " + StringFormat("%-3d", bull_count) + "          ║",  clrLime,   5);
   DashLabel(p + "T6", "║  Bear setups: " + StringFormat("%-3d", bear_count) + "          ║",  clrRed,    6);
   DashLabel(p + "T7", "╠══════════════════════╣",             clrGray,    7);
   DashLabel(p + "T8", "║  Last: " + StringFormat("%-15s", last_signal) + "║", sig_color, 8);
   DashLabel(p + "T9", "╚══════════════════════╝",             clrGray,    9);
  }

//==================================================================
//  MAIN CALCULATION
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

   //--- On first run or full recalc: reset everything
   if(prev_calculated == 0)
     {
      ArrayInitialize(BuyBuffer,       EMPTY_VALUE);
      ArrayInitialize(SellBuffer,      EMPTY_VALUE);
      ArrayInitialize(ManipHighBuffer, EMPTY_VALUE);
      ArrayInitialize(ManipLowBuffer,  EMPTY_VALUE);
      CleanObjects();
     }

   //--- ATR array (series order: index 0 = latest)
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(g_atr_handle, 0, 0, rates_total, atr) <= 0) return 0;

   //--- HTF candles
   MqlRates htf[];
   ArraySetAsSeries(htf, true);
   int htf_count = CopyRates(Symbol(), InpHTF, 0, InpLookback + 3, htf);
   if(htf_count < 3) return 0;

   //--- Price arrays as series
   ArraySetAsSeries(time,  true);
   ArraySetAsSeries(open,  true);
   ArraySetAsSeries(high,  true);
   ArraySetAsSeries(low,   true);
   ArraySetAsSeries(close, true);

   double pip = InpArrowShiftPips * _Point;

   int bull_count = 0;
   int bear_count = 0;
   string last_signal = "none";
   color  last_sig_clr = clrSilver;

   //-------------------------------------------------------------------
   // SCAN HTF CANDLES
   // htf[0] = currently forming (skip)
   // htf[1] = most recent complete (can be manipulation candle)
   // htf[h] = anchor candle when h >= 2
   //-------------------------------------------------------------------
   for(int h = 2; h < htf_count - 1; h++)
     {
      //--- Anchor candle (h)
      double a_hi    = htf[h].high;
      double a_lo    = htf[h].low;
      double a_open  = htf[h].open;
      double a_close = htf[h].close;
      double a_range = a_hi - a_lo;
      datetime a_t1  = htf[h].time;
      datetime a_t2  = htf[h - 1].time;

      //--- Manipulation candle (h-1, comes right after anchor)
      double m_hi    = htf[h - 1].high;
      double m_lo    = htf[h - 1].low;
      double m_close = htf[h - 1].close;
      datetime m_t1  = htf[h - 1].time;
      datetime m_t2  = (h >= 2) ? htf[h - 2].time : time[0];

      //--- ATR at anchor bar (approximate from current chart)
      int a_bar = iBarShift(Symbol(), Period(), a_t1, false);
      if(a_bar < 0 || a_bar >= rates_total) continue;
      double cur_atr = atr[MathMin(a_bar, (int)ArraySize(atr) - 1)];
      if(cur_atr <= 0.0) continue;

      //--- Range size filter
      if(a_range < InpMinRangeATR * cur_atr) continue;
      if(a_range > InpMaxRangeATR * cur_atr) continue;

      double mid = a_lo + a_range * 0.5;
      string base = g_prefix + TimeToString(a_t1, TIME_DATE | TIME_MINUTES);

      // Replace colons/spaces for safe object names
      StringReplace(base, ":", "");
      StringReplace(base, " ", "_");

      //--- HTF overlay box (always draw if enabled)
      if(InpShowHTFOverlay)
        {
         color htf_clr = (a_close >= a_open) ? InpHTFBullColor : InpHTFBearColor;
         ObjBox(base + "_htf", a_t1, a_t2, a_hi, a_lo, htf_clr, InpHTFAlpha);
        }

      //================================================================
      // BULLISH CRT: manipulation sweeps BELOW anchor_low
      //              AND closes back ABOVE anchor_low  →  expect UP
      //================================================================
      bool bull_sweep = (m_lo < a_lo);
      bool bull_reentry = InpRequireClose ? (m_close > a_lo) : (m_lo < a_lo);

      if(bull_sweep && bull_reentry)
        {
         bull_count++;
         last_signal = "BULL CRT";
         last_sig_clr = clrLime;

         //--- Anchor range box
         if(InpShowRangeBox)
            ObjBox(base + "_abox", a_t1, a_t2, a_hi, a_lo,
                   InpBullBoxColor, InpBoxAlpha);

         //--- Manipulation box
         if(InpShowManipBox)
            ObjBox(base + "_mbox", m_t1, m_t2, m_hi, m_lo,
                   InpManipBullColor, InpManipAlpha);

         //--- 50% equilibrium line
         if(InpShow50pctLine)
           {
            ObjHLine(base + "_mid", a_t1, m_t2, mid,
                     InpLine50Color, InpLineWidth, STYLE_DASH);
            ObjText(base + "_midL", a_t1, mid + cur_atr * 0.03,
                    " EQ 50%", InpLine50Color, 7);
           }

         //--- Anchor high line (target)
         if(InpShowAnchorHigh)
           {
            ObjHLine(base + "_ahi", a_t1, m_t2, a_hi,
                     InpHighLineColor, InpLineWidth, STYLE_DOT);
            ObjText(base + "_ahiL", a_t1, a_hi + cur_atr * 0.03,
                    " Target H", InpHighLineColor, 7);
           }

         //--- Anchor low line (invalidation)
         if(InpShowAnchorLow)
           {
            ObjHLine(base + "_alo", a_t1, m_t2, a_lo,
                     InpLowLineColor, InpLineWidth, STYLE_DASH);
            ObjText(base + "_aloL", a_t1, a_lo - cur_atr * 0.05,
                    " Anchor Lo", InpLowLineColor, 7);
           }

         //--- Find lowest LTF bar within the manipulation HTF candle
         int m_bar_start = iBarShift(Symbol(), Period(), m_t1, false);
         int m_bar_end   = iBarShift(Symbol(), Period(), m_t2, false);
         if(m_bar_start < 0) m_bar_start = 0;
         if(m_bar_end   < 0) m_bar_end   = 0;
         m_bar_start = MathMin(m_bar_start, rates_total - 1);
         m_bar_end   = MathMax(0, m_bar_end);

         //--- Find the bar with the lowest low (the actual sweep bar)
         int sweep_bar = m_bar_start;
         double sweep_low = low[m_bar_start];
         for(int b = m_bar_end; b <= m_bar_start; b++)
           {
            if(low[b] < sweep_low)
              {
               sweep_low = low[b];
               sweep_bar = b;
              }
           }

         //--- Manipulation sweep arrow (below the sweep bar)
         if(InpShowManipLow && ManipLowBuffer[sweep_bar] == EMPTY_VALUE)
            ManipLowBuffer[sweep_bar] = low[sweep_bar] - pip;

         //--- Buy signal: first bar that closes back above anchor_low
         if(InpShowBuySignal)
           {
            for(int b = sweep_bar; b >= m_bar_end; b--)
              {
               if(close[b] > a_lo && BuyBuffer[b] == EMPTY_VALUE)
                 {
                  BuyBuffer[b] = low[b] - pip * 2.5;
                  break;
                 }
              }
           }
        }

      //================================================================
      // BEARISH CRT: manipulation sweeps ABOVE anchor_high
      //              AND closes back BELOW anchor_high  →  expect DOWN
      //================================================================
      bool bear_sweep   = (m_hi > a_hi);
      bool bear_reentry = InpRequireClose ? (m_close < a_hi) : (m_hi > a_hi);

      if(bear_sweep && bear_reentry)
        {
         bear_count++;
         last_signal = "BEAR CRT";
         last_sig_clr = clrRed;

         //--- Anchor range box
         if(InpShowRangeBox)
            ObjBox(base + "_abox", a_t1, a_t2, a_hi, a_lo,
                   InpBearBoxColor, InpBoxAlpha);

         //--- Manipulation box
         if(InpShowManipBox)
            ObjBox(base + "_mbox", m_t1, m_t2, m_hi, m_lo,
                   InpManipBearColor, InpManipAlpha);

         //--- 50% equilibrium line
         if(InpShow50pctLine)
           {
            ObjHLine(base + "_mid", a_t1, m_t2, mid,
                     InpLine50Color, InpLineWidth, STYLE_DASH);
            ObjText(base + "_midL", a_t1, mid + cur_atr * 0.03,
                    " EQ 50%", InpLine50Color, 7);
           }

         //--- Anchor low line (target)
         if(InpShowAnchorLow)
           {
            ObjHLine(base + "_alo", a_t1, m_t2, a_lo,
                     InpLowLineColor, InpLineWidth, STYLE_DOT);
            ObjText(base + "_aloL", a_t1, a_lo - cur_atr * 0.05,
                    " Target L", InpLowLineColor, 7);
           }

         //--- Anchor high line (invalidation)
         if(InpShowAnchorHigh)
           {
            ObjHLine(base + "_ahi", a_t1, m_t2, a_hi,
                     InpHighLineColor, InpLineWidth, STYLE_DASH);
            ObjText(base + "_ahiL", a_t1, a_hi + cur_atr * 0.03,
                    " Anchor Hi", InpHighLineColor, 7);
           }

         //--- Find highest LTF bar within the manipulation HTF candle
         int m_bar_start = iBarShift(Symbol(), Period(), m_t1, false);
         int m_bar_end   = iBarShift(Symbol(), Period(), m_t2, false);
         if(m_bar_start < 0) m_bar_start = 0;
         if(m_bar_end   < 0) m_bar_end   = 0;
         m_bar_start = MathMin(m_bar_start, rates_total - 1);
         m_bar_end   = MathMax(0, m_bar_end);

         //--- Find the bar with the highest high (the actual sweep bar)
         int sweep_bar = m_bar_start;
         double sweep_high = high[m_bar_start];
         for(int b = m_bar_end; b <= m_bar_start; b++)
           {
            if(high[b] > sweep_high)
              {
               sweep_high = high[b];
               sweep_bar = b;
              }
           }

         //--- Manipulation sweep arrow (above the sweep bar)
         if(InpShowManipHigh && ManipHighBuffer[sweep_bar] == EMPTY_VALUE)
            ManipHighBuffer[sweep_bar] = high[sweep_bar] + pip;

         //--- Sell signal: first bar that closes back below anchor_high
         if(InpShowSellSignal)
           {
            for(int b = sweep_bar; b >= m_bar_end; b--)
              {
               if(close[b] < a_hi && SellBuffer[b] == EMPTY_VALUE)
                 {
                  SellBuffer[b] = high[b] + pip * 2.5;
                  break;
                 }
              }
           }
        }
     }

   //--- Update dashboard
   UpdateDashboard(bull_count, bear_count, htf_count - 2, last_signal, last_sig_clr);

   //--- Alert on current bar signal (non-repainting: only bar 1)
   if(InpAlertOnSignal)
     {
      datetime now = TimeCurrent();
      if(now != g_last_alert)
        {
         if(BuyBuffer[1] != EMPTY_VALUE)
           {
            g_last_alert = now;
            Alert("CRT BUY Signal  |  ", Symbol(), "  ", EnumToString(InpHTF));
            PlaySound("alert.wav");
           }
         else if(SellBuffer[1] != EMPTY_VALUE)
           {
            g_last_alert = now;
            Alert("CRT SELL Signal  |  ", Symbol(), "  ", EnumToString(InpHTF));
            PlaySound("alert.wav");
           }
        }
     }

   ChartRedraw(0);
   return rates_total;
  }
//+------------------------------------------------------------------+
