//+------------------------------------------------------------------+
//|                                     CRT_CandleRangeTheory.mq5   |
//|                         Candle Range Theory (CRT) Indicator      |
//|                                                                  |
//|  AMD: Accumulation → Manipulation → Distribution                 |
//|                                                                  |
//|  v6.0 – Añadido:                                                |
//|    • Score de Confluencia 0-100 (filtra setups débiles)         |
//|    • MSS/BOS en LTF (confirmación de distribución)              |
//|    • FVG dentro del rango CRT (zona de re-entrada)              |
//|    • Zona R:R visual (riesgo en rojo, ganancia en verde)        |
//|    • Color de flecha según score (verde/amarillo/naranja)       |
//|    • Señales NO REPINTAN (solo velas cerradas)                  |
//+------------------------------------------------------------------+
#property copyright   "CRT - Candle Range Theory v6.0"
#property version     "6.00"
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   6

#property indicator_label1  "CRT BUY  (score≥min)"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLime
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

#property indicator_label2  "CRT SELL (score≥min)"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  3

#property indicator_label3  "Manip Sweep LOW"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrDeepSkyBlue
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

#property indicator_label4  "Manip Sweep HIGH"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrOrangeRed
#property indicator_style4  STYLE_SOLID
#property indicator_width4  2

#property indicator_label5  "MSS Confirmation"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrMagenta
#property indicator_style5  STYLE_SOLID
#property indicator_width5  2

#property indicator_label6  "FVG Midpoint"
#property indicator_type6   DRAW_ARROW
#property indicator_color6  clrYellow
#property indicator_style6  STYLE_SOLID
#property indicator_width6  1

//==================================================================
//  INPUTS
//==================================================================

input group "=== CRT Core ==="
input ENUM_TIMEFRAMES InpHTF        = PERIOD_H4; // Anchor HTF Timeframe
input int             InpLookback   = 80;        // HTF bars to scan
input int             InpAtrPeriod  = 14;        // ATR Period
input double          InpMinATR     = 0.25;      // Min range (× ATR)
input double          InpMaxATR     = 6.0;       // Max range (× ATR)
input bool            InpReqClose   = true;      // Manip candle must CLOSE back inside

input group "=== Score de Confluencia ==="
input int    InpMinScore      = 40;    // Score mínimo para mostrar señal (0=todo, 80=solo los mejores)
input bool   InpShowScore     = true;  // Mostrar score en el chart
input bool   InpUseMSS        = true;  // Detectar MSS/BOS en LTF (+15 pts)
input bool   InpUseFVG        = true;  // Detectar FVG dentro del rango (+15 pts)
input bool   InpUseD1Bias     = true;  // Verificar bias en D1 (+15 pts)
input bool   InpShowRRZone    = true;  // Zona visual riesgo/beneficio
input bool   InpShowFVGBox    = true;  // Dibujar caja del FVG
input color  InpFVGBullColor  = C'0,60,100';  // FVG Bullish color
input color  InpFVGBearColor  = C'100,30,0';  // FVG Bearish color
input int    InpFVGAlpha      = 50;            // FVG box opacidad
input color  InpRRRiskColor   = C'100,0,0';   // Zona riesgo (SL) color
input color  InpRRProfColor   = C'0,80,0';    // Zona ganancia (TP) color
input int    InpRRAlpha       = 25;           // R:R zone opacidad

input group "=== Sesiones / Session Filter ==="
input bool   InpFilterSession  = true;
input int    InpGMTOffset      = 0;      // GMT offset del broker (ej: 2 para EET)
input bool   InpUseNYKillZone  = true;   // NY Kill Zone 13:30–16 UTC (+20 pts)
input bool   InpUseNYSession   = true;   // Nueva York 13–22 UTC (+10 pts)
input bool   InpUseLondonKZ    = true;   // London Kill Zone 07–10 UTC (+20 pts)
input bool   InpUseLondon      = true;   // Londres 08–17 UTC (+10 pts)
input bool   InpUseAsian       = false;  // Asia 23–08 UTC
input bool   InpHighlightSess  = true;
input color  InpNYColor        = C'0,50,100';
input color  InpNYKZColor      = C'0,80,160';
input color  InpLondonColor    = C'0,80,0';
input color  InpLondonKZColor  = C'0,130,0';
input color  InpAsianColor     = C'60,40,0';
input int    InpSessAlpha      = 18;

input group "=== Señales ==="
input bool   InpShowBuy        = true;
input bool   InpShowSell       = true;
input bool   InpShowManip      = true;
input bool   InpAlerts         = false;
input bool   InpPushNotif      = false;

input group "=== SL / TP ==="
input bool   InpShowSL         = true;
input bool   InpShowTP1        = true;
input bool   InpShowTP2        = true;
input double InpSLBuffer       = 0.3;
input color  InpSLColor        = C'180,0,0';
input color  InpTP1Color       = clrGold;
input color  InpTP2Color       = clrAqua;

input group "=== Visual: Cajas ==="
input bool   InpShowAnchorBox  = true;
input bool   InpShowManipBox   = true;
input color  InpBullColor      = C'0,70,160';
input color  InpBearColor      = C'160,40,0';
input int    InpBoxAlpha       = 35;
input bool   InpShow50Line     = true;
input bool   InpShowHTFOverlay = true;
input int    InpHTFAlpha       = 12;

input group "=== Visual: Flechas ==="
input int    InpArrowSize      = 3;
input int    InpManipSize      = 2;
input int    InpArrowPips      = 10;

input group "=== Números Redondos ==="
input bool   InpShowRound      = true;
input double InpBigFigure      = 0.0;    // 0 = auto-detectar
input bool   InpShowQuarters   = true;
input bool   InpShowHalf       = true;
input int    InpRoundLevels    = 10;
input color  InpRound00Color   = C'200,200,0';
input color  InpRound50Color   = C'140,140,0';
input color  InpRoundQtrColor  = C'80,80,0';
input int    InpRound00Width   = 2;
input int    InpRound50Width   = 1;
input int    InpRoundQtrWidth  = 1;
input bool   InpRoundFilter    = false;
input double InpRoundZonePct   = 0.15;

