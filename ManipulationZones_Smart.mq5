//+------------------------------------------------------------------+
//|              ManipulationZones_Smart.mq5                          |
//|    Zonas de Manipulacion Inteligente + Panel Tendencia MTF        |
//|                                                                    |
//|  ZONAS (hora Nueva York):                                          |
//|    Z1: 3:30 - 4:00 AM                                             |
//|    Z2: 8:30 - 9:00 AM                                             |
//|    Z3: 13:30 - 14:00                                              |
//|    Z4: 20:30 - 21:00                                              |
//|                                                                    |
//|  Para XM: InpServerToNY = 7  (normalmente constante todo el año)  |
//+------------------------------------------------------------------+
#property copyright "ManipulationZones_Smart v1.1"
#property version   "1.10"
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   3
#property description "Zonas de manipulacion H/L/50% + EMAs 20/50/150 + Panel MTF"

#property indicator_label1  "EMA 20"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_label2  "EMA 50"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrange
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

#property indicator_label3  "EMA 150"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrMagenta
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

//============================================================
// ESTRUCTURAS
//============================================================

struct ZoneWindow {
   int startMin;
   int endMin;
};

struct ZoneRecord {
   datetime keyTime;
   double   hi;
   double   lo;
   int      zIdx;
};

//============================================================
// INPUTS
//============================================================

input group "=== HORARIO ==="
input int    InpServerToNY    = 7;    // Diferencia Servidor->NY (horas). XM = 7

input group "=== ACTIVAR ZONAS ==="
input bool   InpEnableZone1   = true; // Zona 1: 3:30-4:00 AM (NY)
input bool   InpEnableZone2   = true; // Zona 2: 8:30-9:00 AM (NY)
input bool   InpEnableZone3   = true; // Zona 3: 13:30-14:00 (NY)
input bool   InpEnableZone4   = true; // Zona 4: 20:30-21:00 (NY)
input int    InpMaxDays       = 10;   // Dias hacia atras

input group "=== ZONA 1 | 3:30-4:00 AM ==="
input color  Z1H  = clrDodgerBlue;   // High
input color  Z1L  = clrRed;          // Low
input color  Z1M  = clrYellow;       // 50%
input int    Z1W  = 1;               // Grosor

input group "=== ZONA 2 | 8:30-9:00 AM ==="
input color  Z2H  = clrLimeGreen;
input color  Z2L  = clrOrangeRed;
input color  Z2M  = clrGold;
input int    Z2W  = 1;

input group "=== ZONA 3 | 13:30-14:00 ==="
input color  Z3H  = clrCyan;
input color  Z3L  = clrMagenta;
input color  Z3M  = clrOrange;
input int    Z3W  = 1;

input group "=== ZONA 4 | 20:30-21:00 ==="
input color  Z4H  = clrViolet;
input color  Z4L  = clrPink;
input color  Z4M  = clrKhaki;
input int    Z4W  = 1;

input group "=== ESTILO DE LINEAS ==="
input ENUM_LINE_STYLE HighLowStyle = STYLE_SOLID; // Estilo High / Low
input ENUM_LINE_STYLE MidStyle     = STYLE_DOT;   // Estilo 50%

input group "=== MEDIAS MOVILES (EN GRAFICO) ==="
input int    InpEMA1Period = 20;          // Periodo EMA 1 (rapida)
input int    InpEMA2Period = 50;          // Periodo EMA 2 (media)
input int    InpEMA3Period = 150;         // Periodo EMA 3 (lenta)
input color  InpEMA1Color  = clrDodgerBlue;
input color  InpEMA2Color  = clrOrange;
input color  InpEMA3Color  = clrMagenta;
input bool   InpShowEMA1   = true;        // Mostrar EMA 1 al inicio
input bool   InpShowEMA2   = true;        // Mostrar EMA 2 al inicio
input bool   InpShowEMA3   = true;        // Mostrar EMA 3 al inicio

input group "=== TENDENCIA MTF ==="
input bool   InpAlerts    = true;  // Alertas pop-up al cambiar tendencia
input bool   InpPush      = false; // Notificacion push al movil

