//+------------------------------------------------------------------+
//|                     Smart_OB_FVG_MTF.mq5                        |
//|          Order Blocks + FVG | Multi-Timeframe | Panel ON/OFF    |
//+------------------------------------------------------------------+
#property copyright   "Smart ICT OB+FVG MTF v1.0"
#property version     "1.00"
#property indicator_chart_window
#property indicator_plots 0

//===================================================================
//  INPUTS
//===================================================================
input group "━━━━━  TEMPORALIDADES  ON / OFF  ━━━━━"
input bool  i_MN    = true;    // [MN ] Mensual
input bool  i_W1    = true;    // [W1 ] Semanal
input bool  i_D1    = true;    // [D1 ] Diario
input bool  i_H4    = true;    // [H4 ] 4 Horas
input bool  i_H1    = true;    // [H1 ] 1 Hora
input bool  i_M15   = false;   // [M15] 15 Minutos
input bool  i_M5    = false;   // [M5 ] 5 Minutos
input bool  i_M1    = false;   // [M1 ] 1 Minuto

input group "━━━━━  DETECCION  ━━━━━"
input bool  i_ob      = true;   // Mostrar Order Blocks
input bool  i_fvg     = true;   // Mostrar Fair Value Gaps
input int   i_max     = 3;      // Maximo de zonas por temporalidad (1-10)
input int   i_scan    = 150;    // Barras a escanear por temporalidad
input bool  i_ote     = true;   // Dibujar nivel 50% (OTE)
input bool  i_hide    = true;   // Ocultar zonas ya mitigadas
input bool  i_extend  = true;   // Extender zona hasta precio actual

input group "━━━━━  COLORES  ━━━━━"
input color c_MN    = 0xFFD700;   // Mensual   (Dorado)
input color c_W1    = 0x1E90FF;   // Semanal   (Azul)
input color c_D1    = 0x00C800;   // Diario    (Verde)
input color c_H4    = 0xFF4500;   // H4        (Naranja)
input color c_H1    = 0xFF00FF;   // H1        (Magenta)
input color c_M15   = 0x00FFFF;   // M15       (Cyan)
input color c_M5    = 0xFFFFFF;   // M5        (Blanco)
input color c_M1    = 0x888888;   // M1        (Gris)

input group "━━━━━  ESTILO  ━━━━━"
input bool  i_fill    = true;    // Rellenar zonas con color
input int   i_bw      = 1;       // Grosor del borde (px)
input bool  i_lbl     = true;    // Mostrar etiquetas en zonas

input group "━━━━━  PANEL  ━━━━━"
input bool  i_panel   = true;    // Mostrar panel de control
input int   i_px      = 10;      // Posicion X del panel
input int   i_py      = 30;      // Posicion Y del panel

//===================================================================
//  ESTRUCTURA DE ZONA
//===================================================================
struct Zone
{
   int      idx;      // indice de temporalidad (0-7)
   datetime t_open;   // tiempo del bar donde se formo la zona
   double   top;      // limite superior
   double   bot;      // limite inferior
   double   mid;      // nivel 50%
   bool     bull;     // true=alcista, false=bajista
   string   typ;      // "OB" o "FVG"
};

//===================================================================
//  CONSTANTES Y GLOBALES
//===================================================================
#define PFX  "SOBFVG_"
#define NTF  8

const ENUM_TIMEFRAMES TFS[NTF] = {
   PERIOD_MN1, PERIOD_W1,  PERIOD_D1, PERIOD_H4,
   PERIOD_H1,  PERIOD_M15, PERIOD_M5, PERIOD_M1
};
const string TFN[NTF] = {"MN","W1","D1","H4","H1","M15","M5","M1"};

color  g_clr[NTF];
bool   g_on[NTF];
Zone   g_z[];
int    g_nz;

//===================================================================
//  INIT / DEINIT / CALCULATE
//===================================================================
int OnInit()
{
   Refresh();
   EventSetTimer(2);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectsDeleteAll(0, PFX);
}

int OnCalculate(const int rt, const int pc,
                const datetime &t[], const double &o[],
                const double &h[], const double &l[],
                const double &c[], const long &tv[],
                const long &v[],   const int &s[])
{
   static datetime last_bar = 0;
   if(rt > 0 && t[rt-1] != last_bar)
   {
      last_bar = t[rt-1];
      Refresh();
   }
   return rt;
}