input group "=== Niveles Clave ==="
input bool   InpShowPDHL       = true;
input bool   InpShowPWHL       = true;
input bool   InpShowPMHL       = false;
input color  InpPDHColor       = C'0,180,255';
input color  InpPDLColor       = C'255,80,0';
input color  InpPWHColor       = C'0,120,200';
input color  InpPWLColor       = C'200,60,0';
input color  InpPMHColor       = C'0,80,160';
input color  InpPMLColor       = C'160,40,0';
input int    InpKeyLevelWidth  = 2;
input bool   InpKeyLevelLabel  = true;

input group "=== Dashboard ==="
input bool             InpDash       = true;
input ENUM_BASE_CORNER InpDashCorner = CORNER_LEFT_UPPER;

//==================================================================
//  BUFFERS
//==================================================================
double BuyBuf[];
double SellBuf[];
double ManipLowBuf[];
double ManipHighBuf[];
double MSSBuf[];
double FVGBuf[];

//==================================================================
//  GLOBALS
//==================================================================
int    g_atr = INVALID_HANDLE;
string g_pfx;
datetime g_last_alert = 0;

MqlRates g_htf[];
datetime g_last_htf_t = 0;
int      g_htf_cnt    = 0;

datetime g_last_sess_day = 0;
datetime g_last_kl_day   = 0;
datetime g_last_kl_week  = 0;

double g_pdh = 0, g_pdl = 0;
double g_pwh = 0, g_pwl = 0;
double g_pmh = 0, g_pml = 0;
double g_big_figure = 0;

int    g_last_score  = 0;
string g_last_sig    = "ninguna";
color  g_last_clr    = clrSilver;

//==================================================================
//  INIT
//==================================================================
int OnInit()
  {
   g_pfx = "CRT_" + Symbol() + IntegerToString(Period()) + "_";
   ArraySetAsSeries(g_htf, true);

   SetIndexBuffer(0, BuyBuf,      INDICATOR_DATA);
   SetIndexBuffer(1, SellBuf,     INDICATOR_DATA);
   SetIndexBuffer(2, ManipLowBuf, INDICATOR_DATA);
   SetIndexBuffer(3, ManipHighBuf,INDICATOR_DATA);
   SetIndexBuffer(4, MSSBuf,      INDICATOR_DATA);
   SetIndexBuffer(5, FVGBuf,      INDICATOR_DATA);

   PlotIndexSetInteger(0, PLOT_ARROW, 241);  // fat up
   PlotIndexSetInteger(1, PLOT_ARROW, 242);  // fat down
   PlotIndexSetInteger(2, PLOT_ARROW, 233);  // tri up   (manip low)
   PlotIndexSetInteger(3, PLOT_ARROW, 234);  // tri down (manip high)
   PlotIndexSetInteger(4, PLOT_ARROW, 119);  // diamond  (MSS)
   PlotIndexSetInteger(5, PLOT_ARROW, 167);  // circle   (FVG)

   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpArrowSize);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpArrowSize);
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, InpManipSize);
   PlotIndexSetInteger(3, PLOT_LINE_WIDTH, InpManipSize);
   PlotIndexSetInteger(4, PLOT_LINE_WIDTH, 2);
   PlotIndexSetInteger(5, PLOT_LINE_WIDTH, 1);

   for(int i = 0; i < 6; i++)
      PlotIndexSetDouble(i, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   g_atr = iATR(Symbol(), Period(), InpAtrPeriod);
   if(g_atr == INVALID_HANDLE) { Print("CRT: ATR error"); return INIT_FAILED; }

   g_big_figure = (InpBigFigure > 0.0) ? InpBigFigure : AutoBigFigure();

   IndicatorSetString(INDICATOR_SHORTNAME,
                      "CRT [" + EnumToString(InpHTF) + "] min=" + IntegerToString(InpMinScore));
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
//  AUTO BIG FIGURE
//==================================================================
double AutoBigFigure()
  {
   double price  = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   int    digits = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
   if(digits >= 4) return 0.01;
   if(digits == 3) return 1.0;
   if(digits == 2)
     {
      if(price < 200)  return 1.0;
      if(price < 3000) return 50.0;
      return 500.0;
     }
   if(digits <= 1)
     {
      if(price < 5000) return 100.0;
      return 1000.0;
     }
   return 0.01;
  }

//==================================================================
//  SESSION HELPERS
//==================================================================
bool IsInSession(datetime t, int h_start, int h_end)
  {
   datetime utc = t - InpGMTOffset * 3600;
   MqlDateTime m; TimeToStruct(utc, m);
   double hf = m.hour + m.min / 60.0;
   if(h_start < h_end) return (hf >= h_start && hf < h_end);
   return (hf >= h_start || hf < h_end);
  }

bool IsActiveSession(datetime t)
  {
   if(!InpFilterSession) return true;
   if(InpUseNYKillZone && IsInSession(t, 13, 16)) return true;
   if(InpUseNYSession   && IsInSession(t, 13, 22)) return true;
   if(InpUseLondonKZ    && IsInSession(t,  7, 10)) return true;
   if(InpUseLondon      && IsInSession(t,  8, 17)) return true;
   if(InpUseAsian       && IsInSession(t, 23,  8)) return true;
   return false;
  }

string CurrentSessionName()
  {
   datetime now = TimeCurrent();
   if(IsInSession(now, 13, 16)) return "NY Kill Zone";
   if(IsInSession(now, 13, 22)) return "Nueva York";
   if(IsInSession(now,  7, 10)) return "London KZ";
   if(IsInSession(now,  8, 17)) return "Londres";
   if(IsInSession(now, 23,  8)) return "Asia";
   return "Fuera sesion";
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

color Blend(color c, int alpha)
  {
   alpha = MathMax(0, MathMin(255, alpha));
   int r = (int)(((c >> 16) & 0xFF) * alpha / 255);
   int g = (int)(((c >>  8) & 0xFF) * alpha / 255);
   int b = (int)( (c & 0xFF)        * alpha / 255);
   return (color)((r << 16) | (g << 8) | b);
  }

void Box(string n, datetime t1, datetime t2, double hi, double lo, color c, int a)
  {
   ObjectDelete(0, n);
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
   ObjectDelete(0, n);
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
   ObjectDelete(0, n);
   if(!ObjectCreate(0, n, OBJ_TEXT, 0, t, p)) return;
   ObjectSetString(0,  n, OBJPROP_TEXT,       txt);
   ObjectSetInteger(0, n, OBJPROP_COLOR,      c);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE,   fsz);
   ObjectSetString(0,  n, OBJPROP_FONT,       "Arial Bold");
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN,     true);
  }