input group "=== PANEL ==="
input int    InpPX  = 15;             // Panel X
input int    InpPY  = 30;             // Panel Y
input int    InpFS  = 9;              // Tamano fuente
input color  InpBG  = C'10,15,30';   // Color fondo
input color  InpBRD = C'40,80,180';  // Color borde

//============================================================
// GLOBALES
//============================================================

const string PFX = "MZ_";

bool         g_zOn[4];
ZoneWindow   g_zw[4];

// EMAs visibles en grafico (timeframe actual)
double       g_bufE1[];
double       g_bufE2[];
double       g_bufE3[];
int          g_hE1 = INVALID_HANDLE;
int          g_hE2 = INVALID_HANDLE;
int          g_hE3 = INVALID_HANDLE;
bool         g_emaOn[3];

// EMAs para calculo de tendencia multi-TF (no se dibujan)
int g_hFM1 = INVALID_HANDLE, g_hSM1 = INVALID_HANDLE;
int g_hFM2 = INVALID_HANDLE, g_hSM2 = INVALID_HANDLE;
int g_hFM5 = INVALID_HANDLE, g_hSM5 = INVALID_HANDLE;
int g_hFH1 = INVALID_HANDLE, g_hSH1 = INVALID_HANDLE;
int g_hFH4 = INVALID_HANDLE, g_hSH4 = INVALID_HANDLE;

int g_prevTrend[4]; // [0]=M1 [1]=M2 [2]=H1 [3]=H4

//============================================================
// INIT / DEINIT
//============================================================

int OnInit()
{
   g_zOn[0] = InpEnableZone1;
   g_zOn[1] = InpEnableZone2;
   g_zOn[2] = InpEnableZone3;
   g_zOn[3] = InpEnableZone4;

   g_zw[0].startMin = 3*60+30;  g_zw[0].endMin = 4*60;
   g_zw[1].startMin = 8*60+30;  g_zw[1].endMin = 9*60;
   g_zw[2].startMin = 13*60+30; g_zw[2].endMin = 14*60;
   g_zw[3].startMin = 20*60+30; g_zw[3].endMin = 21*60;

   ArrayInitialize(g_prevTrend, 0);

   // --- Buffers para EMAs visibles ---
   SetIndexBuffer(0, g_bufE1, INDICATOR_DATA);
   SetIndexBuffer(1, g_bufE2, INDICATOR_DATA);
   SetIndexBuffer(2, g_bufE3, INDICATOR_DATA);
   ArraySetAsSeries(g_bufE1, false);
   ArraySetAsSeries(g_bufE2, false);
   ArraySetAsSeries(g_bufE3, false);

   PlotIndexSetString(0,  PLOT_LABEL, StringFormat("EMA %d", InpEMA1Period));
   PlotIndexSetString(1,  PLOT_LABEL, StringFormat("EMA %d", InpEMA2Period));
   PlotIndexSetString(2,  PLOT_LABEL, StringFormat("EMA %d", InpEMA3Period));
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpEMA1Color);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpEMA2Color);
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, InpEMA3Color);
   PlotIndexSetDouble(0,  PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1,  PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2,  PLOT_EMPTY_VALUE, EMPTY_VALUE);

   g_emaOn[0] = InpShowEMA1;
   g_emaOn[1] = InpShowEMA2;
   g_emaOn[2] = InpShowEMA3;
   ApplyEmaVisibility();

   // --- Handles EMAs visibles (current TF) ---
   g_hE1 = iMA(_Symbol, Period(), InpEMA1Period, 0, MODE_EMA, PRICE_CLOSE);
   g_hE2 = iMA(_Symbol, Period(), InpEMA2Period, 0, MODE_EMA, PRICE_CLOSE);
   g_hE3 = iMA(_Symbol, Period(), InpEMA3Period, 0, MODE_EMA, PRICE_CLOSE);

   // --- Handles EMAs para tendencia multi-TF (usan 20/50) ---
   g_hFM1 = iMA(_Symbol, PERIOD_M1,  InpEMA1Period, 0, MODE_EMA, PRICE_CLOSE);
   g_hSM1 = iMA(_Symbol, PERIOD_M1,  InpEMA2Period, 0, MODE_EMA, PRICE_CLOSE);
   g_hFM2 = iMA(_Symbol, PERIOD_M2,  InpEMA1Period, 0, MODE_EMA, PRICE_CLOSE);
   g_hSM2 = iMA(_Symbol, PERIOD_M2,  InpEMA2Period, 0, MODE_EMA, PRICE_CLOSE);
   g_hFM5 = iMA(_Symbol, PERIOD_M5,  InpEMA1Period, 0, MODE_EMA, PRICE_CLOSE);
   g_hSM5 = iMA(_Symbol, PERIOD_M5,  InpEMA2Period, 0, MODE_EMA, PRICE_CLOSE);
   g_hFH1 = iMA(_Symbol, PERIOD_H1,  InpEMA1Period, 0, MODE_EMA, PRICE_CLOSE);
   g_hSH1 = iMA(_Symbol, PERIOD_H1,  InpEMA2Period, 0, MODE_EMA, PRICE_CLOSE);
   g_hFH4 = iMA(_Symbol, PERIOD_H4,  InpEMA1Period, 0, MODE_EMA, PRICE_CLOSE);
   g_hSH4 = iMA(_Symbol, PERIOD_H4,  InpEMA2Period, 0, MODE_EMA, PRICE_CLOSE);

   if(g_hE1==INVALID_HANDLE || g_hE2==INVALID_HANDLE || g_hE3==INVALID_HANDLE ||
      g_hFH1==INVALID_HANDLE || g_hSH1==INVALID_HANDLE ||
      g_hFH4==INVALID_HANDLE || g_hSH4==INVALID_HANDLE)
   {
      Alert("ManipulationZones: Error creando handles EMA (", GetLastError(), ")");
      return INIT_FAILED;
   }

   IndicatorSetString(INDICATOR_SHORTNAME, "ManipulationZones_Smart");

   BuildPanel();
   ChartRedraw(0);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   DeleteAllMZObjects();

   int hArr[] = {g_hE1,g_hE2,g_hE3,
                 g_hFM1,g_hSM1,g_hFM2,g_hSM2,g_hFM5,g_hSM5,
                 g_hFH1,g_hSH1,g_hFH4,g_hSH4};
   for(int i = 0; i < ArraySize(hArr); i++)
      if(hArr[i] != INVALID_HANDLE) IndicatorRelease(hArr[i]);

   ChartRedraw(0);
}