void OnTimer()       { if(i_panel) Panel(); }

void OnChartEvent(const int id, const long &lp,
                  const double &dp, const string &sp)
{
   if(id == CHARTEVENT_CHART_CHANGE) Refresh();
}

//===================================================================
//  REFRESH PRINCIPAL
//===================================================================
void Refresh()
{
   // Cargar inputs a arrays globales
   g_on[0]=i_MN;  g_on[1]=i_W1;  g_on[2]=i_D1;  g_on[3]=i_H4;
   g_on[4]=i_H1;  g_on[5]=i_M15; g_on[6]=i_M5;  g_on[7]=i_M1;
   g_clr[0]=c_MN; g_clr[1]=c_W1; g_clr[2]=c_D1; g_clr[3]=c_H4;
   g_clr[4]=c_H1; g_clr[5]=c_M15;g_clr[6]=c_M5; g_clr[7]=c_M1;

   ObjectsDeleteAll(0, PFX);
   g_nz = 0;
   ArrayResize(g_z, 0);

   for(int t = 0; t < NTF; t++)
      if(g_on[t]) Scan(t);

   Render();
   if(i_panel) Panel();
   ChartRedraw(0);
}

//===================================================================
//  ESCANEAR UNA TEMPORALIDAD
//===================================================================
void Scan(int t)
{
   MqlRates R[];
   int n = CopyRates(_Symbol, TFS[t], 0, i_scan, R);
   if(n < 5) return;

   int ob_n = 0, fvg_n = 0;

   // Escanear de mas reciente a mas antiguo
   for(int i = n-2; i >= 2; i--)
   {
      if(ob_n >= i_max && fvg_n >= i_max) break;

      // ── ORDER BLOCK ──────────────────────────────────────────────
      if(i_ob && ob_n < i_max)
      {
         bool bear = (R[i].close < R[i].open);
         bool bull = (R[i].close > R[i].open);

         // OB Alc: vela bajista seguida de impulso alcista
         if(bear && R[i+1].close > R[i].high)
         {
            Zone z;
            z.idx    = t;
            z.t_open = R[i].time;
            z.top    = MathMax(R[i].open, R[i].close);
            z.bot    = MathMin(R[i].open, R[i].close);
            z.mid    = (z.top + z.bot) * 0.5;
            z.bull   = true;
            z.typ    = "OB";
            if(!i_hide || !Mitigated(z, R, n)) { Push(z); ob_n++; }
         }
         // OB Baj: vela alcista seguida de impulso bajista
         else if(bull && R[i+1].close < R[i].low)
         {
            Zone z;
            z.idx    = t;
            z.t_open = R[i].time;
            z.top    = MathMax(R[i].open, R[i].close);
            z.bot    = MathMin(R[i].open, R[i].close);
            z.mid    = (z.top + z.bot) * 0.5;
            z.bull   = false;
            z.typ    = "OB";
            if(!i_hide || !Mitigated(z, R, n)) { Push(z); ob_n++; }
         }
      }

      // ── FAIR VALUE GAP ───────────────────────────────────────────
      if(i_fvg && fvg_n < i_max)
      {
         // FVG Alc: hueco entre high[i-1] y low[i+1]
         if(R[i-1].high < R[i+1].low)
         {
            Zone z;
            z.idx    = t;
            z.t_open = R[i].time;
            z.top    = R[i+1].low;
            z.bot    = R[i-1].high;
            z.mid    = (z.top + z.bot) * 0.5;
            z.bull   = true;
            z.typ    = "FVG";
            if(z.top > z.bot)
               if(!i_hide || !Mitigated(z, R, n)) { Push(z); fvg_n++; }
         }
         // FVG Baj: hueco entre low[i-1] y high[i+1]
         else if(R[i-1].low > R[i+1].high)
         {
            Zone z;
            z.idx    = t;
            z.t_open = R[i].time;
            z.top    = R[i-1].low;
            z.bot    = R[i+1].high;
            z.mid    = (z.top + z.bot) * 0.5;
            z.bull   = false;
            z.typ    = "FVG";
            if(z.top > z.bot)
               if(!i_hide || !Mitigated(z, R, n)) { Push(z); fvg_n++; }
         }
      }
   }
}

