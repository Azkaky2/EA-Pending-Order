//+------------------------------------------------------------------+
//|   EA Pending Order untuk MT5 - XAUUSD                           |
//|   Versi: 2.0 (Stabil & Testing Ready)                           |
//+------------------------------------------------------------------+
#property strict
#property version   "2.0"
#property description "EA Pending Order dengan Hidden SL/TP & Trailing Stop"

#include <Trade/Trade.mqh>

CTrade trade;

//--- Input Parameters
input double    Lot_Size            = 0.10;         // Ukuran lot
input double    BuyStop_Distance    = 50;           // Jarak Buy Stop (pips)
input double    SellStop_Distance   = 50;           // Jarak Sell Stop (pips)
input double    StopLoss_Pips       = 30;           // Stop Loss (pips)
input double    TakeProfit_Pips     = 60;           // Take Profit (pips)
input double    TrailingStop_Pips   = 20;           // Trailing Stop (pips)
input int       MaxSpread_Points    = 30;           // Spread Max (points)
input int       Start_Hour          = 8;            // Jam mulai
input int       End_Hour            = 22;           // Jam selesai
input bool      Enable_Buy          = true;         // Aktifkan Buy
input bool      Enable_Sell         = true;         // Aktifkan Sell

string TARGET_SYMBOL = "XAUUSD";

//--- Global Variables
double lastBuyPrice = 0;
double lastSellPrice = 0;
double trailingStopBuy = 0;
double trailingStopSell = 0;

//+------------------------------------------------------------------+
//| OnInit
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(2024);  // Magic number untuk tracking
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnDeinit
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Comment("");  // Clear comments
}

//+------------------------------------------------------------------+
//| OnTick
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Hanya operasi di symbol yang ditargetkan
   if(_Symbol != TARGET_SYMBOL)
      return;

   //--- Cek apakah dalam jam trading
   if(!IsWithinTradingHours())
      return;

   //--- Ambil data harga terkini
   double ask = SymbolInfoDouble(TARGET_SYMBOL, SYMBOL_ASK);
   double bid = SymbolInfoDouble(TARGET_SYMBOL, SYMBOL_BID);
   int spread = (int)SymbolInfoInteger(TARGET_SYMBOL, SYMBOL_SPREAD);

   //--- Cek spread
   if(spread > MaxSpread_Points)
      return;

   //--- Update trailing stop
   UpdateTrailingStop(ask, bid);

   //--- Buka posisi baru jika tidak ada posisi
   if(CountPositions() == 0)
   {
      //--- BUY STOP ORDER
      if(Enable_Buy && ask > bid)
      {
         double buyStopPrice = ask + (BuyStop_Distance * _Point);
         lastBuyPrice = buyStopPrice;
         trailingStopBuy = buyStopPrice - (StopLoss_Pips * _Point);
      }

      //--- SELL STOP ORDER
      if(Enable_Sell && bid < ask)
      {
         double sellStopPrice = bid - (SellStop_Distance * _Point);
         lastSellPrice = sellStopPrice;
         trailingStopSell = sellStopPrice + (StopLoss_Pips * _Point);
      }

      //--- Eksekusi BUY jika kondisi terpenuhi
      if(Enable_Buy && ask >= lastBuyPrice && lastBuyPrice > 0)
      {
         ExecuteBuyTrade(ask);
         lastBuyPrice = 0;
      }

      //--- Eksekusi SELL jika kondisi terpenuhi
      if(Enable_Sell && bid <= lastSellPrice && lastSellPrice > 0)
      {
         ExecuteSellTrade(bid);
         lastSellPrice = 0;
      }
   }

   //--- Manage posisi terbuka
   ManageOpenPositions(ask, bid);

   //--- Update Comment di chart
   UpdateComment(ask, bid, spread);
}

//+------------------------------------------------------------------+
//| IsWithinTradingHours
//+------------------------------------------------------------------+
bool IsWithinTradingHours()
{
   int currentHour = (int)TimeHour(TimeCurrent());
   return (currentHour >= Start_Hour && currentHour < End_Hour);
}

