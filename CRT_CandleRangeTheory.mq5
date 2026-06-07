//+------------------------------------------------------------------+
//|                                     CRT_CandleRangeTheory.mq5   |
//|                         Candle Range Theory (CRT) Indicator      |
//|                                                                  |
//|  AMD Framework: Accumulation → Manipulation → Distribution       |
//|  Flechas de entrada exactas en nivel de compra/venta            |
//|  Filtro de sesiones: NY, Londres, Asia + Kill Zones             |
//|  Niveles SL y TP automáticos                                    |
//|  Señales NO REPINTAN (solo velas cerradas)                      |
//|                                                                  |
//|  v4.0 – Optimizado para no ralentizar MT5:                      |
//|    • Guard de nueva vela: cálculo pesado solo en nueva barra    |
//|    • CopyRates/CopyBuffer cacheados entre cambios de HTF bar    |
//|    • Objetos de chart creados UNA vez, no recreados cada tick   |
//|    • Dashboard actualiza texto en labels existentes             |
//|    • Cajas de sesión dibujadas UNA vez por día                 |
//|    • ChartRedraw eliminado (MT5 lo hace automáticamente)        |
//+------------------------------------------------------------------+
#property copyright   "CRT - Candle Range Theory v5.0"
#property version     "5.00"
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   6

#property indicator_label1  "CRT BUY ENTRY"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLime
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

#property indicator_label2  "CRT SELL ENTRY"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  3

#property indicator_label3  "Manip LOW (Bullish Trap)"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrDeepSkyBlue
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

#property indicator_label4  "Manip HIGH (Bearish Trap)"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrOrangeRed
#property indicator_style4  STYLE_SOLID
#property indicator_width4  2

#property indicator_label5  "CRT TP1 (50%)"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrGold
#property indicator_style5  STYLE_SOLID
#property indicator_width5  1

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
input bool            InpReqClose   = true;       // Require manip candle to CLOSE back inside

input group "=== Sesiones / Session Filter ==="
input bool   InpFilterSession  = true;   // Filtrar señales por sesión activa
input int    InpGMTOffset      = 0;      // GMT del servidor broker (ej: 2 para EET)
input bool   InpUseNYSession   = true;   // Nueva York  (13–22 UTC)
input bool   InpUseNYKillZone  = true;   // NY Kill Zone (13:30–16 UTC)  ← Mejor para CRT
input bool   InpUseLondon      = true;   // Londres (08–17 UTC)
input bool   InpUseLondonKZ    = true;   // London Kill Zone (07–10 UTC) ← Mejor para CRT
input bool   InpUseAsian       = false;  // Asia (23–08 UTC)
input bool   InpHighlightSess  = true;   // Dibujar cajas de sesión
input color  InpNYColor        = C'0,50,100';
input color  InpNYKZColor      = C'0,80,160';
input color  InpLondonColor    = C'0,80,0';
input color  InpLondonKZColor  = C'0,130,0';
input color  InpAsianColor     = C'60,40,0';
input int    InpSessAlpha      = 18;

input group "=== Señales / Signals ==="
input bool   InpShowBuy        = true;
input bool   InpShowSell       = true;
input bool   InpShowManip      = true;
input bool   InpAlerts         = false;
input bool   InpPushNotif      = false;

input group "=== Niveles SL / TP ==="
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

input group "=== Números Redondos / Round Numbers ==="
input bool   InpShowRound      = true;   // Mostrar números redondos (00) y cuartos (25/50/75)
input double InpBigFigure      = 0.0;    // Tamaño big figure (0 = auto según instrumento)
input bool   InpShowQuarters   = true;   // Mostrar cuartos (25 / 75)
input bool   InpShowHalf       = true;   // Mostrar mitad (50)
input int    InpRoundLevels    = 10;     // Cuántos niveles arriba y abajo dibujar
input color  InpRound00Color   = C'200,200,0';   // Color nivel 00 (big figure)
input color  InpRound50Color   = C'140,140,0';   // Color nivel 50
input color  InpRoundQtrColor  = C'80,80,0';     // Color cuartos (25/75)
input int    InpRound00Width   = 2;              // Grosor línea 00
input int    InpRound50Width   = 1;              // Grosor línea 50
input int    InpRoundQtrWidth  = 1;              // Grosor línea cuartos
input bool   InpRoundFilter    = false;  // Solo mostrar señales CRT cerca de número redondo
input double InpRoundZonePct   = 0.15;   // % del big figure = zona "cerca" de redondo

