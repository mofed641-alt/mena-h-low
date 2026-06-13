//+------------------------------------------------------------------+
//|                        Mena H-Low Expert Advisor                  |
//|                    Breakout Strategy with Martingale              |
//+------------------------------------------------------------------+
#property copyright "Mena H-Low EA"
#property link      "https://github.com/mofed641-alt/mena-h-low"
#property version   "1.02"
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
double highPrice = 0, lowPrice = 0;
int martingaleLevel = 0;
double totalProfit = 0;
bool buySignalTriggered = false, sellSignalTriggered = false;
bool lastSignalWasBuy = false;

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
      if(buySignalTriggered && !lastSignalWasBuy)
      {
         OpenBuyOrder();
         lastSignalWasBuy = true;
         buySignalTriggered = false;
      }
      else if(sellSignalTriggered && lastSignalWasBuy)
      {
         OpenSellOrder();
         lastSignalWasBuy = false;
         sellSignalTriggered = false;
      }
   }
   else
   {
      // التحقق من إغلاق السلة
      if(InpUseBasketClose)
         CheckBasketClose();
      
      // طباعة معلومات التصحيح
      if(InpPrintDebug)
         PrintDebugInfo();
   }
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
   if(CopyHigh(Symbol(), PERIOD_CURRENT, 0, InpBars, high) <= 0 ||
      CopyLow(Symbol(), PERIOD_CURRENT, 0, InpBars, low) <= 0)
   {
      if(InpPrintDebug)
         Print("خطأ في نسخ بيانات الأسعار");
      return;
   }
   
   // إيجاد الأعلى والأدنى
   int highIndex = ArrayMaximum(high);
   int lowIndex = ArrayMinimum(low);
   
   highPrice = high[highIndex];
   lowPrice = low[lowIndex];
   
   if(InpPrintDebug)
   {
      static datetime lastPrintTime = 0;
      if(TimeCurrent() - lastPrintTime >= 60) // طباعة كل دقيقة
      {
         Print("=== معلومات السعر ===");
         Print("أعلى سعر آخر ", InpBars, " شموع: ", highPrice);
         Print("أدنى سعر آخر ", InpBars, " شموع: ", lowPrice);
         double closePrice[];
         ArraySetAsSeries(closePrice, true);
         CopyClose(Symbol(), PERIOD_CURRENT, 0, 1, closePrice);
         Print("السعر الحالي (Close): ", closePrice[0]);
         Print("======================================");
         lastPrintTime = TimeCurrent();
      }
   }
}

//+------------------------------------------------------------------+
//| فحص الإشارات
//+------------------------------------------------------------------+
void CheckSignals()
{
   // الحصول على السعر الحالي
   double currentPrice[];
   ArraySetAsSeries(currentPrice, true);
   if(CopyClose(Symbol(), PERIOD_CURRENT, 0, 1, currentPrice) <= 0)
      return;
   
   // إشارة الشراء: اختراق الأعلى
   if(currentPrice[0] > highPrice && highPrice > 0)
   {
      buySignalTriggered = true;
      if(InpPrintDebug)
         Print("إشارة شراء: السعر ", currentPrice[0], " > الأعلى ", highPrice);
   }
   
   // إشارة البيع: اختراق الأدنى
   if(currentPrice[0] < lowPrice && lowPrice > 0)
   {
      sellSignalTriggered = true;
      if(InpPrintDebug)
         Print("إشارة بيع: السعر ", currentPrice[0], " < الأدنى ", lowPrice);
   }
}

//+------------------------------------------------------------------+
//| فتح أمر شراء
//+------------------------------------------------------------------+
void OpenBuyOrder()
{
   double lot = CalculateLotSize();
   double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double tp = ask + InpTakeProfit * point;
   double sl = ask - InpStopLoss * point;
   
   // التحقق من صحة البيانات
   if(ask <= 0 || lot <= 0)
   {
      if(InpPrintDebug)
         Print("خطأ: بيانات غير صحيحة - Ask: ", ask, " Lot: ", lot);
      return;
   }
   
   if(trade.Buy(lot, Symbol(), ask, sl, tp, "Mena H-Low Buy"))
   {
      if(InpPrintDebug)
         Print("✓ تم فتح أمر شراء - اللوت: ", lot, " - السعر: ", ask, " - TP: ", tp, " - SL: ", sl);
      martingaleLevel++;
   }
   else
   {
      if(InpPrintDebug)
         Print("✗ فشل فتح أمر الشراء - الخطأ: ", trade.ResultRetcode());
   }
}

//+------------------------------------------------------------------+
//| فتح أمر بيع
//+------------------------------------------------------------------+
void OpenSellOrder()
{
   double lot = CalculateLotSize();
   double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double tp = bid - InpTakeProfit * point;
   double sl = bid + InpStopLoss * point;
   
   // التحقق من صحة البيانات
   if(bid <= 0 || lot <= 0)
   {
      if(InpPrintDebug)
         Print("خطأ: بيانات غير صحيحة - Bid: ", bid, " Lot: ", lot);
      return;
   }
   
   if(trade.Sell(lot, Symbol(), bid, sl, tp, "Mena H-Low Sell"))
   {
      if(InpPrintDebug)
         Print("✓ تم فتح أمر بيع - اللوت: ", lot, " - السعر: ", bid, " - TP: ", tp, " - SL: ", sl);
      martingaleLevel++;
   }
   else
   {
      if(InpPrintDebug)
         Print("✗ فشل فتح أمر البيع - الخطأ: ", trade.ResultRetcode());
   }
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
   
   // التحقق من الحد الأقصى والأدنى للوت
   double maxLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   double minLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double step = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   
   if(lot > maxLot)
      lot = maxLot;
   if(lot < minLot)
      lot = minLot;
   
   // تقريب اللوت حسب خطوة النظام
   if(step > 0)
      lot = MathRound(lot / step) * step;
   
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
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
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
         Print("✓ تم إغلاق السلة بنجاح - الربح الإجمالي: ", totalProfit);
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
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
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
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == Symbol() &&
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            trade.PositionClose(ticket);
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
   double closePrice[];
   ArraySetAsSeries(closePrice, true);
   CopyClose(Symbol(), PERIOD_CURRENT, 0, 1, closePrice);
   
   Print("======================================");
   Print("الوقت: ", TimeToString(TimeCurrent()));
   Print("عدد الصفقات المفتوحة: ", positions);
   Print("مستوى المضاعفة الحالي: ", martingaleLevel);
   Print("الربح الإجمالي: ", totalProfit);
   Print("أعلى السعر: ", highPrice);
   Print("أدنى السعر: ", lowPrice);
   Print("السعر الحالي: ", closePrice[0]);
   Print("======================================");
}

//+------------------------------------------------------------------+