//───────────────────────────────────────────────────────────────────
bool Mitigated(const Zone &z, const MqlRates &R[], int n)
{
   for(int i = 0; i < n; i++)
   {
      if(R[i].time <= z.t_open) continue;
      if( z.bull && R[i].low  <= z.top) return true;
      if(!z.bull && R[i].high >= z.bot) return true;
   }
   return false;
}

void Push(Zone &z)
{
   ArrayResize(g_z, g_nz + 1);
   g_z[g_nz++] = z;
}

//===================================================================
//  DIBUJAR TODAS LAS ZONAS
//===================================================================
void Render()
{
   datetime t_now = TimeCurrent();
   datetime t_ext = t_now + (datetime)(PeriodSeconds(Period()) * 5);

   for(int i = 0; i < g_nz; i++)
   {
      Zone     z  = g_z[i];
      color    cl = g_clr[z.idx];
      string   bn = PFX + TFN[z.idx] + "_" + z.typ +
                    "_" + (z.bull ? "B" : "S") +
                    "_" + IntegerToString((int)z.t_open) +
                    "_" + IntegerToString(i);

      datetime t_right = i_extend ? t_ext : t_now;

      // Relleno de zona
      if(i_fill)
         Box(bn+"_F", z.t_open, t_right, z.top, z.bot, cl);

      // Bordes superior e inferior
      HLine(bn+"_T", z.t_open, t_right, z.top, cl, STYLE_SOLID, i_bw);
      HLine(bn+"_B", z.t_open, t_right, z.bot, cl, STYLE_SOLID, i_bw);

      // Linea 50% OTE
      if(i_ote)
         HLine(bn+"_M", z.t_open, t_right, z.mid, cl, STYLE_DOT, 1);

      // Etiqueta
      if(i_lbl)
      {
         string lbl = TFN[z.idx] + " " + z.typ + (z.bull ? " ▲" : " ▼");
         Txt(bn+"_L", z.t_open, z.top, lbl, cl, 7);
      }
   }
}

//===================================================================
//  PANEL DE CONTROL
//===================================================================
void Panel()
{
   if(!i_panel) return;

   const int RH = 18;
   const int PW = 205;
   const int TH = 22;
   int PH = TH + NTF * RH + 8;
   int x  = i_px;
   int y  = i_py;

   // Contar zonas por temporalidad
   int ob_c[NTF], fv_c[NTF];
   for(int t = 0; t < NTF; t++) { ob_c[t]=0; fv_c[t]=0; }
   for(int i = 0; i < g_nz; i++)
   {
      int ti = g_z[i].idx;
      if(g_z[i].typ == "OB") ob_c[ti]++;
      else                    fv_c[ti]++;
   }

   // Fondo principal
   PRct(PFX+"P_BG", x, y, PW, PH, 0x05050F);

   // Barra de titulo
   PRct(PFX+"P_TH", x, y, PW, TH, 0x15154A);
   PLbl(PFX+"P_TX", x+12, y+5, "  ◈  OB + FVG  MULTI-TF  ◈", clrWhite, 8, true);

   for(int t = 0; t < NTF; t++)
   {
      int  ry  = y + TH + t * RH + 3;
      bool on  = g_on[t];
      color cl = on ? g_clr[t] : (color)0x383838;

      // Fondo de fila
      color rbg = on ? DimClr(g_clr[t], 200) : (color)0x0E0E1C;
      PRct(PFX+"P_R"+IntegerToString(t), x+2, ry, PW-4, RH-1, rbg);

      // Indicador circulo
      string dot = on ? "●" : "○";
      PLbl(PFX+"P_D"+IntegerToString(t), x+7,  ry+2, dot, cl, 10, false);

      // Nombre TF
      PLbl(PFX+"P_N"+IntegerToString(t), x+23, ry+4,
           StringFormat("%-4s", TFN[t]), cl, 8, true);

      // Estado y conteo
      string st;
      if(!on)
         st = "  OFF";
      else if(ob_c[t] + fv_c[t] == 0)
         st = "   ON   sin zonas";
      else
         st = StringFormat("   ON   OB:%d  FVG:%d", ob_c[t], fv_c[t]);

      PLbl(PFX+"P_S"+IntegerToString(t), x+55, ry+4, st, cl, 8, false);
   }
}

