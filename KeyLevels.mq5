//+------------------------------------------------------------------+
//|                                                   KeyLevels.mq5  |
//|                           Niveles Clave de Precio               |
//|                                                                  |
//|  Dibuja en el chart:                                            |
//|    • Números redondos  00 / 25 / 50 / 75                       |
//|    • PDH / PDL  (Previous Day  High / Low)                     |
//|    • PWH / PWL  (Previous Week High / Low)                     |
//|    • PMH / PML  (Previous Month High / Low)                    |
//|    • Apertura del día actual (ODO)                              |
//|    • Apertura de la semana actual (ODW)                        |
//|    • Rango de la sesión Asia (Asian High / Low)                |
//+------------------------------------------------------------------+
#property copyright   "KeyLevels Indicator"
#property version     "1.00"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//==================================================================
//  INPUTS
//==================================================================

input group "=== Números Redondos ==="
input bool   InpShowRound     = true;   // Mostrar niveles redondos
input double InpBigFigure     = 0.0;    // Big figure (0 = auto según instrumento)
input bool   InpShow00        = true;   // Nivel 00  (big figure)
input bool   InpShow50        = true;   // Nivel 50  (mitad)
input bool   InpShow25        = true;   // Niveles 25 y 75 (cuartos)
input int    InpRoundCount    = 12;     // Cuántos niveles arriba y abajo mostrar
input color  InpColor00       = C'220,220,0';   // Color nivel 00
input color  InpColor50       = C'160,160,0';   // Color nivel 50
input color  InpColor25       = C'90,90,0';     // Color cuartos 25/75
input int    InpWidth00       = 2;              // Grosor nivel 00
input int    InpWidth50       = 1;              // Grosor nivel 50
input int    InpWidth25       = 1;              // Grosor cuartos

input group "=== Previous Day ==="
input bool   InpShowPDH       = true;           // Previous Day High
input bool   InpShowPDL       = true;           // Previous Day Low
input bool   InpShowODO       = true;           // Open of current Day
input color  InpColorPDH      = C'0,200,255';   // Color PDH
input color  InpColorPDL      = C'255,100,0';   // Color PDL
input color  InpColorODO      = C'200,200,255'; // Color Open Day

input group "=== Previous Week ==="
input bool   InpShowPWH       = true;           // Previous Week High
input bool   InpShowPWL       = true;           // Previous Week Low
input bool   InpShowODW       = true;           // Open of current Week
input color  InpColorPWH      = C'0,150,220';   // Color PWH
input color  InpColorPWL      = C'220,70,0';    // Color PWL
input color  InpColorODW      = C'180,180,220'; // Color Open Week

input group "=== Previous Month ==="
input bool   InpShowPMH       = false;          // Previous Month High
input bool   InpShowPML       = false;          // Previous Month Low
input bool   InpShowODM       = false;          // Open of current Month
input color  InpColorPMH      = C'0,100,180';   // Color PMH
input color  InpColorPML      = C'180,50,0';    // Color PML
input color  InpColorODM      = C'160,160,200'; // Color Open Month

input group "=== Sesión Asia (Rango) ==="
input bool   InpShowAsianHL   = true;   // Rango alto/bajo de sesión Asia
input int    InpGMTOffset     = 0;      // GMT offset del broker
input color  InpColorAsianH   = C'100,80,0';  // Asian High color
input color  InpColorAsianL   = C'80,60,0';   // Asian Low color

input group "=== Visual ==="
input int    InpLevelWidth    = 2;     // Grosor de todas las líneas de niveles
input bool   InpShowLabels    = true;  // Mostrar etiquetas con precio
input int    InpLabelSize     = 8;     // Tamaño fuente etiquetas
input bool   InpRayRight      = true;  // Extender líneas a la derecha

//==================================================================
//  GLOBALS
//==================================================================
string   g_pfx;
double   g_big_figure = 0;

datetime g_last_day   = 0;
datetime g_last_week  = 0;
datetime g_last_month = 0;

//==================================================================
//  INIT
//==================================================================
int OnInit()
  {
   g_pfx = "KL_" + Symbol() + "_";
   g_big_figure = (InpBigFigure > 0.0) ? InpBigFigure : AutoBigFigure();
   IndicatorSetString(INDICATOR_SHORTNAME, "Key Levels");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   CleanObjects();
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
   if(digits <= 1) return (price < 5000) ? 100.0 : 1000.0;
   return 0.01;
  }

//==================================================================
//  HELPERS
//==================================================================
void CleanObjects()
  {
   for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--)
     {
      string n = ObjectName(0, i, 0, -1);
      if(StringFind(n, g_pfx) == 0)
         ObjectDelete(0, n);
     }
  }