//============================================================
// ON CALCULATE
//============================================================

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
   int maxPeriod = MathMax(InpEMA3Period, MathMax(InpEMA1Period, InpEMA2Period));
   if(rates_total < maxPeriod + 5) return 0;

   if(prev_calculated <= 0)
      DeleteZoneLineObjects();

   // --- Rellenar buffers EMA visibles ---
   if(CopyBuffer(g_hE1, 0, 0, rates_total, g_bufE1) <= 0) return 0;
   if(CopyBuffer(g_hE2, 0, 0, rates_total, g_bufE2) <= 0) return 0;
   if(CopyBuffer(g_hE3, 0, 0, rates_total, g_bufE3) <= 0) return 0;

   RedrawZones();
   UpdateTrendPanel();
   ChartRedraw(0);
   return rates_total;
}

//============================================================
// ON CHART EVENT (clics en botones del panel)
//============================================================

void OnChartEvent(const int id, const long &lparam, const double &dparam,
                  const string &sparam)
{
   if(id != CHARTEVENT_OBJECT_CLICK) return;

   // --- Botones de zonas ---
   for(int z = 0; z < 4; z++)
   {
      string bgN  = StringFormat("%sBtn%d_BG",  PFX, z);
      string txtN = StringFormat("%sBtn%d_TXT", PFX, z);

      if(sparam == bgN || sparam == txtN)
      {
         g_zOn[z] = !g_zOn[z];
         UpdateButtonVisual(z);
         DeleteZoneLineObjects();
         RedrawZones();
         ChartRedraw(0);
         return;
      }
   }

   // --- Botones de EMAs ---
   for(int e = 0; e < 3; e++)
   {
      string bgN  = StringFormat("%sEma%d_BG",  PFX, e);
      string txtN = StringFormat("%sEma%d_TXT", PFX, e);

      if(sparam == bgN || sparam == txtN)
      {
         g_emaOn[e] = !g_emaOn[e];
         UpdateEmaButtonVisual(e);
         ApplyEmaVisibility();
         ChartRedraw(0);
         return;
      }
   }
}