void EntryArrow(string n, datetime t, double price, bool bull, string lbl, color clr)
  {
   ObjectDelete(0, n);
   if(!ObjectCreate(0, n, OBJ_ARROW, 0, t, price)) return;
   ObjectSetInteger(0, n, OBJPROP_ARROWCODE,  bull ? 241 : 242);
   ObjectSetInteger(0, n, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, n, OBJPROP_WIDTH,      InpArrowSize + 1);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN,     false);
   string ln = n + "_L";
   ObjectDelete(0, ln);
   if(!ObjectCreate(0, ln, OBJ_TEXT, 0, t, price)) return;
   ObjectSetString(0,  ln, OBJPROP_TEXT,      "  " + lbl);
   ObjectSetInteger(0, ln, OBJPROP_COLOR,     clr);
   ObjectSetInteger(0, ln, OBJPROP_FONTSIZE,  9);
   ObjectSetString(0,  ln, OBJPROP_FONT,      "Arial Bold");
   ObjectSetInteger(0, ln, OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0, ln, OBJPROP_HIDDEN,    false);
  }

//==================================================================
//  SCORE → COLOR
//  Verde (≥80) · Amarillo (≥60) · Naranja (≥40) · Gris (<40)
//==================================================================
color ScoreColor(int score)
  {
   if(score >= 80) return clrLime;
   if(score >= 60) return clrGold;
   if(score >= 40) return clrOrange;
   return clrGray;
  }

//==================================================================
//  SCORE DE CONFLUENCIA (0–100)
//==================================================================
int CalcScore(bool bull,
              datetime sig_time,
              double entry,
              double sw_extreme,
              double rng,
              bool has_mss,
              bool has_fvg,
              double a_hi, double a_lo)
  {
   int s = 0;

   // +20 Kill Zone / +10 sesión regular
   if(IsInSession(sig_time, 13, 16) || IsInSession(sig_time, 7, 10)) s += 20;
   else if(IsActiveSession(sig_time)) s += 10;

   // +20 Entry cerca de número redondo
   if(NearRoundNumber(entry)) s += 20;

   // +15 Sweep tocó un nivel clave (PDH/PDL/PWH/PWL)
   double tol = rng * 0.08;
   if(bull)
     {
      if(g_pdl > 0 && MathAbs(sw_extreme - g_pdl) <= tol) s += 15;
      else if(g_pwl > 0 && MathAbs(sw_extreme - g_pwl) <= tol) s += 15;
     }
   else
     {
      if(g_pdh > 0 && MathAbs(sw_extreme - g_pdh) <= tol) s += 15;
      else if(g_pwh > 0 && MathAbs(sw_extreme - g_pwh) <= tol) s += 15;
     }

   // +15 D1 bias alineado
   if(InpUseD1Bias)
     {
      MqlRates d1[]; ArraySetAsSeries(d1, true);
      if(CopyRates(Symbol(), PERIOD_D1, 0, 2, d1) == 2)
        {
         bool d1_bull = (d1[1].close > d1[1].open);
         if(bull  && d1_bull)  s += 15;
         if(!bull && !d1_bull) s += 15;
        }
     }

   // +15 MSS confirmado
   if(has_mss) s += 15;

   // +15 FVG detectado
   if(has_fvg) s += 15;

   return MathMin(s, 100);
  }

//==================================================================
//  MSS / BOS en LTF
//  Bull: después del sweep bajo, precio rompe el último swing high
//        del tramo bajista que causó el sweep  → confirmación de que
//        la distribución alcista ya arrancó
//  Bear: simétrico
//  Devuelve la barra del MSS (índice) o -1 si no hay
//==================================================================
int FindMSS_Bull(const double &high[], const double &close[],
                 int sw_bar, int mb_s, int mb_e, int rtotal)
  {
   // Swing high = el high más alto del tramo bajista (entre mb_s y sw_bar)
   double swing_hi = 0;
   for(int i = sw_bar; i <= mb_s && i < rtotal; i++)
      if(high[i] > swing_hi) swing_hi = high[i];
   if(swing_hi <= 0) return -1;

   // Barra donde cierra por encima del swing high (después del sweep)
   for(int i = sw_bar - 1; i >= mb_e && i >= 0; i--)
      if(close[i] > swing_hi) return i;
   return -1;
  }

int FindMSS_Bear(const double &low[], const double &close[],
                 int sw_bar, int mb_s, int mb_e, int rtotal)
  {
   double swing_lo = DBL_MAX;
   for(int i = sw_bar; i <= mb_s && i < rtotal; i++)
      if(low[i] < swing_lo) swing_lo = low[i];
   if(swing_lo >= DBL_MAX) return -1;

   for(int i = sw_bar - 1; i >= mb_e && i >= 0; i--)
      if(close[i] < swing_lo) return i;
   return -1;
  }

//==================================================================
//  FVG — Fair Value Gap dentro del rango CRT
//  Bull FVG: high[i+1] < low[i-1]  (impulso alcista dejó un gap)
//  Bear FVG: low[i+1]  > high[i-1] (impulso bajista dejó un gap)
//  Escanea entre mb_e y mb_s, solo dentro de [a_lo, a_hi]
//  Devuelve el midpoint del primer FVG encontrado o 0.0 si no hay
//==================================================================
double FindFVG(const double &high[], const double &low[],
               int mb_s, int mb_e, double a_lo, double a_hi,
               bool bull, int rtotal)
  {
   int limit = MathMin(mb_s - 1, rtotal - 2);
   for(int i = mb_e + 1; i <= limit; i++)
     {
      if(i < 1 || i + 1 >= rtotal) continue;
      if(bull)
        {
         // Bullish FVG: gap alcista (high de vela más vieja < low de vela más nueva)
         double gap_lo = high[i + 1];
         double gap_hi = low[i - 1];
         if(gap_hi > gap_lo && gap_lo >= a_lo && gap_hi <= a_hi)
            return (gap_lo + gap_hi) * 0.5;
        }
      else
        {
         // Bearish FVG: gap bajista
         double gap_hi = low[i + 1];
         double gap_lo = high[i - 1];
         if(gap_hi > gap_lo && gap_lo >= a_lo && gap_hi <= a_hi)
            return (gap_lo + gap_hi) * 0.5;
        }
     }
   return 0.0;
  }

