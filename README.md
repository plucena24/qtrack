## Qtrack - Options Tick Tracking

### OptionChain Request:

#### Request URL:
```https://apis.tdameritrade.com/apps/200/OptionChain?source=<#sourceID#>&symbol=<#symbol#>```

#### Parameters:
The symbol parameter contains the underlying symbol for the option chain being requested.

|PARAMETER|DESCRIPTION|REQUIRED|POSSIBLE VALUES|
|---------|:---------|:------:|:-------------|
|source|The Application ID of the software client assigned by Ameritrade.|YES|The value is assigned by TD AMERITRADE to the application developer for the specific application|
|symbol|The underlying symbol for the option chain|YES|Can be a stock, or index symbol. Standard TD AMERITRADE symbology applies.|
type|The option chain type.  If the type is not included, then both calls and puts will be returned.|NO|If type is not specified, calls and puts are returned. Otherwise: <br> * **C** - Only Calls <br> * **P** - Only Puts <br> * **VCS** - Vertical Call Spread <br> * **VPS** - Vertical Put Spread <br> * **CCS** - Calendar Call Spread <br> * **CPS** - Calendar Put Spread <br> * **BW** - Buy/Write<br> * **STDL** - Straddle <br> * **STGL** - Strangle|
interval|The interval or Spread for Vertical Spreads and Strangles|NO|Only required for Vertical Spreads and Strangles requests|
strike|The option chain strike price. If the strike price is not included, then all strike prices will be returned.|NO| A valid strike price, e.g. 15 or 17.5 <br>A valid strike price will return those calls and puts for that strike price. <br>An invalid strike price will return no data.|
|expire| The option expiration.  If the expiration is not included or has a value of AL, then all standard months and leap months will be included.|NO *| **al, a, l, w** <br> or a date matching the YYYYMM pattern <br> **AL** = ALL+Leaps, including Weeklies A = All standard expirations, including Weeklies <br> **L** = leap expirations<br> **W** = weeklies only (this is only supported for a few index options).<br> **YYYYMM** = returns only the option month requests.  A date that doesn’t have options will return an empty data set.<br><br> * Required for Vertical Spreads|
|range|The Strike Price range of the options to be returned|NO|**N** - Near The Money <br> **I** - In The Money <br> **O** - Out of The Money <br> **ALL** - All <br><br>The following are for use with Straddes and Strangles: <br> **SNK** - Strikes Near Market <br> **SBK** - Strikes Below Market <br> **SAK** - Strikes Above Market|
|neardate|for use with Calendar spreads|NO|YYYYMM Format date|
|fardate|for use with Calendar spreads|NO|YYYYMM Format date|
|quotes|A flag to request quote data.  The default behavior is not to send quote data.|NO| **true/false**|
