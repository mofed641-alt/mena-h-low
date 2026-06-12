//+------------------------------------------------------------------+
//|                        Mena H-Low Expert Advisor                  |
//|                    Breakout Strategy with Martingale              |
//+------------------------------------------------------------------+
#property copyright "Mena H-Low EA"
#property link      "https://github.com/mofed641-alt/mena-h-low"
#property version   "1.0"
#property strict

#include <Trade\Trade.mqh>

// ============================================================
//                      INPUTS - الإعدادات
// ============================================================

input int    InpBars              = 5;           // عدد الشموع للحساب
input double InpLotSize           = 0.1;         // حجم اللوت الأساسي
input int    InpTakeProfit       = 200;          // الهدف بالنقاط
input int    InpStopLoss         = 100;          // وقف الخسارة بالنقاط
input int    InpMaxMartingale     = 20;          // أقصى عدد مضاعفات
input double InpBasketProfit      = 100;         // الربح الإجمالي المستهدف بالدولار
input bool   InpUseBasketClose    = true;        // إغلاق على السلة
input int    InpMagicNumber       = 123456;      // رقم الـ Magic
input bool   InpPrintDebug        = true;        // طباعة معلومات التصحيح

// ============================================================
//                      GLOBAL VARIABLES
// ============================================================

CTrade trade;
double highPrice, lowPrice;
int martingaleLevel = 0;
double totalProfit = 0;
bool buySignal = false, sellSignal = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // تعريف الـ Magic Number
   trade.SetExpertMagicNumber(InpMagicNumber);
   
   // تحديد انزلاق الأسعار (Slippage)
   trade.SetDeviationInPoints(10);
   
   // طباعة معلومات البداية
   if(InpPrintDebug)
   {
      Print("=== Mena H-Low EA Started ===");
      Print("عدد الشموع: ", InpBars);
      Print("حجم اللوت: ", InpLotSize);
      Print("الهدف: ", InpTakeProfit, " نقطة");
      Print("وقف الخسارة: ", InpStopLoss, " نقطة");
      Print("أقصى مضاعفات: ", InpMaxMartingale);
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("=== Mena H-Low EA Stopped ===");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // التحقق من وجود صفقات مفتوحة
   int openPositions = CountOpenPositions();
   
   // حساب الأعلى والأدنى
   CalculateHighLow();
   
   // التحقق من الإشارات
   CheckSignals();
   
   // فتح صفقات جديدة إذا لم تكن هناك صفقات مفتوحة
   if(openPositions == 0)
   {
      if(buySignal)
         OpenBuyOrder();
      else if(sellSignal)
         OpenSellOrder();
   }
   
   // التحقق من إغلاق السلة
   if(InpUseBasketClose)
      CheckBasketClose();
   
   // طباعة معلومات التصحيح
   if(InpPrintDebug && openPositions > 0)
      PrintDebugInfo();
}

//+------------------------------------------------------------------+
//| حساب الأعلى والأدنى لعدد الشموع المحددة
//+------------------------------------------------------------------+
void CalculateHighLow()
{
   // إنشاء مصفوفة للأسعار العالية والمنخفضة
   double high[];
   double low[];
   
   // ربط المصفوفات بالمؤشر
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   
   // نسخ البيانات من الرسم البياني
   CopyHigh(Symbol(), PERIOD_CURRENT, 1, InpBars, high);
   CopyLow(Symbol(), PERIOD_CURRENT, 1, InpBars, low);
   
   // إيجاد الأعلى والأدنى
   highPrice = high[ArrayMaximum(high)];
   lowPrice = low[ArrayMinimum(low)];
   
   if(InpPrintDebug)
   {
      Print("أعلى سعر آخر ", InpBars, " شموع: ", highPrice);
      Print("أدنى سعر آخر ", InpBars, " شموع: ", lowPrice);
   }
}