// Dibuja la caja del FVG con sus coordenadas exactas
void DrawFVGBox(string nm, const double &high[], const double &low[],
                int mb_s, int mb_e, double a_lo, double a_hi, bool bull,
                int rtotal, const datetime &time[])
  {
   if(!InpShowFVGBox) return;
   int limit = MathMin(mb_s - 1, rtotal - 2);
   int drawn = 0;
   for(int i = mb_e + 1; i <= limit && drawn < 3; i++)
     {
      if(i < 1 || i + 1 >= rtotal) continue;
      double gap_lo, gap_hi;
      if(bull)
        {
         gap_lo = high[i + 1]; gap_hi = low[i - 1];
        }
      else
        {
         gap_hi = low[i + 1]; gap_lo = high[i - 1];
        }
      if(gap_hi > gap_lo && gap_lo >= a_lo && gap_hi <= a_hi)
        {
         string fn = nm + "_fvg" + IntegerToString(drawn);
         if(ObjectFind(0, fn) < 0)
           {
            color fc = bull ? InpFVGBullColor : InpFVGBearColor;
            // Extend FVG box 5 bars to the left of the bar
            datetime t1 = (i + 5 < rtotal) ? time[i + 5] : time[i];
            datetime t2 = (i >= 1) ? time[i - 1] : time[0];
            Box(fn, t1, t2, gap_hi, gap_lo, fc, InpFVGAlpha);
            Txt(fn + "_L", time[i], gap_hi, " FVG", fc, 7);
           }
         drawn++;
        }
     }
  }

//==================================================================
//  ZONA VISUAL R:R
//  Rectángulo rojo entre entry y SL + rectángulo verde entry→TP2
//==================================================================
void DrawRRZone(string nm, datetime t1, datetime t2,
                double entry, double sl, double tp1, double tp2, bool bull)
  {
   if(!InpShowRRZone) return;
   if(ObjectFind(0, nm + "_rrisk") >= 0) return;

   // Zona de riesgo (entry → SL)
   Box(nm + "_rrisk", t1, t2,
       bull ? entry : sl,
       bull ? sl    : entry,
       InpRRRiskColor, InpRRAlpha);

   // Zona de ganancia TP1 (entry → TP1)
   Box(nm + "_rrtp1", t1, t2,
       bull ? tp1   : entry,
       bull ? entry : tp1,
       InpRRProfColor, InpRRAlpha - 5);

   // Zona de ganancia TP2 (TP1 → TP2, más intensa)
   Box(nm + "_rrtp2", t1, t2,
       bull ? tp2 : tp1,
       bull ? tp1 : tp2,
       InpRRProfColor, InpRRAlpha + 10);

   // Ratio R:R
   double risk   = MathAbs(entry - sl);
   double reward = MathAbs(tp2   - entry);
   if(risk > 0)
     {
      double rr = reward / risk;
      Txt(nm + "_rrL", t1,
          bull ? (tp2 + risk * 0.1) : (tp2 - risk * 0.1),
          " R:R 1:" + DoubleToString(rr, 1),
          clrWhite, 8);
     }
  }

//==================================================================
//  SETUP VISUAL (anchor box, manip box, levels)
//  Solo se dibuja si la caja anchor NO existe aún
//==================================================================
bool DrawSetup(string b, datetime a_t1, datetime a_t2, datetime m_t1, datetime m_t2,
               double a_hi, double a_lo, double m_hi, double m_lo,
               double mid, double sl_p, double cur_atr, bool bull, int score)
  {
   if(ObjectFind(0, b + "_ab") >= 0) return false;

   color box_c  = bull ? InpBullColor : InpBearColor;
   double entry = bull ? a_lo : a_hi;
   double target = bull ? a_hi : a_lo;

   if(InpShowAnchorBox)
      Box(b+"_ab", a_t1, a_t2, a_hi, a_lo, box_c, InpBoxAlpha);
   if(InpShowManipBox)
      Box(b+"_mb", m_t1, m_t2, m_hi, m_lo, box_c, InpBoxAlpha - 12);
   if(InpShow50Line)
     {
      HLine(b+"_mid", a_t1, m_t2, mid, clrGold, 1, STYLE_DASH);
      Txt(b+"_midL", a_t1, mid + cur_atr*0.03, " EQ 50%", clrGold, 7);
     }
   HLine(b+"_entry", m_t1, m_t2, entry,
         bull ? clrLime : clrRed, 2, STYLE_SOLID);
   Txt(b+"_entL", m_t1, entry + (bull ? cur_atr*0.02 : cur_atr*0.03),
       " ENTRY: " + DoubleToString(entry, _Digits),
       bull ? clrLime : clrRed, 8);
   if(InpShowSL)
     {
      HLine(b+"_sl", m_t1, m_t2, sl_p, InpSLColor, 1, STYLE_DOT);
      Txt(b+"_slL", m_t1, sl_p + (bull ? -cur_atr*0.04 : cur_atr*0.03),
          " SL: " + DoubleToString(sl_p, _Digits), InpSLColor, 7);
     }
   if(InpShowTP1)
     {
      HLine(b+"_tp1", m_t1, m_t2, mid, InpTP1Color, 1, STYLE_DASH);
      Txt(b+"_tp1L", m_t1, mid + (bull ? cur_atr*0.03 : -cur_atr*0.05),
          " TP1: " + DoubleToString(mid, _Digits), InpTP1Color, 7);
     }
   if(InpShowTP2)
     {
      HLine(b+"_tp2", m_t1, m_t2, target, InpTP2Color, 2, STYLE_DOT);
      Txt(b+"_tp2L", m_t1, target + (bull ? cur_atr*0.03 : -cur_atr*0.05),
          " TP2: " + DoubleToString(target, _Digits), InpTP2Color, 8);
     }
   // Score badge en la esquina de la caja
   if(InpShowScore)
      Txt(b+"_sc", a_t1, bull ? a_hi + cur_atr*0.05 : a_lo - cur_atr*0.08,
          " Score: " + IntegerToString(score) + "/100",
          ScoreColor(score), 9);

   return true;
  }

//==================================================================
//  ROUND NUMBERS
//==================================================================
bool NearRoundNumber(double price)
  {
   if(!InpRoundFilter) return true;
   double bf   = g_big_figure;
   double zone = bf * InpRoundZonePct;
   double mod  = MathMod(MathAbs(price), bf * 0.25);
   return (mod < zone || (bf * 0.25 - mod) < zone);
  }

