DROP TABLE v_optsputnik;
 
 CREATE TABLE v_optsputnik
 (
   load_time character(30),
   call_option_symbol character(50),
   lastUnderlyingPrice double precision,
   call_bid double precision,
   call_ask double precision,
   call_bid_ask_size character(50),
   call_last character(50),
   call_delta double precision,
   call_volume double precision,
   call_implied_volatility double precision,
   call_open_interest double precision,
   put_bid double precision,
   put_ask double precision,
   put_bid_ask_size character(50),
   put_last character(50),
   put_delta double precision,
   put_volume double precision,
   put_implied_volatility DOUBLE PRECISION,
   put_open_interest double precision
 )
 WITH (
   OIDS=FALSE
 );
 ALTER TABLE v_optsputnik
   OWNER TO postgres;