input group "=== Niveles Clave / Key Levels ==="
input bool   InpShowPDHL       = true;   // Previous Day High / Low (PDH/PDL)
input bool   InpShowPWHL       = true;   // Previous Week High / Low (PWH/PWL)
input bool   InpShowPMHL       = false;  // Previous Month High / Low (PMH/PML)
input color  InpPDHColor       = C'0,180,255';   // Color Previous Day High
input color  InpPDLColor       = C'255,80,0';    // Color Previous Day Low
input color  InpPWHColor       = C'0,120,200';   // Color Previous Week High
input color  InpPWLColor       = C'200,60,0';    // Color Previous Week Low
input color  InpPMHColor       = C'0,80,160';    // Color Previous Month High
input color  InpPMLColor       = C'160,40,0';    // Color Previous Month Low
input int    InpKeyLevelWidth  = 2;              // Grosor líneas PDH/PDL/PWH/PWL
input bool   InpKeyLevelLabel  = true;           // Mostrar etiquetas

input group "=== Dashboard ==="
input bool            InpDash       = true;
input ENUM_BASE_CORNER InpDashCorner = CORNER_LEFT_UPPER;

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
int    g_atr = INVALID_HANDLE;
string g_pfx;
datetime g_last_alert = 0;

// Cache: HTF bars (refreshed only when HTF bar changes)
MqlRates g_htf[];
datetime g_last_htf_t  = 0;
int      g_htf_cnt     = 0;

// Cache: session boxes (drawn once per day)
datetime g_last_sess_day = 0;

// Cache: key levels (refreshed on new day/week)
datetime g_last_kl_day  = 0;
datetime g_last_kl_week = 0;
double   g_pdh = 0, g_pdl = 0;
double   g_pwh = 0, g_pwl = 0;
double   g_pmh = 0, g_pml = 0;
double   g_big_figure = 0;  // computed once in OnInit

//==================================================================
//  INIT
//==================================================================
int OnInit()
  {
   g_pfx = "CRT_" + Symbol() + IntegerToString(Period()) + "_";
   ArraySetAsSeries(g_htf, true);

   SetIndexBuffer(0, BuyBuf,       INDICATOR_DATA);
   SetIndexBuffer(1, SellBuf,      INDICATOR_DATA);
   SetIndexBuffer(2, ManipLowBuf,  INDICATOR_DATA);
   SetIndexBuffer(3, ManipHighBuf, INDICATOR_DATA);
   SetIndexBuffer(4, TP1Buf,       INDICATOR_DATA);
   SetIndexBuffer(5, TP2Buf,       INDICATOR_DATA);

   // Arrow glyphs
   PlotIndexSetInteger(0, PLOT_ARROW, 241);
   PlotIndexSetInteger(1, PLOT_ARROW, 242);
   PlotIndexSetInteger(2, PLOT_ARROW, 233);
   PlotIndexSetInteger(3, PLOT_ARROW, 234);
   PlotIndexSetInteger(4, PLOT_ARROW, 167);
   PlotIndexSetInteger(5, PLOT_ARROW, 167);

   // Arrow sizes
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpArrowSize);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpArrowSize);
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, InpManipSize);
   PlotIndexSetInteger(3, PLOT_LINE_WIDTH, InpManipSize);
   PlotIndexSetInteger(4, PLOT_LINE_WIDTH, 1);
   PlotIndexSetInteger(5, PLOT_LINE_WIDTH, 1);

   for(int i = 0; i < 6; i++)
      PlotIndexSetDouble(i, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   g_atr = iATR(Symbol(), Period(), InpAtrPeriod);
   if(g_atr == INVALID_HANDLE) { Print("CRT: ATR error"); return INIT_FAILED; }

   // Auto-detectar big figure según instrumento
   g_big_figure = (InpBigFigure > 0.0) ? InpBigFigure : AutoBigFigure();

   IndicatorSetString(INDICATOR_SHORTNAME, "CRT [" + EnumToString(InpHTF) + "]");
   return INIT_SUCCEEDED;
  }

//==================================================================
//  AUTO BIG FIGURE — detecta el tamaño del "nivel 00" según símbolo
//  Forex 5d: 0.01 | JPY 3d: 1.0 | Gold: 50.0 | Indices: variable
//==================================================================
double AutoBigFigure()
  {
   double price  = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   int    digits = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);

   if(digits >= 4) return 0.01;          // EURUSD, GBPUSD, AUDUSD …
   if(digits == 3) return 1.0;           // USDJPY, EURJPY (3-digit)
   if(digits == 2)
     {
      if(price < 200)   return 1.0;      // USDJPY 2-digit
      if(price < 3000)  return 50.0;     // XAUUSD (Gold) → 00 = 1950, 2000, 2050
      return 500.0;                      // US30 / NAS100 burdo
     }
   if(digits <= 1)
     {
      if(price < 5000)  return 100.0;    // SPX500
      return 1000.0;                     // NAS100, US30
     }
   return 0.01;
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
//  SESSION HELPERS
//==================================================================
bool IsInSession(datetime bar_time, int utc_h_start, int utc_h_end)
  {
   datetime utc = bar_time - InpGMTOffset * 3600;
   MqlDateTime mdt;
   TimeToStruct(utc, mdt);
   double hf = mdt.hour + mdt.min / 60.0;
   if(utc_h_start < utc_h_end)
      return (hf >= utc_h_start && hf < utc_h_end);
   return (hf >= utc_h_start || hf < utc_h_end);
  }