//============================================================
// ZONAS: DIBUJO
//============================================================

void RedrawZones()
{
   datetime cutoff = TimeCurrent() - (datetime)(InpMaxDays * 86400LL);

   int totalBars = Bars(_Symbol, Period());
   if(totalBars <= 0) return;

   datetime t[];
   double   h[], l[];
   ArraySetAsSeries(t, false);
   ArraySetAsSeries(h, false);
   ArraySetAsSeries(l, false);

   int copied = CopyTime(_Symbol, Period(), 0, totalBars, t);
   if(copied <= 0) return;
   CopyHigh(_Symbol, Period(), 0, copied, h);
   CopyLow(_Symbol,  Period(), 0, copied, l);

   ZoneRecord recs[];
   int        recCnt = 0;

   for(int i = 0; i < copied; i++)
   {
      if(t[i] < cutoff) continue;

      int zIdx = TimeToZone(t[i]);
      if(zIdx < 0 || !g_zOn[zIdx]) continue;

      MqlDateTime bdt;
      TimeToStruct(t[i], bdt);

      bool matched = false;
      for(int r = 0; r < recCnt; r++)
      {
         MqlDateTime rdt;
         TimeToStruct(recs[r].keyTime, rdt);
         if(recs[r].zIdx == zIdx &&
            rdt.day  == bdt.day  &&
            rdt.mon  == bdt.mon  &&
            rdt.year == bdt.year)
         {
            if(h[i] > recs[r].hi) recs[r].hi = h[i];
            if(l[i] < recs[r].lo) recs[r].lo = l[i];
            matched = true;
            break;
         }
      }

      if(!matched)
      {
         ArrayResize(recs, recCnt + 1);
         recs[recCnt].keyTime = t[i];
         recs[recCnt].hi      = h[i];
         recs[recCnt].lo      = l[i];
         recs[recCnt].zIdx    = zIdx;
         recCnt++;
      }
   }

   for(int r = 0; r < recCnt; r++)
      PlaceZoneLines(recs[r]);
}

// Convierte datetime del servidor a zona (0-3) segun horario NY
int TimeToZone(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   int serverMin = dt.hour * 60 + dt.min;
   int nyMin     = serverMin - InpServerToNY * 60;
   nyMin = nyMin % 1440;
   if(nyMin < 0) nyMin += 1440;

   for(int z = 0; z < 4; z++)
      if(nyMin >= g_zw[z].startMin && nyMin < g_zw[z].endMin)
         return z;
   return -1;
}

void PlaceZoneLines(ZoneRecord &rec)
{
   color hc, lc, mc;
   int   w;
   GetZoneColors(rec.zIdx, hc, lc, mc, w);

   double mid  = (rec.hi + rec.lo) / 2.0;
   string base = StringFormat("%sZ%d_%d", PFX, rec.zIdx, (int)rec.keyTime);

   PlaceRay(base + "_H", rec.keyTime, rec.hi,  hc, HighLowStyle, w);
   PlaceRay(base + "_L", rec.keyTime, rec.lo,  lc, HighLowStyle, w);
   PlaceRay(base + "_M", rec.keyTime, mid,     mc, MidStyle,     w);
}

void PlaceRay(string name, datetime t, double price,
              color clr, ENUM_LINE_STYLE style, int w)
{
   if(ObjectFind(0, name) >= 0) return;

   datetime t2 = t + (datetime)(PeriodSeconds(Period()) * 3);

   if(!ObjectCreate(0, name, OBJ_TREND, 0, t, price, t2, price))
      return;

   ObjectSetInteger(0, name, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE,      style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH,      w);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT,  true);
   ObjectSetInteger(0, name, OBJPROP_RAY_LEFT,   false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
   ObjectSetInteger(0, name, OBJPROP_BACK,       true);
}

