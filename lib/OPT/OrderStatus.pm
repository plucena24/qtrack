package OPT::OrderStatus;
use strict;
use warnings;
use XML::Simple;
use XML::Parser;
use DBI;
#use Data::Dumper;
use Data::Dump 'dump';
use LWP::UserAgent;
use DateTime;
use Benchmark qw( cmpthese );
use threads;
use threads::shared;


use Exporter qw(import);
#use Exporter;
#use base qw( Exporter );

#our \@ISA= qw( Exporter );
our @EXPORT_OK = qw( trackOrderStatus );
#our $VERSION = '0.01';
#our @EXPORT = qw( launchChainSputnik );

sub trackOrderStatus
{

        #############################################################################################################
        #set variables
        #############################################################################################################
        my @sarray1;
        my @sarray2;
        my @sload;
        my @skeep;
        my @oarray1;
        my @oarray2;
        my @oload;
        my @okeep;

        my (@sa1, @oa1) = order_pull();
        my (@sa2, @oa2) = order_pull();

        #############################################################################################################
        #connect to db
        #############################################################################################################
        #Connect to SQL SERVER for insert
        my ($dbInfo, $pguser, $pgpass) = split /~/, get_credentials("/home/zad0xlik/.qtrack_pg.conf");

        my $dbh2 = DBI->connect($dbInfo,
            $pguser,
            $pgpass,
            {AutoCommit=>1,RaiseError=>1,PrintError=>0}
        ) || die "Database connection not made: $DBI::errstr";

#        my $ins = $dbh2->prepare("INSERT INTO ". $table ." (load_time, call_option_symbol, lastUnderlyingPrice, call_bid, call_ask, call_bid_ask_size, call_last, call_delta, call_volume, call_implied_volatility, call_open_interest, put_bid, put_ask, put_bid_ask_size, put_last, put_delta, put_volume, put_implied_volatility, put_open_interest) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
        #############################################################################################################

        while (42) {

            my $dt = DateTime->now( time_zone => 'America/New_York' );
            #print "$dt \n";

            my $hms = $dt->hms;

            if (@skeep) {

                #move data to array1 - change shallow copy to deep copy
                @sa1 = map { [ @$_ ] } @sa2;

                #print $a1[1][1];

                #replace date time
                foreach my $row (@{skeep})
                {
                    $row->[0] =~ s/load_time/$hms/g;
                    #print values $row;
                }

                #insert changese into db
                my @stuple_status;
#                $sins->execute_for_fetch( sub { shift @skeep }, \@stuple_status);

            }

            if (@okeep) {

                #move data to array1 - change shallow copy to deep copy
                @oa1 = map { [ @$_ ] } @oa2;

                #print $a1[1][1];

                #replace date time
                foreach my $row (@{okeep})
                {
                    $row->[0] =~ s/load_time/$hms/g;
                    #print values $row;
                }

                #insert changese into db
                my @otuple_status;
#                $oins->execute_for_fetch( sub { shift @okeep }, \@otuple_status);

            }

            undef @sa2;
            undef @oa2;
            undef @sload;
            undef @oload;
            undef @skeep;
            undef @okeep;
            undef @sarray1;
            undef @sarray2;
            undef @oarray1;
            undef @oarray2;


            do {
                #loop until you get answer
#                @a2 = order_pull();
                (@sa2,  @oa2) = order_pull();
            } while (@sa2 == 1);


            for my $i (0..$#sa1)
            {
                undef @sload;
                @sarray1 = values $sa1[$i];
                @sarray2 = values $sa2[$i];
                @sload = compare(\@sarray1, \@sarray2);
                if (scalar(grep {defined $_} @sload) > 0) {

                    push @skeep, $sa2[$i];

                }
            }

            for my $i (0..$#oa1)
            {
                undef @oload;
                @oarray1 = values $oa1[$i];
                @oarray2 = values $oa2[$i];
                @oload = compare(\@oarray1, \@oarray2);
                if (scalar(grep {defined $_} @oload) > 0) {

                    push @okeep, $oa2[$i];

                }
            }

        }

 }

    #############################################################################################################
    #thread requests - also this should set PERL_DESTRUCT_LEVEL to 2 - to give memory back
    #############################################################################################################

    sub get_credentials {
        my ($file) = @_;
        open my $fh, "<", $file or die $!;

        my $line = <$fh>;
        chomp($line);
        return ($line)
    }

    #############################################################################################################
    #compare two arrays to see if anything has changed
    #############################################################################################################
    sub compare{

	my (@array1, @array2) = @_;
        my @intersection = ();
        my @difference = ();
        my %count = ();
        
        foreach my $element (@array1, @array2) { $count{$element}++ }
        foreach my $element (keys %count) {
            push @{ $count{$element} > 1 ? \@intersection : \@difference }, $element;
        };
            
        return @difference;
        
    }


    #############################################################################################################
    #subroutine for pulling option chains
    #############################################################################################################
    sub order_pull{

        my $ua = LWP::UserAgent->new();

        $ua->cookie_jar({});

        my ($source, $userid, $pass) = split /~/, get_credentials("/home/zad0xlik/.qtrack.conf");

        #Make a https request
        my $url = 'https://apis.tdameritrade.com/apps/200/LogIn?source='.$source.'&version=1.0';
        my $response = $ua->post($url,
                                      [
                                       'userid'   => $userid,
                                       'password' => $pass,
                                       'source'   => $source,
                                       'version'  => "1.0",
                                      ],
                                      'Content-Type' => "application/x-www-form-urlencoded",
                                     );

        $url = 'https://apis.tdameritrade.com/apps/100/BalancesAndPositions?source='.$source;


        $response = $ua->get($url); die "can't get $url --", $response->status_line
            unless $response->is_success;


        my $xs = XML::Simple->new();
        my $ref; # = $xs->XMLin($response->content, ForceArray => ['optionchain'], KeyAttr => {});

        #if server doesnt reply leave sub and try again
        if ($response->is_success) {

            $ref = $xs->XMLin($response->content, ForceArray => ['BalancePositions'], KeyAttr => {});

            print $response->content;

        } else {
                print "\n ...server not reached...\n";
                return 1;
        }

        #check if anyhing came back else exist and re-request
        #unless (@{ $val // [] }) {
        #... # stuff to do if the array is empty
        #}
        if (not defined $ref->{'balance'}) {
                print "\n no results came back\n";
                return 1;
        }

        my $cash_balance_current = $ref->{'balance'}->{'cash-balance'}->{'current'};
        print "cash_balance_current: " . $cash_balance_current . "\n";
        my $margin_balance_current = $ref->{'balance'}->{'margin-balance'}->{'current'};
        print "margin_balance_current: " . $margin_balance_current . "\n";
        my $account_value_current = $ref->{'balance'}->{'account-value'}->{'current'};
        print "account_value_current: " . $account_value_current . "\n";


        my @stocks = $ref->{'positions'}->{'stocks'}->{'position'};

        my @sarray;
        my $stocks_ref;
        my $srow = 0;
        foreach(@stocks)
        {

            my @position = @{$_};

                foreach(@position)
                {
                    my $stocks_position_type =  $_->{'position-type'};
                    print "stocks_position_type: " . $stocks_position_type . "\n";

                    my $stocks_quantity =  $_->{'quantity'};
                    print "stocks_quantity: " . $stocks_quantity . "\n";

                    my @quote = $_->{'quote'};
                    foreach (@quote)
                    {
                        my $stock_symbol = $_->{'symbol'};
                        print "stock_symbol: " . $stock_symbol . "\n";


                        my $stock_last = $_->{'last'};
                        print "stock_last: " . $stock_last . "\n";

                        push @{ $stocks_ref }, "load_time";
                        push @{ $stocks_ref }, "$cash_balance_current";
                        push @{ $stocks_ref }, "$margin_balance_current";
                        push @{ $stocks_ref }, "$account_value_current";
                        push @{ $stocks_ref }, "$stock_symbol";
                        push @{ $stocks_ref }, "$stocks_position_type";
                        push @{ $stocks_ref }, "$stocks_quantity";
                        push @{ $stocks_ref }, "$stock_last";

                        foreach my $stocks_ref (@{$stocks_ref})
                        {
                            $stocks_ref =~ s/([HASH]+)\(([^)]+)\)//g;
                        }
                        push @{$sarray[$srow]}, @{ $stocks_ref };
                        $srow++;

                        @{ $stocks_ref } = ();
                    }

#                    dump $_;
                }

            print "------------------------------------\n"

        }

        my @options = $ref->{'positions'}->{'options'}->{'position'};

        my @oarray;
        my $options_ref;
        my $orow = 0;

        foreach(@options)
        {

            my @position = @{$_};

            foreach(@position)
            {

                my $options_quantity =  $_->{'quantity'};
                print "options_quantity: " . $options_quantity . "\n";

                my $options_position_type = $_->{'position-type'};
                print "options_position_type: " . $options_position_type . "\n";

                my $options_average_price = $_->{'average-price'};
                print "options_average_price: " . $options_average_price . "\n";

                my $options_current_value = $_->{'current-value'};
                print "options_current_value: " . $options_current_value . "\n";

                my $options_put_call = $_->{'put-call'};
                print "options_put_call: " . $options_put_call . "\n";


                my @quote = $_->{'quote'};
                foreach (@quote)
                {

                    my $options_symbol = $_->{'symbol'};
                    print "options_symbol: " . $options_symbol . "\n";

                    my $options_last = $_->{'last'};
                    print "options_last: " . $options_last . "\n";

                    push @{ $options_ref }, "load_time";
                    push @{ $options_ref }, "$cash_balance_current";
                    push @{ $options_ref }, "$margin_balance_current";
                    push @{ $options_ref }, "$account_value_current";
                    push @{ $options_ref }, "$options_symbol";
                    push @{ $options_ref }, "$options_quantity";
                    push @{ $options_ref }, "$options_position_type";
                    push @{ $options_ref }, "$options_average_price";
                    push @{ $options_ref }, "$options_current_value";
                    push @{ $options_ref }, "$options_put_call";
                    push @{ $options_ref }, "$options_last";

                    foreach my $options_ref (@{$options_ref})
                    {
                        $options_ref =~ s/([HASH]+)\(([^)]+)\)//g;
                    }
                    push @{$oarray[$orow]}, @{ $options_ref };
                    $orow++;

                    @{ $options_ref } = ();

                }

            }

#            dump $_;
        }

        return (@sarray, @oarray);

    }