//+------------------------------------------------------------------+
//| CountPositions
//+------------------------------------------------------------------+
int CountPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByIndex(i))
      {
         if(PositionGetString(POSITION_SYMBOL) == TARGET_SYMBOL && 
            PositionGetInteger(POSITION_MAGIC) == 2024)
         {
            count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| ExecuteBuyTrade
//+------------------------------------------------------------------+
void ExecuteBuyTrade(double entryPrice)
{
   double sl = entryPrice - (StopLoss_Pips * _Point);
   double tp = entryPrice + (TakeProfit_Pips * _Point);

   if(!trade.Buy(Lot_Size, TARGET_SYMBOL, entryPrice, sl, tp, "Buy Order"))
   {
      PrintFormat("BUY FAILED: %s", trade.ResultComment());
   }
   else
   {
      PrintFormat("BUY SUCCESS at %.2f", entryPrice);
      trailingStopBuy = sl;
   }
}

//+------------------------------------------------------------------+
//| ExecuteSellTrade
//+------------------------------------------------------------------+
void ExecuteSellTrade(double entryPrice)
{
   double sl = entryPrice + (StopLoss_Pips * _Point);
   double tp = entryPrice - (TakeProfit_Pips * _Point);

   if(!trade.Sell(Lot_Size, TARGET_SYMBOL, entryPrice, sl, tp, "Sell Order"))
   {
      PrintFormat("SELL FAILED: %s", trade.ResultComment());
   }
   else
   {
      PrintFormat("SELL SUCCESS at %.2f", entryPrice);
      trailingStopSell = sl;
   }
}

//+------------------------------------------------------------------+
//| UpdateTrailingStop
//+------------------------------------------------------------------+
void UpdateTrailingStop(double ask, double bid)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByIndex(i))
      {
         if(PositionGetString(POSITION_SYMBOL) != TARGET_SYMBOL)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != 2024)
            continue;

         int posType = (int)PositionGetInteger(POSITION_TYPE);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentSL = PositionGetDouble(POSITION_SL);

         //--- BUY Position Trailing Stop
         if(posType == POSITION_TYPE_BUY)
         {
            double profit = bid - openPrice;
            double newSL = bid - (TrailingStop_Pips * _Point);

            if(profit > (TrailingStop_Pips * _Point) && newSL > currentSL)
            {
               trade.PositionModify(PositionGetInteger(POSITION_TICKET), newSL, PositionGetDouble(POSITION_TP));
            }
         }

         //--- SELL Position Trailing Stop
         else if(posType == POSITION_TYPE_SELL)
         {
            double profit = openPrice - ask;
            double newSL = ask + (TrailingStop_Pips * _Point);

            if(profit > (TrailingStop_Pips * _Point) && newSL < currentSL)
            {
               trade.PositionModify(PositionGetInteger(POSITION_TICKET), newSL, PositionGetDouble(POSITION_TP));
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| ManageOpenPositions
//+------------------------------------------------------------------+
void ManageOpenPositions(double ask, double bid)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByIndex(i))
      {
         if(PositionGetString(POSITION_SYMBOL) != TARGET_SYMBOL)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != 2024)
            continue;

         ulong ticket = PositionGetInteger(POSITION_TICKET);
         int posType = (int)PositionGetInteger(POSITION_TYPE);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentPrice = (posType == POSITION_TYPE_BUY) ? bid : ask;

         //--- Hitung P&L
         double pnl = (posType == POSITION_TYPE_BUY) ? 
                      (currentPrice - openPrice) : 
                      (openPrice - currentPrice);

         //--- STOP LOSS
         if(pnl <= -(StopLoss_Pips * _Point))
         {
            trade.PositionClose(ticket);
            PrintFormat("CLOSE SL: Ticket %d | PnL: %.2f pips", ticket, pnl / _Point);
            continue;
         }

         //--- TAKE PROFIT
         if(pnl >= (TakeProfit_Pips * _Point))
         {
            trade.PositionClose(ticket);
            PrintFormat("CLOSE TP: Ticket %d | PnL: %.2f pips", ticket, pnl / _Point);
            continue;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| UpdateComment - Info di Chart
//+------------------------------------------------------------------+
void UpdateComment(double ask, double bid, int spread)
{
   string comment = "";
   comment += "=== EA Pending Order ===\n";
   comment += StringFormat("Symbol: %s\n", TARGET_SYMBOL);
   comment += StringFormat("Ask: %.2f | Bid: %.2f\n", ask, bid);
   comment += StringFormat("Spread: %d points\n", spread);
   comment += StringFormat("Positions: %d\n", CountPositions());
   comment += StringFormat("Status: %s\n", IsWithinTradingHours() ? "Trading" : "OFF");
   comment += StringFormat("Time: %s\n", TimeToString(TimeCurrent()));

   Comment(comment);
}