void RoundLine(string n, double price, color clr, int width, ENUM_LINE_STYLE style, string lbl)
  {
   if(ObjectFind(0, n) >= 0) return;
   if(!ObjectCreate(0, n, OBJ_HLINE, 0, 0, price)) return;
   ObjectSetInteger(0, n, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, n, OBJPROP_WIDTH,      width);
   ObjectSetInteger(0, n, OBJPROP_STYLE,      style);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN,     true);
   if(lbl != "")
     {
      string ln = n + "_L";
      if(ObjectFind(0, ln) >= 0) return;
      if(!ObjectCreate(0, ln, OBJ_TEXT, 0, TimeCurrent(), price)) return;
      ObjectSetString(0,  ln, OBJPROP_TEXT,       " " + lbl);
      ObjectSetInteger(0, ln, OBJPROP_COLOR,      clr);
      ObjectSetInteger(0, ln, OBJPROP_FONTSIZE,   7);
      ObjectSetString(0,  ln, OBJPROP_FONT,       "Arial Bold");
      ObjectSetInteger(0, ln, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, ln, OBJPROP_HIDDEN,     true);
     }
  }

void DrawRoundNumbers()
  {
   if(!InpShowRound) return;
   double price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double bf    = g_big_figure;
   double base  = MathFloor(price / bf) * bf;
   for(int i = -InpRoundLevels; i <= InpRoundLevels; i++)
     {
      double lvl = NormalizeDouble(base + i * bf, _Digits);
      RoundLine(g_pfx+"RN00_"+DoubleToString(lvl,_Digits), lvl,
                InpRound00Color, InpRound00Width, STYLE_SOLID,
                DoubleToString(lvl,_Digits)+" [00]");
      if(InpShowHalf)
        {
         double l50 = NormalizeDouble(lvl + bf*0.50, _Digits);
         RoundLine(g_pfx+"RN50_"+DoubleToString(l50,_Digits), l50,
                   InpRound50Color, InpRound50Width, STYLE_DASH,
                   DoubleToString(l50,_Digits)+" [50]");
        }
      if(InpShowQuarters)
        {
         double l25 = NormalizeDouble(lvl + bf*0.25, _Digits);
         double l75 = NormalizeDouble(lvl + bf*0.75, _Digits);
         RoundLine(g_pfx+"RN25_"+DoubleToString(l25,_Digits), l25,
                   InpRoundQtrColor, InpRoundQtrWidth, STYLE_DOT,
                   DoubleToString(l25,_Digits)+" [25]");
         RoundLine(g_pfx+"RN75_"+DoubleToString(l75,_Digits), l75,
                   InpRoundQtrColor, InpRoundQtrWidth, STYLE_DOT,
                   DoubleToString(l75,_Digits)+" [75]");
        }
     }
  }

//==================================================================
//  KEY LEVELS
//==================================================================
void KeyHLine(string n, double price, color clr, int width, string lbl)
  {
   if(ObjectFind(0, n) >= 0)
     {
      ObjectSetDouble(0, n, OBJPROP_PRICE, price);
      if(ObjectFind(0, n+"_L") >= 0)
         ObjectSetDouble(0, n+"_L", OBJPROP_PRICE, price);
      return;
     }
   if(!ObjectCreate(0, n, OBJ_HLINE, 0, 0, price)) return;
   ObjectSetInteger(0, n, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, n, OBJPROP_WIDTH,      width);
   ObjectSetInteger(0, n, OBJPROP_STYLE,      STYLE_DASH);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN,     true);
   if(InpKeyLevelLabel && lbl != "")
     {
      string ln = n + "_L";
      if(!ObjectCreate(0, ln, OBJ_TEXT, 0, TimeCurrent(), price)) return;
      ObjectSetString(0,  ln, OBJPROP_TEXT,       " " + lbl);
      ObjectSetInteger(0, ln, OBJPROP_COLOR,      clr);
      ObjectSetInteger(0, ln, OBJPROP_FONTSIZE,   8);
      ObjectSetString(0,  ln, OBJPROP_FONT,       "Arial Bold");
      ObjectSetInteger(0, ln, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, ln, OBJPROP_HIDDEN,     true);
     }
  }

void DrawKeyLevels()
  {
   if(InpShowPDHL)
     {
      MqlRates d[]; ArraySetAsSeries(d, true);
      if(CopyRates(Symbol(), PERIOD_D1, 1, 1, d) == 1)
        {
         g_pdh = d[0].high; g_pdl = d[0].low;
         KeyHLine(g_pfx+"PDH", g_pdh, InpPDHColor, InpKeyLevelWidth, "PDH");
         KeyHLine(g_pfx+"PDL", g_pdl, InpPDLColor, InpKeyLevelWidth, "PDL");
        }
     }
   if(InpShowPWHL)
     {
      MqlRates w[]; ArraySetAsSeries(w, true);
      if(CopyRates(Symbol(), PERIOD_W1, 1, 1, w) == 1)
        {
         g_pwh = w[0].high; g_pwl = w[0].low;
         KeyHLine(g_pfx+"PWH", g_pwh, InpPWHColor, InpKeyLevelWidth, "PWH");
         KeyHLine(g_pfx+"PWL", g_pwl, InpPWLColor, InpKeyLevelWidth, "PWL");
        }
     }
   if(InpShowPMHL)
     {
      MqlRates m[]; ArraySetAsSeries(m, true);
      if(CopyRates(Symbol(), PERIOD_MN1, 1, 1, m) == 1)
        {
         g_pmh = m[0].high; g_pml = m[0].low;
         KeyHLine(g_pfx+"PMH", g_pmh, InpPMHColor, InpKeyLevelWidth, "PMH");
         KeyHLine(g_pfx+"PML", g_pml, InpPMLColor, InpKeyLevelWidth, "PML");
        }
     }
  }

//==================================================================
//  SESSION BOXES (una vez por día)
//==================================================================
void DrawOneDaySession(datetime day_broker, int h_start, int h_end,
                       color clr, string lbl, int alpha)
  {
   int hd = InpGMTOffset;
   datetime s = day_broker + (h_start - hd) * 3600;
   datetime e = day_broker + (h_end   - hd) * 3600;
   string sn  = g_pfx + "SES_" + lbl + "_" + IntegerToString((int)day_broker);
   if(ObjectFind(0, sn) >= 0) return;
   Box(sn, s, e, 99999, 0, clr, alpha);
   Txt(sn+"_L", s, 0, lbl, clr, 7);
  }