// Dibuja una línea horizontal extendida (OBJ_HLINE = se extiende sola)
void DrawLevel(string name, double price, color clr, int width,
               ENUM_LINE_STYLE style, string lbl)
  {
   // Si ya existe, solo actualizar precio
   if(ObjectFind(0, name) >= 0)
     {
      ObjectSetDouble(0, name, OBJPROP_PRICE, price);
      if(InpShowLabels && ObjectFind(0, name+"_L") >= 0)
        {
         ObjectSetDouble(0, name+"_L", OBJPROP_PRICE, price);
         ObjectSetString(0, name+"_L", OBJPROP_TEXT, " " + lbl + "  " + DoubleToString(price, _Digits));
        }
      return;
     }

   // Crear nueva
   if(!ObjectCreate(0, name, OBJ_HLINE, 0, 0, price)) return;
   ObjectSetInteger(0, name, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH,      width);
   ObjectSetInteger(0, name, OBJPROP_STYLE,      style);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,     false);
   ObjectSetInteger(0, name, OBJPROP_TOOLTIP,    false);

   // Etiqueta de texto
   if(InpShowLabels)
     {
      string ln = name + "_L";
      datetime t_label = TimeCurrent();
      if(!ObjectCreate(0, ln, OBJ_TEXT, 0, t_label, price)) return;
      ObjectSetString(0,  ln, OBJPROP_TEXT,       " " + lbl + "  " + DoubleToString(price, _Digits));
      ObjectSetInteger(0, ln, OBJPROP_COLOR,      clr);
      ObjectSetInteger(0, ln, OBJPROP_FONTSIZE,   InpLabelSize);
      ObjectSetString(0,  ln, OBJPROP_FONT,       "Arial Bold");
      ObjectSetInteger(0, ln, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, ln, OBJPROP_HIDDEN,     false);
     }
  }

// Dibuja niveles redondos (OBJ_HLINE, se crean solo una vez con guard)
void DrawRoundLine(string name, double price, color clr, int width,
                   ENUM_LINE_STYLE style, string lbl)
  {
   if(ObjectFind(0, name) >= 0) return;  // ya existe → no recrear
   DrawLevel(name, price, clr, width, style, lbl);
  }

//==================================================================
//  NÚMEROS REDONDOS
//==================================================================
void DrawRoundNumbers()
  {
   if(!InpShowRound) return;
   double price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double bf    = g_big_figure;
   double base  = MathFloor(price / bf) * bf;

   for(int i = -InpRoundCount; i <= InpRoundCount; i++)
     {
      double l00 = NormalizeDouble(base + i * bf, _Digits);

      if(InpShow00)
        {
         string n = g_pfx + "RN_00_" + DoubleToString(l00, _Digits);
         DrawRoundLine(n, l00, InpColor00, InpWidth00, STYLE_SOLID, "[00]");
        }

      if(InpShow50)
        {
         double l50 = NormalizeDouble(l00 + bf * 0.50, _Digits);
         string n   = g_pfx + "RN_50_" + DoubleToString(l50, _Digits);
         DrawRoundLine(n, l50, InpColor50, InpWidth50, STYLE_DASH, "[50]");
        }

      if(InpShow25)
        {
         double l25 = NormalizeDouble(l00 + bf * 0.25, _Digits);
         double l75 = NormalizeDouble(l00 + bf * 0.75, _Digits);
         DrawRoundLine(g_pfx+"RN_25_"+DoubleToString(l25,_Digits),
                       l25, InpColor25, InpWidth25, STYLE_DOT, "[25]");
         DrawRoundLine(g_pfx+"RN_75_"+DoubleToString(l75,_Digits),
                       l75, InpColor25, InpWidth25, STYLE_DOT, "[75]");
        }
     }
  }

//==================================================================
//  NIVELES CLAVE POR PERÍODO
//==================================================================
void DrawPeriodLevels()
  {
   //--- DAILY
   MqlRates d1[]; ArraySetAsSeries(d1, true);

   if((InpShowPDH || InpShowPDL) && CopyRates(Symbol(), PERIOD_D1, 1, 1, d1) == 1)
     {
      if(InpShowPDH) DrawLevel(g_pfx+"PDH", d1[0].high, InpColorPDH, InpLevelWidth, STYLE_DASH, "PDH");
      if(InpShowPDL) DrawLevel(g_pfx+"PDL", d1[0].low,  InpColorPDL, InpLevelWidth, STYLE_DASH, "PDL");
     }

   if(InpShowODO && CopyRates(Symbol(), PERIOD_D1, 0, 1, d1) == 1)
      DrawLevel(g_pfx+"ODO", d1[0].open, InpColorODO, 1, STYLE_DOT, "ODO");

   //--- WEEKLY
   MqlRates w1[]; ArraySetAsSeries(w1, true);

   if((InpShowPWH || InpShowPWL) && CopyRates(Symbol(), PERIOD_W1, 1, 1, w1) == 1)
     {
      if(InpShowPWH) DrawLevel(g_pfx+"PWH", w1[0].high, InpColorPWH, InpLevelWidth, STYLE_DASH, "PWH");
      if(InpShowPWL) DrawLevel(g_pfx+"PWL", w1[0].low,  InpColorPWL, InpLevelWidth, STYLE_DASH, "PWL");
     }

   if(InpShowODW && CopyRates(Symbol(), PERIOD_W1, 0, 1, w1) == 1)
      DrawLevel(g_pfx+"ODW", w1[0].open, InpColorODW, 1, STYLE_DOT, "ODW");

   //--- MONTHLY
   MqlRates mn[]; ArraySetAsSeries(mn, true);

   if((InpShowPMH || InpShowPML) && CopyRates(Symbol(), PERIOD_MN1, 1, 1, mn) == 1)
     {
      if(InpShowPMH) DrawLevel(g_pfx+"PMH", mn[0].high, InpColorPMH, InpLevelWidth, STYLE_DASH, "PMH");
      if(InpShowPML) DrawLevel(g_pfx+"PML", mn[0].low,  InpColorPML, InpLevelWidth, STYLE_DASH, "PML");
     }

   if(InpShowODM && CopyRates(Symbol(), PERIOD_MN1, 0, 1, mn) == 1)
      DrawLevel(g_pfx+"ODM", mn[0].open, InpColorODM, 1, STYLE_DOT, "ODM");
  }