//+------------------------------------------------------------------+
//| فحص الإشارات
//+------------------------------------------------------------------+
void CheckSignals()
{
   double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_LAST);
   
   buySignal = (currentPrice > highPrice);
   sellSignal = (currentPrice < lowPrice);
}

//+------------------------------------------------------------------+
//| فتح أمر شراء
//+------------------------------------------------------------------+
void OpenBuyOrder()
{
   double lot = CalculateLotSize();
   double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double tp = ask + InpTakeProfit * Point();
   double sl = ask - InpStopLoss * Point();
   
   trade.Buy(lot, Symbol(), ask, sl, tp, "Mena H-Low Buy");
   
   if(InpPrintDebug)
      Print("فتح أمر شراء - اللوت: ", lot, " - TP: ", tp, " - SL: ", sl);
   
   martingaleLevel++;
}

//+------------------------------------------------------------------+
//| فتح أمر بيع
//+------------------------------------------------------------------+
void OpenSellOrder()
{
   double lot = CalculateLotSize();
   double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double tp = bid - InpTakeProfit * Point();
   double sl = bid + InpStopLoss * Point();
   
   trade.Sell(lot, Symbol(), bid, sl, tp, "Mena H-Low Sell");
   
   if(InpPrintDebug)
      Print("فتح أمر بيع - اللوت: ", lot, " - TP: ", tp, " - SL: ", sl);
   
   martingaleLevel++;
}

//+------------------------------------------------------------------+
//| حساب حجم اللوت بناءً على المضاعفات
//+------------------------------------------------------------------+
double CalculateLotSize()
{
   double lot = InpLotSize;
   
   // مضاعفة اللوت حسب عدد المحاولات السابقة
   for(int i = 0; i < martingaleLevel && i < InpMaxMartingale; i++)
      lot *= 2;
   
   // التحقق من الحد الأقصى للوت
   double maxLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   double minLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   
   if(lot > maxLot)
      lot = maxLot;
   if(lot < minLot)
      lot = minLot;
   
   return lot;
}

//+------------------------------------------------------------------+
//| عد الصفقات المفتوحة
//+------------------------------------------------------------------+
int CountOpenPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetString(POSITION_SYMBOL) == Symbol() &&
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| إغلاق جميع الصفقات عند تحقيق الربح الإجمالي
//+------------------------------------------------------------------+
void CheckBasketClose()
{
   totalProfit = CalculateTotalProfit();
   
   if(totalProfit >= InpBasketProfit)
   {
      CloseAllPositions();
      martingaleLevel = 0;
      
      if(InpPrintDebug)
         Print("تم إغلاق السلة - الربح الإجمالي: ", totalProfit);
   }
}

//+------------------------------------------------------------------+
//| حساب الربح الإجمالي
//+------------------------------------------------------------------+
double CalculateTotalProfit()
{
   double profit = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetString(POSITION_SYMBOL) == Symbol() &&
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            profit += PositionGetDouble(POSITION_PROFIT);
         }
      }
   }
   
   return profit;
}

//+------------------------------------------------------------------+
//| إغلاق جميع الصفقات
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetString(POSITION_SYMBOL) == Symbol() &&
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            trade.PositionClose(PositionGetTicket(i));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| طباعة معلومات التصحيح
//+------------------------------------------------------------------+
void PrintDebugInfo()
{
   totalProfit = CalculateTotalProfit();
   int positions = CountOpenPositions();
   double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_LAST);
   
   Print("======================================");
   Print("الوقت: ", TimeToString(TimeCurrent()));
   Print("عدد الصفقات المفتوحة: ", positions);
   Print("مستوى المضاعفة الحالي: ", martingaleLevel);
   Print("الربح الإجمالي: ", totalProfit);
   Print("أعلى السعر: ", highPrice);
   Print("أدنى السعر: ", lowPrice);
   Print("السعر الحالي: ", currentPrice);
   Print("======================================");
}

//+------------------------------------------------------------------+
