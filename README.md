## Qtrack - Options Tick Tracking

#### Re-Development Instructions from Perl to Python:
Code needs to be ported over from Perl to Python. The redevelopment process will be done in batches and each batch should be done in a cadence right after another and NOT simultaneously.

##### Batch I:
###### 1. Setup Postgres Database (latest stable version) instance and create database called 'QTRACK' - this is where all the information will be loaded from received from the TD API server
###### 2. Go to 'slq' folder in this repository and use schema in 'schema_optsputnik.sql' to create 26 tables in the database where each table would store information for stocks starting with its first leter, so one table per letter of the alphabet (a,b,c,d,e...x,y,z)
###### 3. The naming of the table will be the first letter of the stock then '_optsputnik' as the remaining name (a_optsputnik, b_optsputnik... z_optsputnik); this is why '&symbol' in '&symbols_optsputnik' is a reference for each letter of the alphabet as the tables get created.
###### 4. The process for steps 2 and 3 should not be done manually and there should be a class written in Python to execute the 'schema_optsputnik.sql' for all letters in the alphabet
###### 5. After all the tables are created, you will need to recode a Perl Module called 'MultChainSputnik.pm' (you can split this class into smaller sub-classes in Python); This code will retrieve information from TD API server, transform it into the format that has been declared in the database and load it into correspoding table of the first letter the stock into the table that start with the same letter.





#### OptionChain Request:

##### Request URL:
```https://apis.tdameritrade.com/apps/200/OptionChain?source=<#sourceID#>&symbol=<#symbol#>```

##### Parameters:
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

<br>
<br>

#### OptionChain Response (With Quotes):
-----------------

|XML Attribute |Type|Definitions|
|--------------|:---------|:------|
|XML Attribute Name|Type|Definitions|
|result|String|Contains the overall result for the request.<br>OK - indicates the request was successful<br>FAIL - indicates the request was unsuccessful.|
|option-chain-results|Complex|Container for all the option chain info|
|error|String|Contains an error message| if any. For example| **The Security Symbol is Invalid.**|
|symbol|String|Symbol of the security being quoted.  For example| **DELL**|
|description|String|"Contains a description of the symbol. For example| **TD AMERITRADE HLDG CORP COM**"|
|bid|Double|Underlying Symbol - BID|
|ask|Double|Underlying Symbol - ASK|
|bid-ask-size|String|Underlying Symbol - bid/ask Size <br>The value is displayed as **bid qty X ask qty**. For example, **390X41**
|last|Double|Underlying Symbol - The price of the last trade|
|open|Double|Underlying Symbol - The price of the first trade at normal market open.|
|high|Double|Underlying Symbol - The highest price trade for the symbol during the normal trading session|
|low|Double|Underlying Symbol - The lowest price trade for the symbol during the normal trading session.|
|close|Double|Underlying Symbol - The price of the last trade for the symbol at the end of the previous trading session.|
|volume|Integer|Underlying Symbol - The number of shares traded for the symbol.|
|change|Double|Underlying Symbol - **CHANGE**|
|quote-punctuality|String|**R or D** - Real-time or Delayed|
|time|String|Last Trade Time for the quote|
|option-date|Complex|Container for all the option chain data for a particular option expiration date|
|date|String|The options expiration date in **YYYYMMDD** format|
|expiration-type|String|**R or L** - Regular or LEAP|
|days-to-expiration|Integer|Number of days till the options expire|
|option-strike|Complex|Container for the options at a given strike price|
|strike-price|Double|Option Strike Price|
|standard-option|String|**true/false** - indicates if the options in question are standard or non-standard|
|put|Complex|Container for the fields describing the PUT option symbol at the given date and strike price|
call|Complex|Container for the fields describing the CALL option symbol at the given date and strike price
option-symbol|String|The option symbol
description|String|The option symbol description
bid|Double| 
ask|Double| 
bid-ask-size|String| 
last|Double| 
last-trade-date|String| 
volume|Integer| 
open-interest|Integer| 
real-time|String| 
underlying-symbol|String| 
delta|Double| 
gamma|Double| 
theta|Double| 
vega|Double| 
rho|Double| 
implied-volatility|Double| 
time-value-index|Double| 
multiplier|Integer| 
change|Double| 
change-percent|String| 
in-the-money|String|**true/false**
near-the-money|String|**true/false**
theoretica-value|Double| 
deliverable-list|Complex|Container for Deliverables
notes-description|String|For non-standard options this describes what needs to be delivered. For example:**$600.0cash in lieu of shares, 100 shares of AMTD**
cash-in-lieu-dollar-amount|Double| 
cash-dollar-amount|Double| 
index-option|String|**true/false**
row|Complex|Container
   symbol|String| 
   shares|Integer| 