//==================================================================
//  RANGO SESIÓN ASIA  (23:00 – 08:00 UTC aprox)
//  Busca el high y low de las últimas X horas correspondientes
//  a la sesión asiática del día actual
//==================================================================
void DrawAsianRange()
  {
   if(!InpShowAsianHL) return;

   // Calcular inicio/fin de sesión Asia de HOY en hora del broker
   datetime now_utc  = TimeCurrent() - InpGMTOffset * 3600;
   MqlDateTime mdt; TimeToStruct(now_utc, mdt);
   datetime today_utc = now_utc - mdt.hour*3600 - mdt.min*60 - mdt.sec;

   // Asia: 23:00 UTC ayer → 08:00 UTC hoy
   datetime asia_start = today_utc - 1*3600 + InpGMTOffset*3600;   // 23:00 UTC-ajustado
   datetime asia_end   = today_utc + 8*3600 + InpGMTOffset*3600;   // 08:00 UTC-ajustado

   if(TimeCurrent() < asia_end) return;  // sesión aún no terminó → no dibujar

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   // Copiar barras del período H1 para el rango asiático
   int copied = CopyRates(Symbol(), PERIOD_H1, asia_start, asia_end, bars);
   if(copied <= 0) return;

   double asian_hi = 0, asian_lo = DBL_MAX;
   for(int i = 0; i < copied; i++)
     {
      if(bars[i].high > asian_hi) asian_hi = bars[i].high;
      if(bars[i].low  < asian_lo) asian_lo = bars[i].low;
     }
   if(asian_hi <= 0 || asian_lo >= DBL_MAX) return;

   DrawLevel(g_pfx+"ASIAH", asian_hi, InpColorAsianH, InpLevelWidth, STYLE_DASH, "Asian H");
   DrawLevel(g_pfx+"ASIAL", asian_lo, InpColorAsianL, InpLevelWidth, STYLE_DASH, "Asian L");
  }

//==================================================================
//  CALCULATE — guard de nueva vela, trabajo por períodos
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
   if(rates_total < 2) return 0;

   ArraySetAsSeries(time, true);

   //--- Guard: ejecutar solo en nueva barra
   static datetime s_last = 0;
   if(time[0] == s_last && prev_calculated > 0) return rates_total;
   s_last = time[0];

   if(prev_calculated == 0)
     {
      CleanObjects();
      g_last_day   = 0;
      g_last_week  = 0;
      g_last_month = 0;
      g_big_figure = (InpBigFigure > 0.0) ? InpBigFigure : AutoBigFigure();
     }

   //--- Detectar cambio de día / semana / mes
   datetime now_utc = TimeCurrent() - InpGMTOffset * 3600;
   MqlDateTime mdt; TimeToStruct(now_utc, mdt);

   datetime cur_day = (datetime)(now_utc - mdt.hour*3600 - mdt.min*60 - mdt.sec);

   int dow = mdt.day_of_week;
   datetime cur_week  = cur_day - (datetime)((dow == 0 ? 6 : dow - 1) * 86400);
   datetime cur_month = (datetime)(now_utc - (mdt.day - 1)*86400 - mdt.hour*3600
                                   - mdt.min*60 - mdt.sec);

   //--- Niveles redondos: refresco diario (precio puede haberse movido)
   if(cur_day != g_last_day || prev_calculated == 0)
     {
      DrawRoundNumbers();
      DrawPeriodLevels();
      DrawAsianRange();
      g_last_day = cur_day;
     }

   //--- Niveles semanales/mensuales
   if(cur_week != g_last_week || prev_calculated == 0)
     {
      DrawPeriodLevels();
      g_last_week = cur_week;
     }

   if(cur_month != g_last_month || prev_calculated == 0)
     {
      DrawPeriodLevels();
      g_last_month = cur_month;
     }

   return rates_total;
  }
//+------------------------------------------------------------------+