void GetZoneColors(int z, color &hc, color &lc, color &mc, int &w)
{
   switch(z)
   {
      case 0: hc=Z1H; lc=Z1L; mc=Z1M; w=Z1W; break;
      case 1: hc=Z2H; lc=Z2L; mc=Z2M; w=Z2W; break;
      case 2: hc=Z3H; lc=Z3L; mc=Z3M; w=Z3W; break;
      case 3: hc=Z4H; lc=Z4L; mc=Z4M; w=Z4W; break;
      default: hc=clrWhite; lc=clrWhite; mc=clrGray; w=1; break;
   }
}

//============================================================
// TENDENCIA: CALCULO Y PANEL
//============================================================

void UpdateTrendPanel()
{
   int tM1 = CalcTrend(g_hFM1, g_hSM1);
   int tM2 = CalcTrend(g_hFM2, g_hSM2);
   int tH1 = CalcTrend(g_hFH1, g_hSH1);
   int tH4 = CalcTrend(g_hFH4, g_hSH4);

   if(InpAlerts)
   {
      FireAlert(tM1, 0, "M1");
      FireAlert(tM2, 1, "M2");
      FireAlert(tH1, 2, "H1");
      FireAlert(tH4, 3, "H4");
   }
   g_prevTrend[0] = tM1;
   g_prevTrend[1] = tM2;
   g_prevTrend[2] = tH1;
   g_prevTrend[3] = tH4;

   ClearTrendLabels();

   ENUM_TIMEFRAMES tf = Period();
   string          tfStr = TFStr(tf);
   // Y base: 4 zonas (28*4) + 3 emas (28*3) + separadores/titulos
   int             y = InpPY + 290;

   TLbl("HDR", InpPX+5, y,
        "--- TENDENCIA | TF: " + tfStr + " ---",
        clrSilver, InpFS - 1);
   y += 20;

   if(tf == PERIOD_M1 || tf == PERIOD_M5)
   {
      // En M1/M5: mostrar H4 y H1
      TLbl("R1", InpPX+10, y, FmtTrend("H4", tH4), TClr(tH4), InpFS); y += 22;
      TLbl("R2", InpPX+10, y, FmtTrend("H1", tH1), TClr(tH1), InpFS); y += 22;
      if(tH1 != 0 && tH4 != 0 && tH1 != tH4)
      {
         TLbl("R3", InpPX+10, y, "! H1 vs H4: DIVERGENCIA", clrOrange, InpFS-1);
         y += 18;
      }
   }
   else if(tf == PERIOD_H1 || tf == PERIOD_H4)
   {
      // En H1/H4: mostrar propia TF + micro-tendencia M1/M2
      int    ownT   = (tf == PERIOD_H1) ? tH1 : tH4;
      string ownStr = (tf == PERIOD_H1) ? "H1" : "H4";

      TLbl("R0", InpPX+10, y, FmtTrend(ownStr, ownT), TClr(ownT), InpFS); y += 22;
      TLbl("SEP", InpPX+10, y, "  [ Micro-TF ]", clrSilver, InpFS-1); y += 18;
      TLbl("R1", InpPX+14, y, FmtTrend("M1", tM1), TClr(tM1), InpFS); y += 20;
      TLbl("R2", InpPX+14, y, FmtTrend("M2", tM2), TClr(tM2), InpFS); y += 20;

      if(ownT != 0 && tM1 != 0 && tM1 != ownT)
      {
         TLbl("REV", InpPX+10, y, "! POSIBLE REVERSION", clrOrange, InpFS-1);
         y += 18;
      }
   }
   else
   {
      // D1, W1, MN o cualquier otra TF alta: resumen completo
      TLbl("R1", InpPX+10, y, FmtTrend("H4", tH4), TClr(tH4), InpFS); y += 22;
      TLbl("R2", InpPX+10, y, FmtTrend("H1", tH1), TClr(tH1), InpFS); y += 22;
      TLbl("R3", InpPX+10, y, FmtTrend("M1", tM1), TClr(tM1), InpFS); y += 22;
      TLbl("R4", InpPX+10, y, FmtTrend("M2", tM2), TClr(tM2), InpFS); y += 22;
   }
}