bool IsActiveSession(datetime bar_time)
  {
   if(!InpFilterSession) return true;
   if(InpUseNYKillZone && IsInSession(bar_time, 13, 16)) return true;
   if(InpUseNYSession   && IsInSession(bar_time, 13, 22)) return true;
   if(InpUseLondonKZ    && IsInSession(bar_time,  7, 10)) return true;
   if(InpUseLondon      && IsInSession(bar_time,  8, 17)) return true;
   if(InpUseAsian       && IsInSession(bar_time, 23,  8)) return true;
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
   return "Fuera sesión";
  }

//==================================================================
//  OBJECT HELPERS
//  ObjectDelete() en MQL5 es seguro aunque el objeto no exista.
//  Eliminamos el ObjectFind() previo (era un O(n) innecesario).
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
   int g = (int)(((c >> 8)  & 0xFF) * alpha / 255);
   int b = (int)( (c & 0xFF)        * alpha / 255);
   return (color)((r << 16) | (g << 8) | b);
  }

// Crea objetos SIN ObjectFind previo — más rápido
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

void EntryArrow(string n, datetime t, double price, bool bull, string label_txt)
  {
   ObjectDelete(0, n);
   if(!ObjectCreate(0, n, OBJ_ARROW, 0, t, price)) return;
   ObjectSetInteger(0, n, OBJPROP_ARROWCODE,  bull ? 241 : 242);
   ObjectSetInteger(0, n, OBJPROP_COLOR,      bull ? clrLime : clrRed);
   ObjectSetInteger(0, n, OBJPROP_WIDTH,      InpArrowSize + 1);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN,     false);

   string ln = n + "_L";
   ObjectDelete(0, ln);
   if(!ObjectCreate(0, ln, OBJ_TEXT, 0, t, price)) return;
   ObjectSetString(0,  ln, OBJPROP_TEXT,      "  " + label_txt);
   ObjectSetInteger(0, ln, OBJPROP_COLOR,     bull ? clrLime : clrRed);
   ObjectSetInteger(0, ln, OBJPROP_FONTSIZE,  9);
   ObjectSetString(0,  ln, OBJPROP_FONT,      "Arial Bold");
   ObjectSetInteger(0, ln, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, ln, OBJPROP_HIDDEN,    false);
  }

//==================================================================
//  NÚMEROS REDONDOS — dibujados solo cuando cambia el rango visible
//==================================================================

// Línea horizontal simple de chart (reutiliza HLine pero con ray_right=true)
void RoundLine(string n, double price, color clr, int width, ENUM_LINE_STYLE style,
               string lbl = "")
  {
   if(ObjectFind(0, n) >= 0) return;  // ya existe → no recrear
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
      datetime t_now = TimeCurrent();
      if(!ObjectCreate(0, ln, OBJ_TEXT, 0, t_now, price)) return;
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
   double qtr   = bf * 0.25;

   // Centro de la grilla en el nivel 00 más cercano al precio actual
   double base = MathFloor(price / bf) * bf;

   for(int i = -InpRoundLevels; i <= InpRoundLevels; i++)
     {
      double lvl_00 = NormalizeDouble(base + i * bf, _Digits);

      // — nivel 00 (big figure) —
      string n00 = g_pfx + "RN00_" + DoubleToString(lvl_00, _Digits);
      string lbl_00 = DoubleToString(lvl_00, _Digits) + " [00]";
      RoundLine(n00, lvl_00, InpRound00Color, InpRound00Width, STYLE_SOLID, lbl_00);

      // — nivel 50 (mitad del big figure) —
      if(InpShowHalf)
        {
         double lvl_50 = NormalizeDouble(lvl_00 + bf * 0.50, _Digits);
         string n50 = g_pfx + "RN50_" + DoubleToString(lvl_50, _Digits);
         RoundLine(n50, lvl_50, InpRound50Color, InpRound50Width, STYLE_DASH,
                   DoubleToString(lvl_50, _Digits) + " [50]");
        }

      // — cuartos: 25 y 75 —
      if(InpShowQuarters)
        {
         double lvl_25 = NormalizeDouble(lvl_00 + bf * 0.25, _Digits);
         double lvl_75 = NormalizeDouble(lvl_00 + bf * 0.75, _Digits);
         string n25 = g_pfx + "RN25_" + DoubleToString(lvl_25, _Digits);
         string n75 = g_pfx + "RN75_" + DoubleToString(lvl_75, _Digits);
         RoundLine(n25, lvl_25, InpRoundQtrColor, InpRoundQtrWidth, STYLE_DOT,
                   DoubleToString(lvl_25, _Digits) + " [25]");
         RoundLine(n75, lvl_75, InpRoundQtrColor, InpRoundQtrWidth, STYLE_DOT,
                   DoubleToString(lvl_75, _Digits) + " [75]");
        }
     }
  }