//===================================================================
//  HELPERS: OBJETOS EN GRAFICO
//===================================================================
void Box(string n, datetime t1, datetime t2, double p1, double p2, color cl)
{
   if(ObjectFind(0,n) < 0) ObjectCreate(0,n,OBJ_RECTANGLE,0,t1,p1,t2,p2);
   ObjectSetInteger(0,n,OBJPROP_TIME,  0,t1);
   ObjectSetDouble( 0,n,OBJPROP_PRICE, 0,p1);
   ObjectSetInteger(0,n,OBJPROP_TIME,  1,t2);
   ObjectSetDouble( 0,n,OBJPROP_PRICE, 1,p2);
   ObjectSetInteger(0,n,OBJPROP_COLOR, cl);
   ObjectSetInteger(0,n,OBJPROP_FILL,  true);
   ObjectSetInteger(0,n,OBJPROP_BACK,  true);
   ObjectSetInteger(0,n,OBJPROP_WIDTH, 0);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN, true);
}

void HLine(string n, datetime t1, datetime t2, double p,
           color cl, ENUM_LINE_STYLE sty, int w)
{
   if(ObjectFind(0,n) < 0) ObjectCreate(0,n,OBJ_TREND,0,t1,p,t2,p);
   ObjectSetInteger(0,n,OBJPROP_TIME,  0,t1);
   ObjectSetDouble( 0,n,OBJPROP_PRICE, 0,p);
   ObjectSetInteger(0,n,OBJPROP_TIME,  1,t2);
   ObjectSetDouble( 0,n,OBJPROP_PRICE, 1,p);
   ObjectSetInteger(0,n,OBJPROP_COLOR, cl);
   ObjectSetInteger(0,n,OBJPROP_STYLE, sty);
   ObjectSetInteger(0,n,OBJPROP_WIDTH, w);
   ObjectSetInteger(0,n,OBJPROP_RAY_RIGHT,  false);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN, true);
}

void Txt(string n, datetime t, double p, string tx, color cl, int sz)
{
   if(ObjectFind(0,n) < 0) ObjectCreate(0,n,OBJ_TEXT,0,t,p);
   ObjectSetInteger(0,n,OBJPROP_TIME,    0,t);
   ObjectSetDouble( 0,n,OBJPROP_PRICE,   0,p);
   ObjectSetString( 0,n,OBJPROP_TEXT,    tx);
   ObjectSetInteger(0,n,OBJPROP_COLOR,   cl);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,sz);
   ObjectSetString( 0,n,OBJPROP_FONT,    "Arial Bold");
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN, true);
}

//===================================================================
//  HELPERS: PANEL (OBJETOS PIXEL)
//===================================================================
void PRct(string n, int x, int y, int w, int h, color cl)
{
   if(ObjectFind(0,n) < 0) ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,   x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,   y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,       w);
   ObjectSetInteger(0,n,OBJPROP_YSIZE,       h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,     cl);
   ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0,n,OBJPROP_CORNER,      CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_BACK,        false);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,  false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,      true);
}

void PLbl(string n, int x, int y, string tx, color cl, int sz, bool bold)
{
   if(ObjectFind(0,n) < 0) ObjectCreate(0,n,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,  y);
   ObjectSetString( 0,n,OBJPROP_TEXT,       tx);
   ObjectSetInteger(0,n,OBJPROP_COLOR,      cl);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,   sz);
   ObjectSetString( 0,n,OBJPROP_FONT,       bold ? "Arial Bold" : "Arial");
   ObjectSetInteger(0,n,OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_BACK,       false);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,     true);
}

//===================================================================
//  UTILIDAD: OSCURECER COLOR
//===================================================================
color DimClr(color c, int s)
{
   int r = (c >> 16) & 0xFF;
   int g = (c >>  8) & 0xFF;
   int b =  c        & 0xFF;
   return (color)(
      ((int)MathMax(0, r - s) << 16) |
      ((int)MathMax(0, g - s) <<  8) |
      ((int)MathMax(0, b - s))
   );
}
//+------------------------------------------------------------------+