int CalcTrend(int hFast, int hSlow)
{
   if(hFast == INVALID_HANDLE || hSlow == INVALID_HANDLE) return 0;
   double f[2], s[2];
   if(CopyBuffer(hFast, 0, 0, 2, f) < 2) return 0;
   if(CopyBuffer(hSlow, 0, 0, 2, s) < 2) return 0;
   if(f[1] > s[1]) return  1;
   if(f[1] < s[1]) return -1;
   return 0;
}

void FireAlert(int newT, int idx, string tfName)
{
   if(g_prevTrend[idx] != 0 && newT != 0 && newT != g_prevTrend[idx])
   {
      string dir = (newT > 0) ? "ALCISTA ^" : "BAJISTA v";
      string msg = StringFormat("CAMBIO TENDENCIA %s: %s -> %s  [%s]",
                                tfName, _Symbol, dir, TimeToString(TimeCurrent()));
      Alert(msg);
      if(InpPush) SendNotification(msg);
   }
}

string FmtTrend(string tf, int t)
{
   if(t > 0) return tf + ": ^ ALCISTA";
   if(t < 0) return tf + ": v BAJISTA";
   return       tf + ":   LATERAL";
}

color TClr(int t)
{
   if(t > 0) return clrLimeGreen;
   if(t < 0) return C'220,60,60';
   return clrGray;
}

string TFStr(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M2:  return "M2";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H2:  return "H2";
      case PERIOD_H3:  return "H3";
      case PERIOD_H4:  return "H4";
      case PERIOD_H6:  return "H6";
      case PERIOD_H8:  return "H8";
      case PERIOD_H12: return "H12";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN";
      default:         return "??";
   }
}

//============================================================
// PANEL: CONSTRUCCION
//============================================================

#define PW  215
#define PH  520

void BuildPanel()
{
   MkRect(PFX+"PBG",  InpPX, InpPY, PW, PH, InpBG, InpBRD, false);

   MkLbl(PFX+"PTit",  InpPX+6,  InpPY+7,
         " MANIPULATION ZONES v1.1", clrWhite, InpFS+1);
   MkLbl(PFX+"PSep0", InpPX+5,  InpPY+25,
         "-----------------------------------", InpBRD, InpFS-2);

   // Zonas
   int by = InpPY + 36;
   for(int z = 0; z < 4; z++)
   {
      BuildBtn(z, by);
      by += 28;
   }

   MkLbl(PFX+"PSep1", InpPX+5, by+4,
         "-----------------------------------", InpBRD, InpFS-2);
   by += 18;

   // EMAs
   MkLbl(PFX+"PEmaTit", InpPX+6, by, " MEDIAS MOVILES", clrSilver, InpFS-1);
   by += 18;
   for(int e = 0; e < 3; e++)
   {
      BuildEmaBtn(e, by);
      by += 28;
   }

   MkLbl(PFX+"PSep2", InpPX+5, by+4,
         "-----------------------------------", InpBRD, InpFS-2);
}

void BuildBtn(int z, int y)
{
   string bgN  = StringFormat("%sBtn%d_BG",  PFX, z);
   string txtN = StringFormat("%sBtn%d_TXT", PFX, z);
   color  bg   = g_zOn[z] ? C'0,110,55' : C'120,20,20';

   MkRect(bgN,  InpPX+5, y, PW-10, 26, bg, bg, true);
   MkLbl(txtN, InpPX+12, y+5, BtnText(z), clrWhite, InpFS);
}

void UpdateButtonVisual(int z)
{
   string bgN  = StringFormat("%sBtn%d_BG",  PFX, z);
   string txtN = StringFormat("%sBtn%d_TXT", PFX, z);
   color  bg   = g_zOn[z] ? C'0,110,55' : C'120,20,20';

   ObjectSetInteger(0, bgN,  OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, bgN,  OBJPROP_COLOR,   bg);
   ObjectSetString(0,  txtN, OBJPROP_TEXT, BtnText(z));
}