// Devuelve true si 'price' está dentro de la zona de un número redondo
bool NearRoundNumber(double price)
  {
   if(!InpRoundFilter) return true;  // filtro desactivado → siempre true
   double bf   = g_big_figure;
   double zone = bf * InpRoundZonePct;
   double mod  = MathMod(MathAbs(price), bf * 0.25);  // distancia al cuarto más cercano
   return (mod < zone || (bf * 0.25 - mod) < zone);
  }

//==================================================================
//  KEY LEVELS: PDH/PDL, PWH/PWL, PMH/PML
//==================================================================

void KeyHLine(string n, double price, color clr, int width, string lbl)
  {
   // Usa OBJ_HLINE para que se extienda todo el chart
   if(ObjectFind(0, n) >= 0)
     {
      // Ya existe → solo actualizar precio (puede cambiar de día a día)
      ObjectSetDouble(0, n, OBJPROP_PRICE, price);
      if(lbl != "" && ObjectFind(0, n+"_L") >= 0)
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
      datetime t = TimeCurrent();
      if(!ObjectCreate(0, ln, OBJ_TEXT, 0, t, price)) return;
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
   //--- Previous Day High / Low
   if(InpShowPDHL)
     {
      MqlRates d[];
      ArraySetAsSeries(d, true);
      if(CopyRates(Symbol(), PERIOD_D1, 1, 1, d) == 1)
        {
         g_pdh = d[0].high;
         g_pdl = d[0].low;
         KeyHLine(g_pfx+"PDH", g_pdh, InpPDHColor, InpKeyLevelWidth, "PDH");
         KeyHLine(g_pfx+"PDL", g_pdl, InpPDLColor, InpKeyLevelWidth, "PDL");
        }
     }

   //--- Previous Week High / Low
   if(InpShowPWHL)
     {
      MqlRates w[];
      ArraySetAsSeries(w, true);
      if(CopyRates(Symbol(), PERIOD_W1, 1, 1, w) == 1)
        {
         g_pwh = w[0].high;
         g_pwl = w[0].low;
         KeyHLine(g_pfx+"PWH", g_pwh, InpPWHColor, InpKeyLevelWidth, "PWH");
         KeyHLine(g_pfx+"PWL", g_pwl, InpPWLColor, InpKeyLevelWidth, "PWL");
        }
     }

   //--- Previous Month High / Low
   if(InpShowPMHL)
     {
      MqlRates m[];
      ArraySetAsSeries(m, true);
      if(CopyRates(Symbol(), PERIOD_MN1, 1, 1, m) == 1)
        {
         g_pmh = m[0].high;
         g_pml = m[0].low;
         KeyHLine(g_pfx+"PMH", g_pmh, InpPMHColor, InpKeyLevelWidth, "PMH");
         KeyHLine(g_pfx+"PML", g_pml, InpPMLColor, InpKeyLevelWidth, "PML");
        }
     }
  }

//==================================================================
//  SESSION BOXES — dibujadas UNA vez por día (no cada tick)
//==================================================================
void DrawOneDaySession(datetime day_broker, int h_start, int h_end,
                       color clr, string lbl, int alpha)
  {
   // Horas ajustadas al broker: restar GMTOffset para pasar de UTC a local broker
   int h_diff = InpGMTOffset; // broker = UTC + GMTOffset
   datetime s = day_broker + (h_start - h_diff) * 3600;
   datetime e = day_broker + (h_end   - h_diff) * 3600;
   string sn  = g_pfx + "SES_" + lbl + "_" + IntegerToString((int)day_broker);
   if(ObjectFind(0, sn) >= 0) return;  // ya dibujada este día
   Box(sn, s, e, 99999, 0, clr, alpha);
   Txt(sn + "_L", s, 0, lbl, clr, 7);
  }

void DrawSessionBoxes(const datetime &time[], int rates_total)
  {
   if(!InpHighlightSess) return;

   // Sólo escanear los últimos 20 días (~400 barras en H1) para no iterar todo
   int scan_limit = MathMin(rates_total, 500);

   for(int i = scan_limit - 1; i >= 0; i--)
     {
      datetime utc = time[i] - InpGMTOffset * 3600;
      MqlDateTime mdt;
      TimeToStruct(utc, mdt);
      // Start-of-day en hora broker
      datetime day_utc    = utc - mdt.hour * 3600 - mdt.min * 60 - mdt.sec;
      datetime day_broker = day_utc + InpGMTOffset * 3600;

      if(InpUseNYSession)   DrawOneDaySession(day_broker, 13, 22, InpNYColor,      "NY",    InpSessAlpha);
      if(InpUseNYKillZone)  DrawOneDaySession(day_broker, 13, 16, InpNYKZColor,    "NY_KZ", InpSessAlpha + 10);
      if(InpUseLondon)      DrawOneDaySession(day_broker,  8, 17, InpLondonColor,  "LON",   InpSessAlpha);
      if(InpUseLondonKZ)    DrawOneDaySession(day_broker,  7, 10, InpLondonKZColor,"LON_KZ",InpSessAlpha + 10);
      if(InpUseAsian)       DrawOneDaySession(day_broker, 23, 32, InpAsianColor,   "ASIA",  InpSessAlpha);
     }
  }

//==================================================================
//  DASHBOARD — crea labels una sola vez, luego solo actualiza texto
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

void UpdateDash(int bull, int bear, int total, string last_sig, color lc, string sess)
  {
   if(!InpDash) return;
   string p = g_pfx + "D_";

   // Número redondo más cercano al precio actual
   double price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double bf    = g_big_figure;
   double nearest_00 = MathRound(price / bf) * bf;
   double dist_pips  = MathAbs(price - nearest_00) / _Point / 10.0;

   string pdh_s = (g_pdh > 0) ? DoubleToString(g_pdh, _Digits) : "---";
   string pdl_s = (g_pdl > 0) ? DoubleToString(g_pdl, _Digits) : "---";
   string pwh_s = (g_pwh > 0) ? DoubleToString(g_pwh, _Digits) : "---";
   string pwl_s = (g_pwl > 0) ? DoubleToString(g_pwl, _Digits) : "---";
   string rnd_s = DoubleToString(nearest_00, _Digits)
                  + " (" + DoubleToString(dist_pips, 1) + "p)";

   Dash(p+"r0",  "╔═══════════════════════════╗",                               clrGray,   0);
   Dash(p+"r1",  "║   CRT  Candle Range Theory   ║",                            clrGold,   1);
   Dash(p+"r2",  "║  HTF : " + StringFormat("%-21s", EnumToString(InpHTF)) + "║",  clrSilver, 2);
   Dash(p+"r3",  "╠═══════════════════════════╣",                               clrGray,   3);
   Dash(p+"r4",  "║  Bull: " + StringFormat("%-4d",bull) + "  Bear: " + StringFormat("%-15d",bear) + "║", clrSilver, 4);
   Dash(p+"r5",  "║  Última señal : " + StringFormat("%-12s", last_sig) +       "║",  lc,        5);
   Dash(p+"r6",  "╠═══════════════════════════╣",                               clrGray,   6);
   Dash(p+"r7",  "║  Sesión activa: " + StringFormat("%-12s", sess) +           "║",  clrAqua,   7);
   Dash(p+"r8",  "╠═══════════════════════════╣",                               clrGray,   8);
   Dash(p+"r9",  "║  PDH: " + StringFormat("%-22s", pdh_s) +                    "║",  InpPDHColor, 9);
   Dash(p+"r10", "║  PDL: " + StringFormat("%-22s", pdl_s) +                    "║",  InpPDLColor, 10);
   Dash(p+"r11", "║  PWH: " + StringFormat("%-22s", pwh_s) +                    "║",  InpPWHColor, 11);
   Dash(p+"r12", "║  PWL: " + StringFormat("%-22s", pwl_s) +                    "║",  InpPWLColor, 12);
   Dash(p+"r13", "╠═══════════════════════════╣",                               clrGray,   13);
   Dash(p+"r14", "║  RN00 cercano: " + StringFormat("%-13s", rnd_s) +           "║",  InpRound00Color, 14);
   Dash(p+"r15", "╚═══════════════════════════╝",                               clrGray,   15);
  }

//==================================================================
//  DIBUJAR SETUP VISUAL (solo si no existe aún en el chart)
//  Devuelve true si se dibujó nuevo, false si ya existía
//==================================================================
bool DrawSetup(string b, datetime a_t1, datetime a_t2, datetime m_t1, datetime m_t2,
               double a_hi, double a_lo, double m_hi, double m_lo,
               double mid, double sl_p, double cur_atr,
               bool bull)
  {
   // Guard: si la caja ya existe, NO redibujar (evita trabajo por tick)
   if(ObjectFind(0, b + "_ab") >= 0) return false;

   color box_c  = bull ? InpBullColor : InpBearColor;
   double entry = bull ? a_lo : a_hi;
   double target = bull ? a_hi : a_lo;
   double entry_offset = bull ? cur_atr * 0.02 : cur_atr * 0.03;
   double entry_sign   = bull ? 1.0 : 1.0;
   ENUM_LINE_STYLE entry_style = STYLE_SOLID;

   if(InpShowAnchorBox)
      Box(b+"_ab", a_t1, a_t2, a_hi, a_lo, box_c, InpBoxAlpha);
   if(InpShowManipBox)
      Box(b+"_mb", m_t1, m_t2, m_hi, m_lo, box_c, InpBoxAlpha - 12);
   if(InpShow50Line)
     {
      HLine(b+"_mid", a_t1, m_t2, mid, clrGold, 1, STYLE_DASH);
      Txt(b+"_midL", a_t1, mid + cur_atr * 0.03, " EQ 50%", clrGold, 7);
     }

   // Línea de entrada
   HLine(b+"_entry", m_t1, m_t2, entry, bull ? clrLime : clrRed, 2, entry_style);
   Txt(b+"_entL", m_t1, entry + (bull ? cur_atr*0.02 : cur_atr*0.03),
       " ENTRY: " + DoubleToString(entry, _Digits),
       bull ? clrLime : clrRed, 8);

   // SL
   if(InpShowSL)
     {
      HLine(b+"_sl", m_t1, m_t2, sl_p, InpSLColor, 1, STYLE_DOT);
      Txt(b+"_slL", m_t1, sl_p + (bull ? -cur_atr*0.04 : cur_atr*0.03),
          " SL: " + DoubleToString(sl_p, _Digits), InpSLColor, 7);
     }
   // TP1
   if(InpShowTP1)
     {
      HLine(b+"_tp1", m_t1, m_t2, mid, InpTP1Color, 1, STYLE_DASH);
      Txt(b+"_tp1L", m_t1, mid + (bull ? cur_atr*0.03 : -cur_atr*0.05),
          " TP1: " + DoubleToString(mid, _Digits), InpTP1Color, 7);
     }
   // TP2
   if(InpShowTP2)
     {
      HLine(b+"_tp2", m_t1, m_t2, target, InpTP2Color, 2, STYLE_DOT);
      Txt(b+"_tp2L", m_t1, target + (bull ? cur_atr*0.03 : -cur_atr*0.05),
          " TP2: " + DoubleToString(target, _Digits), InpTP2Color, 8);
     }
   return true;
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

   //--- Arrays como serie (índice 0 = barra más reciente)
   ArraySetAsSeries(time,  true);
   ArraySetAsSeries(open,  true);
   ArraySetAsSeries(high,  true);
   ArraySetAsSeries(low,   true);
   ArraySetAsSeries(close, true);

   //==============================================================
   //  GUARD DE NUEVA BARRA
   //  El trabajo pesado SOLO se ejecuta cuando abre una nueva vela.
   //  En ticks intermedios → solo actualizar dashboard y salir.
   //==============================================================
   static datetime s_last_ltf = 0;
   bool new_bar = (time[0] != s_last_ltf);

   if(!new_bar && prev_calculated > 0)
     {
      // Tick entre velas: solo refrescar dashboard (muy barato)
      UpdateDash(0, 0, g_htf_cnt - 2, "---", clrSilver, CurrentSessionName());
      return rates_total;
     }
   s_last_ltf = time[0];

   //--- Reset en cálculo completo
   if(prev_calculated == 0)
     {
      ArrayInitialize(BuyBuf,       EMPTY_VALUE);
      ArrayInitialize(SellBuf,      EMPTY_VALUE);
      ArrayInitialize(ManipLowBuf,  EMPTY_VALUE);
      ArrayInitialize(ManipHighBuf, EMPTY_VALUE);
      ArrayInitialize(TP1Buf,       EMPTY_VALUE);
      ArrayInitialize(TP2Buf,       EMPTY_VALUE);
      CleanObjects();
      g_last_htf_t    = 0;
      g_last_sess_day = 0;
      g_last_kl_day   = 0;
      g_last_kl_week  = 0;
      g_big_figure    = (InpBigFigure > 0.0) ? InpBigFigure : AutoBigFigure();
     }

   //--- ATR: solo copiar los barras necesarias (no todo rates_total)
   double atr[];
   ArraySetAsSeries(atr, true);
   int atr_need = MathMin(InpLookback * 5 + 30, rates_total);
   if(CopyBuffer(g_atr, 0, 0, atr_need, atr) <= 0) return 0;
   int atr_size = ArraySize(atr);

   //--- HTF: solo refrescar cuando la barra HTF cambia
   datetime cur_htf_open = iTime(Symbol(), InpHTF, 0);
   if(cur_htf_open != g_last_htf_t || prev_calculated == 0)
     {
      g_htf_cnt = CopyRates(Symbol(), InpHTF, 0, InpLookback + 3, g_htf);
      ArraySetAsSeries(g_htf, true);
      g_last_htf_t = cur_htf_open;
     }
   if(g_htf_cnt < 3) return 0;

   //--- Cajas de sesión + Números redondos + Key levels: actualizados por día/semana
   datetime cur_utc = TimeCurrent() - InpGMTOffset * 3600;
   MqlDateTime mdt_now;
   TimeToStruct(cur_utc, mdt_now);
   datetime cur_day  = (datetime)(cur_utc - mdt_now.hour*3600 - mdt_now.min*60 - mdt_now.sec)
                       + InpGMTOffset * 3600;

   // Semana: lunes de la semana actual
   int day_of_week   = mdt_now.day_of_week;
   datetime cur_week = cur_day - (datetime)((day_of_week == 0 ? 6 : day_of_week - 1) * 86400);

   if(cur_day != g_last_sess_day || prev_calculated == 0)
     {
      DrawSessionBoxes(time, rates_total);
      DrawRoundNumbers();    // nuevos niveles si el precio se movió mucho
      DrawKeyLevels();       // PDH/PDL y PMH/PML refrescados cada día
      g_last_sess_day = cur_day;
      g_last_kl_day   = cur_day;
     }

   if(cur_week != g_last_kl_week || prev_calculated == 0)
     {
      DrawKeyLevels();       // PWH/PWL refrescado cada semana
      g_last_kl_week = cur_week;
     }

   double pip = InpArrowPips * _Point;
   int bull_cnt = 0, bear_cnt = 0;
   string last_sig = "ninguna";
   color  last_clr = clrSilver;

   //=================================================================
   //  SCAN HTF CANDLES
   //  g_htf[0] = vela en formación (skip)
   //  g_htf[h]   = anchor (h >= 2)
   //  g_htf[h-1] = manipulación
   //=================================================================
   for(int h = 2; h < g_htf_cnt - 1; h++)
     {
      double a_hi   = g_htf[h].high,  a_lo  = g_htf[h].low;
      double a_op   = g_htf[h].open,  a_cl  = g_htf[h].close;
      double rng    = a_hi - a_lo;
      datetime a_t1 = g_htf[h].time,  a_t2  = g_htf[h-1].time;

      double m_hi   = g_htf[h-1].high, m_lo  = g_htf[h-1].low;
      double m_cl   = g_htf[h-1].close;
      datetime m_t1 = g_htf[h-1].time;
      datetime m_t2 = (h >= 2) ? g_htf[h-2].time : time[0];

      // ATR: iBarShift cacheado una sola vez por candle anchor
      int a_bar = iBarShift(Symbol(), Period(), a_t1, false);
      if(a_bar < 0 || a_bar >= rates_total) continue;
      double cur_atr = atr[MathMin(a_bar, atr_size - 1)];
      if(cur_atr <= 0.0) continue;

      if(rng < InpMinATR * cur_atr) continue;
      if(rng > InpMaxATR * cur_atr) continue;

      double mid = a_lo + rng * 0.5;
      string b   = g_pfx + TimeToString(a_t1, TIME_DATE | TIME_MINUTES);
      StringReplace(b, ":", "");
      StringReplace(b, " ", "_");

      if(InpShowHTFOverlay)
        {
         color oc = (a_cl >= a_op) ? C'0,55,0' : C'55,0,0';
         // Solo dibujar overlay si no existe
         if(ObjectFind(0, b+"_htf") < 0)
            Box(b+"_htf", a_t1, a_t2, a_hi, a_lo, oc, InpHTFAlpha);
        }

      // iBarShift para la vela de manipulación (cacheado)
      int mb_s = iBarShift(Symbol(), Period(), m_t1, false);
      int mb_e = iBarShift(Symbol(), Period(), m_t2, false);
      mb_s = MathMax(0, MathMin(mb_s, rates_total - 1));
      mb_e = MathMax(0, MathMin(mb_e, rates_total - 1));

      //==============================================================
      // BULLISH CRT ↑
      //==============================================================
      bool b_sweep = (m_lo < a_lo);
      bool b_reent = InpReqClose ? (m_cl > a_lo) : b_sweep;

      if(b_sweep && b_reent)
        {
         bull_cnt++;
         last_sig = "BUY CRT";
         last_clr = clrLime;

         // Barra con el low más bajo (sweep real)
         int sw_bar = mb_s;
         double sw_lo = low[mb_s];
         for(int b2 = mb_e; b2 <= mb_s; b2++)
            if(low[b2] < sw_lo) { sw_lo = low[b2]; sw_bar = b2; }

         // Primera barra que cierra de vuelta sobre anchor_low
         int sig_bar = mb_e;
         for(int b2 = sw_bar; b2 >= mb_e; b2--)
            if(close[b2] > a_lo) { sig_bar = b2; break; }

         double sl_p = sw_lo - InpSLBuffer * cur_atr;

         // Dibujar setup visual (solo si es nuevo)
         DrawSetup(b, a_t1, a_t2, m_t1, m_t2,
                   a_hi, a_lo, m_hi, m_lo,
                   mid, sl_p, cur_atr, true);

         // Marcador sweep
         if(InpShowManip && ManipLowBuf[sw_bar] == EMPTY_VALUE)
            ManipLowBuf[sw_bar] = low[sw_bar] - pip;

         // Flecha entrada y buffers (sesión + filtro número redondo)
         if(IsActiveSession(time[sig_bar]) && NearRoundNumber(a_lo))
           {
            if(InpShowBuy && BuyBuf[sig_bar] == EMPTY_VALUE)
              {
               BuyBuf[sig_bar] = a_lo - pip * 2;
               EntryArrow(b+"_buy", time[sig_bar], a_lo - pip,
                          true, "BUY  @ " + DoubleToString(a_lo, _Digits));
              }
            if(InpShowTP1 && TP1Buf[sig_bar] == EMPTY_VALUE) TP1Buf[sig_bar] = mid;
            if(InpShowTP2 && TP2Buf[sig_bar] == EMPTY_VALUE) TP2Buf[sig_bar] = a_hi;

            if(InpAlerts && sig_bar <= 1 && TimeCurrent() != g_last_alert)
              {
               g_last_alert = TimeCurrent();
               string msg = "CRT BUY  " + Symbol() + " [" + EnumToString(InpHTF) + "]"
                            + "  Entry:" + DoubleToString(a_lo, _Digits)
                            + "  TP:" + DoubleToString(a_hi, _Digits)
                            + "  SL:" + DoubleToString(sl_p, _Digits);
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
         bear_cnt++;
         last_sig = "SELL CRT";
         last_clr = clrRed;

         int sw_bar = mb_s;
         double sw_hi = high[mb_s];
         for(int b2 = mb_e; b2 <= mb_s; b2++)
            if(high[b2] > sw_hi) { sw_hi = high[b2]; sw_bar = b2; }

         int sig_bar = mb_e;
         for(int b2 = sw_bar; b2 >= mb_e; b2--)
            if(close[b2] < a_hi) { sig_bar = b2; break; }

         double sl_p = sw_hi + InpSLBuffer * cur_atr;

         DrawSetup(b, a_t1, a_t2, m_t1, m_t2,
                   a_hi, a_lo, m_hi, m_lo,
                   mid, sl_p, cur_atr, false);

         if(InpShowManip && ManipHighBuf[sw_bar] == EMPTY_VALUE)
            ManipHighBuf[sw_bar] = high[sw_bar] + pip;

         if(IsActiveSession(time[sig_bar]) && NearRoundNumber(a_hi))
           {
            if(InpShowSell && SellBuf[sig_bar] == EMPTY_VALUE)
              {
               SellBuf[sig_bar] = a_hi + pip * 2;
               EntryArrow(b+"_sell", time[sig_bar], a_hi + pip,
                          false, "SELL @ " + DoubleToString(a_hi, _Digits));
              }
            if(InpShowTP1 && TP1Buf[sig_bar] == EMPTY_VALUE) TP1Buf[sig_bar] = mid;
            if(InpShowTP2 && TP2Buf[sig_bar] == EMPTY_VALUE) TP2Buf[sig_bar] = a_lo;

            if(InpAlerts && sig_bar <= 1 && TimeCurrent() != g_last_alert)
              {
               g_last_alert = TimeCurrent();
               string msg = "CRT SELL " + Symbol() + " [" + EnumToString(InpHTF) + "]"
                            + "  Entry:" + DoubleToString(a_hi, _Digits)
                            + "  TP:" + DoubleToString(a_lo, _Digits)
                            + "  SL:" + DoubleToString(sl_p, _Digits);
               Alert(msg);
               if(InpPushNotif) SendNotification(msg);
               PlaySound("alert.wav");
              }
           }
        }
     }

   UpdateDash(bull_cnt, bear_cnt, g_htf_cnt - 2, last_sig, last_clr, CurrentSessionName());
   // ChartRedraw() eliminado — MT5 redibuja automáticamente al cambiar buffers/objetos
   return rates_total;
  }
//+------------------------------------------------------------------+