void DrawSessionBoxes(const datetime &time[], int rates_total)
  {
   if(!InpHighlightSess) return;
   int scan = MathMin(rates_total, 500);
   for(int i = scan - 1; i >= 0; i--)
     {
      datetime utc = time[i] - InpGMTOffset * 3600;
      MqlDateTime mdt; TimeToStruct(utc, mdt);
      datetime day_utc    = utc - mdt.hour*3600 - mdt.min*60 - mdt.sec;
      datetime day_broker = day_utc + InpGMTOffset * 3600;
      if(InpUseNYSession)   DrawOneDaySession(day_broker, 13, 22, InpNYColor,      "NY",    InpSessAlpha);
      if(InpUseNYKillZone)  DrawOneDaySession(day_broker, 13, 16, InpNYKZColor,    "NY_KZ", InpSessAlpha+10);
      if(InpUseLondon)      DrawOneDaySession(day_broker,  8, 17, InpLondonColor,  "LON",   InpSessAlpha);
      if(InpUseLondonKZ)    DrawOneDaySession(day_broker,  7, 10, InpLondonKZColor,"LON_KZ",InpSessAlpha+10);
      if(InpUseAsian)       DrawOneDaySession(day_broker, 23, 32, InpAsianColor,   "ASIA",  InpSessAlpha);
     }
  }

//==================================================================
//  DASHBOARD (labels created once, text updated in-place)
//==================================================================
void Dash(string n, string txt, color c, int row)
  {
   if(ObjectFind(0, n) < 0)
     {
      ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, n, OBJPROP_FONTSIZE,   9);
      ObjectSetString(0,  n, OBJPROP_FONT,       "Courier New");
      ObjectSetInteger(0, n, OBJPROP_CORNER,     InpDashCorner);
      ObjectSetInteger(0, n, OBJPROP_XDISTANCE,  10);
      ObjectSetInteger(0, n, OBJPROP_YDISTANCE,  15 + row * 14);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN,     false);
     }
   ObjectSetString(0,  n, OBJPROP_TEXT,  txt);
   ObjectSetInteger(0, n, OBJPROP_COLOR, c);
  }