string BtnText(int z)
{
   string lbl[] = {"Z1: 3:30-4:00 AM", "Z2: 8:30-9:00 AM",
                   "Z3: 13:30-14:00 ", "Z4: 20:30-21:00 "};
   return (g_zOn[z] ? "[ON ] " : "[OFF] ") + lbl[z];
}

void BuildEmaBtn(int e, int y)
{
   string bgN  = StringFormat("%sEma%d_BG",  PFX, e);
   string txtN = StringFormat("%sEma%d_TXT", PFX, e);
   color  bg   = g_emaOn[e] ? C'0,110,55' : C'120,20,20';

   MkRect(bgN,  InpPX+5, y, PW-10, 26, bg, bg, true);
   MkLbl(txtN, InpPX+12, y+5, EmaBtnText(e), clrWhite, InpFS);
}

void UpdateEmaButtonVisual(int e)
{
   string bgN  = StringFormat("%sEma%d_BG",  PFX, e);
   string txtN = StringFormat("%sEma%d_TXT", PFX, e);
   color  bg   = g_emaOn[e] ? C'0,110,55' : C'120,20,20';

   ObjectSetInteger(0, bgN,  OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, bgN,  OBJPROP_COLOR,   bg);
   ObjectSetString(0,  txtN, OBJPROP_TEXT, EmaBtnText(e));
}

string EmaBtnText(int e)
{
   int    per[] = {InpEMA1Period, InpEMA2Period, InpEMA3Period};
   return StringFormat("%s EMA %d", g_emaOn[e] ? "[ON ]" : "[OFF]", per[e]);
}

void ApplyEmaVisibility()
{
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, g_emaOn[0] ? InpEMA1Color : clrNONE);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, g_emaOn[1] ? InpEMA2Color : clrNONE);
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, g_emaOn[2] ? InpEMA3Color : clrNONE);
}

//============================================================
// HELPERS DE OBJETOS
//============================================================

void MkRect(string name, int x, int y, int w, int h,
            color bg, color border, bool selectable)
{
   if(ObjectFind(0, name) >= 0) return;
   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,   x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,   y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE,       w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE,       h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR,     bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR,       border);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_CORNER,      CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE,  selectable);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,      !selectable);
   ObjectSetInteger(0, name, OBJPROP_BACK,        false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER,      selectable ? 10 : 0);
}

void MkLbl(string name, int x, int y, string text, color clr, int fs)
{
   if(ObjectFind(0, name) >= 0) return;
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,  y);
   ObjectSetString(0,  name, OBJPROP_TEXT,       text);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      clr);
   ObjectSetString(0,  name, OBJPROP_FONT,       "Consolas");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,   fs);
   ObjectSetInteger(0, name, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR,     ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
   ObjectSetInteger(0, name, OBJPROP_BACK,       false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER,     0);
}

void TLbl(string key, int x, int y, string text, color clr, int fs)
{
   string name = PFX + "T_" + key;
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR,     ANCHOR_LEFT_UPPER);
      ObjectSetString(0,  name, OBJPROP_FONT,       "Consolas");
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
      ObjectSetInteger(0, name, OBJPROP_BACK,       false);
   }
   ObjectSetString(0,  name, OBJPROP_TEXT,      text);
   ObjectSetInteger(0, name, OBJPROP_COLOR,     clr);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,  fs);
}

void ClearTrendLabels()
{
   string keys[] = {"HDR","R0","R1","R2","R3","R4","SEP","REV"};
   for(int i = 0; i < ArraySize(keys); i++)
      ObjectDelete(0, PFX + "T_" + keys[i]);
}

//============================================================
// LIMPIEZA
//============================================================

void DeleteZoneLineObjects()
{
   int n = ObjectsTotal(0);
   for(int i = n-1; i >= 0; i--)
   {
      string nm = ObjectName(0, i);
      if(StringFind(nm, PFX+"Z") == 0)
         ObjectDelete(0, nm);
   }
}

void DeleteAllMZObjects()
{
   int n = ObjectsTotal(0);
   for(int i = n-1; i >= 0; i--)
   {
      string nm = ObjectName(0, i);
      if(StringFind(nm, PFX) == 0)
         ObjectDelete(0, nm);
   }
}
//+------------------------------------------------------------------+