1;

#        print "stock_quantity: " . $stock_quantity . "\n";

#        my @result = $ref->{'positions'}->{'stocks'};
#        print $ref->{'positions'}->{'stocks'}->{'position'}->{'quantity'};

#        print "--------------------------------- \n";
        #Declare array to store XML response after being formatted

#        my $array_ref;
#        my @array;
#        my $row = 0;
#        my $sc_volume;
#        my $sp_volume;

        #Loop through xml results
#        foreach (@result) {

#                my @child = @{$_->{'option-strike'}};

#                foreach (@child) {
#
#                #############################################################################################################

#                        my $quantity = "$_->{'position'}->{'quantity'}";
#                        print "--------------------------------- \n";
#                        print "quantity: " . $quantity . "\n";
#
#                        my $call_bid = "$_->{call}->{'bid'}";
#                        my $call_ask = "$_->{call}->{'ask'}";
#                        my $put_bid = "$_->{put}->{'bid'}";
#                        my $put_ask = "$_->{put}->{'ask'}";
#                        my $call_delta= "$_->{call}->{'delta'}";
#                        my $put_delta= "$_->{put}->{'delta'}";
#                    	 my $call_implied_volatility = "$_->{call}->{'implied-volatility'}";
#                    	 my $put_implied_volatility = "$_->{put}->{'implied-volatility'}";
#                        my $call_open_interest = "$_->{call}->{'open-interest'}" || 0;
#                        my $put_open_interest = "$_->{put}->{'open-interest'}" || 0;
#
#                        $call_bid =~ s/([HASH]+)\(([^)]+)\)/0.00/g;
#                        $call_ask =~ s/([HASH]+)\(([^)]+)\)/0.00/g;
#                        $put_bid =~ s/([HASH]+)\(([^)]+)\)/0.00/g;
#                        $put_ask =~ s/([HASH]+)\(([^)]+)\)/0.00/g;
#                        $call_delta =~ s/([HASH]+)\(([^)]+)\)/0.00/g;
#                        $put_delta =~ s/([HASH]+)\(([^)]+)\)/0.00/g;
#                    	 $call_implied_volatility =~ s/([HASH]+)\(([^)]+)\)/0.00/g;
#                    	 $put_implied_volatility =~ s/([HASH]+)\(([^)]+)\)/0.00/g;
#                        $call_open_interest =~ s/([HASH]+)\(([^)]+)\)/0.00/g;
#                        $put_open_interest =~ s/([HASH]+)\(([^)]+)\)/0.00/g;
#
#                        no warnings;
#
#                        push @{ $array_ref }, "load_time";
#                        push @{ $array_ref }, "$_->{call}->{'option-symbol'}";
#			             push @{ $array_ref }, "$lastUnderlyingPrice";
#                        push @{ $array_ref }, "$call_bid";
#                        push @{ $array_ref }, "$call_ask";
#                        push @{ $array_ref }, "$_->{call}->{'bid-ask-size'}";
#                        push @{ $array_ref }, "$_->{call}->{'last'}";
#                        push @{ $array_ref }, "$call_delta";
#                        push @{ $array_ref }, "$sc_volume";
#                        push @{ $array_ref }, "$call_implied_volatility";
#                        push @{ $array_ref }, "$call_open_interest";
#                        push @{ $array_ref }, "$put_bid";
#                        push @{ $array_ref }, "$put_ask";
#                        push @{ $array_ref }, "$_->{put}->{'bid-ask-size'}";
#                        push @{ $array_ref }, "$_->{put}->{'last'}";
#                        push @{ $array_ref }, "$put_delta";
#                        push @{ $array_ref }, "$sp_volume";
#			             push @{ $array_ref }, "$put_implied_volatility";
#                        push @{ $array_ref }, "$put_open_interest";
#
#                    use warnings;
#
#                        foreach my $array_ref (@{$array_ref})
#                        {
#                                $array_ref =~ s/([HASH]+)\(([^)]+)\)//g;
#                        }
#                        push @{$array[$row]}, @{ $array_ref };
#                        $row++;
#
#                        @{ $array_ref } = ();
#
#                        }

#                }