void UpdateDash(int bull, int bear, string sess)
  {
   if(!InpDash) return;
   string p = g_pfx + "D_";

   double price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double bf    = g_big_figure;
   double near  = MathRound(price / bf) * bf;
   double dpips = MathAbs(price - near) / _Point / 10.0;

   string pdh_s = (g_pdh > 0) ? DoubleToString(g_pdh,_Digits) : "---";
   string pdl_s = (g_pdl > 0) ? DoubleToString(g_pdl,_Digits) : "---";
   string pwh_s = (g_pwh > 0) ? DoubleToString(g_pwh,_Digits) : "---";
   string pwl_s = (g_pwl > 0) ? DoubleToString(g_pwl,_Digits) : "---";
   string rn_s  = DoubleToString(near,_Digits)
                  + " (" + DoubleToString(dpips,1) + "p)";
   string sc_s  = IntegerToString(g_last_score) + "/100";
   string minscore_s = "min=" + IntegerToString(InpMinScore);

   Dash(p+"r0",  "╔════════════════════════════╗",                                    clrGray,   0);
   Dash(p+"r1",  "║  CRT Candle Range Theory v6  ║",                                  clrGold,   1);
   Dash(p+"r2",  "║  HTF: "+StringFormat("%-22s",EnumToString(InpHTF))+"║",           clrSilver, 2);
   Dash(p+"r3",  "╠════════════════════════════╣",                                    clrGray,   3);
   Dash(p+"r4",  "║  BULL: "+StringFormat("%-4d",bull)+" BEAR: "+StringFormat("%-16d",bear)+"║", clrSilver,4);
   Dash(p+"r5",  "║  Último: "+StringFormat("%-20s",g_last_sig)+"║",                  g_last_clr,5);
   Dash(p+"r6",  "║  Score: "+StringFormat("%-21s",sc_s)+"║",                         ScoreColor(g_last_score),6);
   Dash(p+"r7",  "╠════════════════════════════╣",                                    clrGray,   7);
   Dash(p+"r8",  "║  Sesión: "+StringFormat("%-21s",sess)+"║",                        clrAqua,   8);
   Dash(p+"r9",  "╠════════════════════════════╣",                                    clrGray,   9);
   Dash(p+"r10", "║  PDH: "+StringFormat("%-23s",pdh_s)+"║",                          InpPDHColor,10);
   Dash(p+"r11", "║  PDL: "+StringFormat("%-23s",pdl_s)+"║",                          InpPDLColor,11);
   Dash(p+"r12", "║  PWH: "+StringFormat("%-23s",pwh_s)+"║",                          InpPWHColor,12);
   Dash(p+"r13", "║  PWL: "+StringFormat("%-23s",pwl_s)+"║",                          InpPWLColor,13);
   Dash(p+"r14", "╠════════════════════════════╣",                                    clrGray,   14);
   Dash(p+"r15", "║  RN00: "+StringFormat("%-22s",rn_s)+"║",                          InpRound00Color,15);
   Dash(p+"r16", "║  "+StringFormat("%-27s",minscore_s)+"║",                          clrGray,   16);
   Dash(p+"r17", "╚════════════════════════════╝",                                    clrGray,   17);
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

   ArraySetAsSeries(time,  true);
   ArraySetAsSeries(open,  true);
   ArraySetAsSeries(high,  true);
   ArraySetAsSeries(low,   true);
   ArraySetAsSeries(close, true);

   //--- Guard: trabajo pesado SOLO en nueva barra
   static datetime s_last_ltf = 0;
   bool new_bar = (time[0] != s_last_ltf);
   if(!new_bar && prev_calculated > 0)
     {
      UpdateDash(0, 0, CurrentSessionName());
      return rates_total;
     }
   s_last_ltf = time[0];

   if(prev_calculated == 0)
     {
      ArrayInitialize(BuyBuf,       EMPTY_VALUE);
      ArrayInitialize(SellBuf,      EMPTY_VALUE);
      ArrayInitialize(ManipLowBuf,  EMPTY_VALUE);
      ArrayInitialize(ManipHighBuf, EMPTY_VALUE);
      ArrayInitialize(MSSBuf,       EMPTY_VALUE);
      ArrayInitialize(FVGBuf,       EMPTY_VALUE);
      CleanObjects();
      g_last_htf_t  = 0; g_last_sess_day = 0;
      g_last_kl_day = 0; g_last_kl_week  = 0;
      g_big_figure  = (InpBigFigure > 0.0) ? InpBigFigure : AutoBigFigure();
     }

   //--- ATR
   double atr[];
   ArraySetAsSeries(atr, true);
   int atr_need = MathMin(InpLookback * 5 + 30, rates_total);
   if(CopyBuffer(g_atr, 0, 0, atr_need, atr) <= 0) return 0;
   int atr_size = ArraySize(atr);

   //--- HTF cache
   datetime cur_htf = iTime(Symbol(), InpHTF, 0);
   if(cur_htf != g_last_htf_t || prev_calculated == 0)
     {
      g_htf_cnt = CopyRates(Symbol(), InpHTF, 0, InpLookback + 3, g_htf);
      ArraySetAsSeries(g_htf, true);
      g_last_htf_t = cur_htf;
     }
   if(g_htf_cnt < 3) return 0;

   //--- Day / week guards para niveles y sesiones
   datetime cur_utc = TimeCurrent() - InpGMTOffset * 3600;
   MqlDateTime mdt; TimeToStruct(cur_utc, mdt);
   datetime cur_day  = (datetime)(cur_utc - mdt.hour*3600 - mdt.min*60 - mdt.sec)
                       + InpGMTOffset * 3600;
   int dow = mdt.day_of_week;
   datetime cur_week = cur_day - (datetime)((dow == 0 ? 6 : dow - 1) * 86400);

   if(cur_day != g_last_sess_day || prev_calculated == 0)
     {
      DrawSessionBoxes(time, rates_total);
      DrawRoundNumbers();
      DrawKeyLevels();
      g_last_sess_day = cur_day;
      g_last_kl_day   = cur_day;
     }
   if(cur_week != g_last_kl_week || prev_calculated == 0)
     {
      DrawKeyLevels();
      g_last_kl_week = cur_week;
     }

   double pip = InpArrowPips * _Point;
   int bull_cnt = 0, bear_cnt = 0;

   //=================================================================
   //  SCAN HTF CANDLES
   //=================================================================
   for(int h = 2; h < g_htf_cnt - 1; h++)
     {
      double a_hi  = g_htf[h].high,  a_lo  = g_htf[h].low;
      double a_op  = g_htf[h].open,  a_cl  = g_htf[h].close;
      double rng   = a_hi - a_lo;
      datetime a_t1 = g_htf[h].time, a_t2  = g_htf[h-1].time;

      double m_hi  = g_htf[h-1].high, m_lo  = g_htf[h-1].low;
      double m_cl  = g_htf[h-1].close;
      datetime m_t1 = g_htf[h-1].time;
      datetime m_t2 = (h >= 2) ? g_htf[h-2].time : time[0];

      int a_bar = iBarShift(Symbol(), Period(), a_t1, false);
      if(a_bar < 0 || a_bar >= rates_total) continue;
      double cur_atr = atr[MathMin(a_bar, atr_size - 1)];
      if(cur_atr <= 0.0) continue;
      if(rng < InpMinATR * cur_atr || rng > InpMaxATR * cur_atr) continue;

      double mid = a_lo + rng * 0.5;
      string b   = g_pfx + TimeToString(a_t1, TIME_DATE|TIME_MINUTES);
      StringReplace(b, ":", ""); StringReplace(b, " ", "_");

      if(InpShowHTFOverlay && ObjectFind(0, b+"_htf") < 0)
        {
         color oc = (a_cl >= a_op) ? C'0,55,0' : C'55,0,0';
         Box(b+"_htf", a_t1, a_t2, a_hi, a_lo, oc, InpHTFAlpha);
        }

      int mb_s = MathMax(0, MathMin(iBarShift(Symbol(),Period(),m_t1,false), rates_total-1));
      int mb_e = MathMax(0, MathMin(iBarShift(Symbol(),Period(),m_t2,false), rates_total-1));

      //==============================================================
      // BULLISH CRT ↑
      //==============================================================
      bool b_sweep = (m_lo < a_lo);
      bool b_reent = InpReqClose ? (m_cl > a_lo) : b_sweep;

      if(b_sweep && b_reent)
        {
         // Sweep bar (lowest low)
         int sw_bar = mb_s; double sw_lo = low[mb_s];
         for(int i = mb_e; i <= mb_s; i++)
            if(low[i] < sw_lo) { sw_lo = low[i]; sw_bar = i; }

         // Signal bar (first close back above anchor_low)
         int sig_bar = mb_e;
         for(int i = sw_bar; i >= mb_e; i--)
            if(close[i] > a_lo) { sig_bar = i; break; }

         double sl_p = sw_lo - InpSLBuffer * cur_atr;

         // MSS detection
         int mss_bar = -1;
         if(InpUseMSS)
            mss_bar = FindMSS_Bull(high, close, sw_bar, mb_s, mb_e, rates_total);

         // FVG detection
         double fvg_mid = 0.0;
         if(InpUseFVG)
            fvg_mid = FindFVG(high, low, mb_s, mb_e, a_lo, a_hi, true, rates_total);

         // Score
         int score = CalcScore(true, time[sig_bar], a_lo, sw_lo, rng,
                               mss_bar >= 0, fvg_mid > 0.0, a_hi, a_lo);
         bull_cnt++;

         // Visual (siempre dibuja el setup, cualquier score)
         bool newly_drawn = DrawSetup(b, a_t1, a_t2, m_t1, m_t2,
                                      a_hi, a_lo, m_hi, m_lo,
                                      mid, sl_p, cur_atr, true, score);

         // FVG box
         if(InpUseFVG && newly_drawn)
            DrawFVGBox(b, high, low, mb_s, mb_e, a_lo, a_hi, true, rates_total, time);

         // Sweep marker
         if(InpShowManip && ManipLowBuf[sw_bar] == EMPTY_VALUE)
            ManipLowBuf[sw_bar] = low[sw_bar] - pip;

         // MSS marker
         if(mss_bar >= 0 && MSSBuf[mss_bar] == EMPTY_VALUE)
            MSSBuf[mss_bar] = low[mss_bar] - pip * 1.5;

         // FVG marker
         if(fvg_mid > 0.0 && FVGBuf[sig_bar] == EMPTY_VALUE)
            FVGBuf[sig_bar] = fvg_mid;

         // Señal de entrada: requiere score mínimo + sesión + redondo
         if(score >= InpMinScore && IsActiveSession(time[sig_bar]) && NearRoundNumber(a_lo))
           {
            color sig_clr = ScoreColor(score);
            if(InpShowBuy && BuyBuf[sig_bar] == EMPTY_VALUE)
              {
               BuyBuf[sig_bar] = a_lo - pip * 2;
               string lbl = "BUY @ " + DoubleToString(a_lo,_Digits)
                            + "  [" + IntegerToString(score) + "]";
               EntryArrow(b+"_buy", time[sig_bar], a_lo - pip, true, lbl, sig_clr);
              }
            // R:R zone
            DrawRRZone(b, m_t1, m_t2, a_lo, sl_p, mid, a_hi, true);

            // TP levels are shown as chart objects (HLines in DrawSetup)

            g_last_sig   = "BUY  [" + IntegerToString(score) + "]";
            g_last_clr   = sig_clr;
            g_last_score = score;

            if(InpAlerts && sig_bar <= 1 && TimeCurrent() != g_last_alert)
              {
               g_last_alert = TimeCurrent();
               double risk = MathAbs(a_lo - sl_p);
               double rr   = (risk > 0) ? MathAbs(a_hi - a_lo) / risk : 0;
               string msg = "CRT BUY " + Symbol() + " [" + EnumToString(InpHTF) + "]"
                            + "  Score:" + IntegerToString(score)
                            + "  Entry:" + DoubleToString(a_lo,_Digits)
                            + "  TP:"    + DoubleToString(a_hi,_Digits)
                            + "  SL:"    + DoubleToString(sl_p,_Digits)
                            + "  R:R 1:" + DoubleToString(rr,1)
                            + (mss_bar >= 0 ? "  MSS✓" : "")
                            + (fvg_mid > 0  ? "  FVG✓" : "");
               Alert(msg);
               if(InpPushNotif) SendNotification(msg);
               PlaySound("alert.wav");
              }
           }
        }

      //==============================================================
      // BEARISH CRT ↓
      //==============================================================
      bool s_sweep = (m_hi > a_hi);
      bool s_reent = InpReqClose ? (m_cl < a_hi) : s_sweep;

      if(s_sweep && s_reent)
        {
         int sw_bar = mb_s; double sw_hi = high[mb_s];
         for(int i = mb_e; i <= mb_s; i++)
            if(high[i] > sw_hi) { sw_hi = high[i]; sw_bar = i; }

         int sig_bar = mb_e;
         for(int i = sw_bar; i >= mb_e; i--)
            if(close[i] < a_hi) { sig_bar = i; break; }

         double sl_p = sw_hi + InpSLBuffer * cur_atr;

         int mss_bar = -1;
         if(InpUseMSS)
            mss_bar = FindMSS_Bear(low, close, sw_bar, mb_s, mb_e, rates_total);

         double fvg_mid = 0.0;
         if(InpUseFVG)
            fvg_mid = FindFVG(high, low, mb_s, mb_e, a_lo, a_hi, false, rates_total);

         int score = CalcScore(false, time[sig_bar], a_hi, sw_hi, rng,
                               mss_bar >= 0, fvg_mid > 0.0, a_hi, a_lo);
         bear_cnt++;

         bool newly_drawn = DrawSetup(b, a_t1, a_t2, m_t1, m_t2,
                                      a_hi, a_lo, m_hi, m_lo,
                                      mid, sl_p, cur_atr, false, score);

         if(InpUseFVG && newly_drawn)
            DrawFVGBox(b, high, low, mb_s, mb_e, a_lo, a_hi, false, rates_total, time);

         if(InpShowManip && ManipHighBuf[sw_bar] == EMPTY_VALUE)
            ManipHighBuf[sw_bar] = high[sw_bar] + pip;

         if(mss_bar >= 0 && MSSBuf[mss_bar] == EMPTY_VALUE)
            MSSBuf[mss_bar] = high[mss_bar] + pip * 1.5;

         if(fvg_mid > 0.0 && FVGBuf[sig_bar] == EMPTY_VALUE)
            FVGBuf[sig_bar] = fvg_mid;

         if(score >= InpMinScore && IsActiveSession(time[sig_bar]) && NearRoundNumber(a_hi))
           {
            color sig_clr = ScoreColor(score);
            if(InpShowSell && SellBuf[sig_bar] == EMPTY_VALUE)
              {
               SellBuf[sig_bar] = a_hi + pip * 2;
               string lbl = "SELL @ " + DoubleToString(a_hi,_Digits)
                            + "  [" + IntegerToString(score) + "]";
               EntryArrow(b+"_sell", time[sig_bar], a_hi + pip, false, lbl, sig_clr);
              }
            DrawRRZone(b, m_t1, m_t2, a_hi, sl_p, mid, a_lo, false);

            // TP levels are shown as chart objects (HLines in DrawSetup)

            g_last_sig   = "SELL [" + IntegerToString(score) + "]";
            g_last_clr   = sig_clr;
            g_last_score = score;

            if(InpAlerts && sig_bar <= 1 && TimeCurrent() != g_last_alert)
              {
               g_last_alert = TimeCurrent();
               double risk = MathAbs(a_hi - sl_p);
               double rr   = (risk > 0) ? MathAbs(a_hi - a_lo) / risk : 0;
               string msg = "CRT SELL " + Symbol() + " [" + EnumToString(InpHTF) + "]"
                            + "  Score:" + IntegerToString(score)
                            + "  Entry:" + DoubleToString(a_hi,_Digits)
                            + "  TP:"    + DoubleToString(a_lo,_Digits)
                            + "  SL:"    + DoubleToString(sl_p,_Digits)
                            + "  R:R 1:" + DoubleToString(rr,1)
                            + (mss_bar >= 0 ? "  MSS✓" : "")
                            + (fvg_mid > 0  ? "  FVG✓" : "");
               Alert(msg);
               if(InpPushNotif) SendNotification(msg);
               PlaySound("alert.wav");
              }
           }
        }
     }

   UpdateDash(bull_cnt, bear_cnt, CurrentSessionName());
   return rates_total;
  }
//+------------------------------------------------------------------+
