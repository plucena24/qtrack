package OPT::OrderStatus;
use strict;
use warnings;
use XML::Simple;
use XML::Parser;
use DBI;
#use Data::Dumper;
use Data::Dump;
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
        my @array1;
        my @array2;
        my @load;
        my @a1 = order_pull();
        my @a2 = order_pull();
        my @keep;

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

            if (@keep) {

                #move data to array1 - change shallow copy to deep copy
                @a1 = map { [ @$_ ] } @a2;

                #print $a1[1][1];

                #replace date time
                foreach my $row (@{keep})
                {
                    $row->[0] =~ s/load_time/$hms/g;
                    #print values $row;
                }

                #insert changese into db
                my @tuple_status;
#                $ins->execute_for_fetch( sub { shift @keep }, \@tuple_status);

            }

            undef @a2;
            undef @load;
            undef @keep;
            undef @array1;
            undef @array2;

            do {
                #loop until you get answer
                @a2 = order_pull(); #$symbol, $simulation
            } while (@a2 == 1);


            for my $i (0..$#a1)
            {
                undef @load;
                @array1 = values $a1[$i];
                @array2 = values $a2[$i];
                @load = compare(\@array1, \@array2);
                if (scalar(grep {defined $_} @load) > 0) {

#                    print "\nchange found - details\n $hms \n";
                    push @keep, $a2[$i];

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

#            print $response->content;

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

#	     my $lastUnderlyingPrice = $ref->{'option-chain-results'}->{'last'};
        my $account_id = $ref->{'balance'}->{'account-id'};
        my $cash_balance_initial = $ref->{'balance'}->{'cash-balance'}->{'initial'};
        my $cash_balance_current = $ref->{'balance'}->{'cash-balance'}->{'current'};
        my $cash_balance_change = $ref->{'balance'}->{'cash-balance'}->{'change'};
        my $mm_balance_initial = $ref->{'balance'}->{'money-market-balance'}->{'initial'};
        my $mm_balance_current = $ref->{'balance'}->{'money-market-balance'}->{'current'};
        my $mm_balance_change = $ref->{'balance'}->{'money-market-balance'}->{'change'};
        my $savings_balance_current = $ref->{'balance'}->{'savings-balance'}->{'current'};
        my $ls_value_initial = $ref->{'balance'}->{'long-stock-value'}->{'initial'};
        my $ls_value_current = $ref->{'balance'}->{'long-stock-value'}->{'current'};
        my $ls_value_change = $ref->{'balance'}->{'long-stock-value'}->{'change'};
        my $lo_value_initial = $ref->{'balance'}->{'long-option-value'}->{'initial'};
        my $lo_value_current = $ref->{'balance'}->{'long-option-value'}->{'current'};
        my $lo_value_change = $ref->{'balance'}->{'long-option-value'}->{'change'};
        my $so_value_initial = $ref->{'balance'}->{'short-option-value'}->{'initial'};
        my $so_value_current = $ref->{'balance'}->{'short-option-value'}->{'current'};
        my $so_value_change = $ref->{'balance'}->{'short-option-value'}->{'change'};
        my $mf_value_initial = $ref->{'balance'}->{'mutual-fund-value'}->{'initial'};
        my $mf_value_current = $ref->{'balance'}->{'mutual-fund-value'}->{'current'};
        my $mf_value_change = $ref->{'balance'}->{'mutual-fund-value'}->{'change'};
        my $bond_value_initial = $ref->{'balance'}->{'bond-value'}->{'initial'};
        my $bond_value_current = $ref->{'balance'}->{'bond-value'}->{'current'};
        my $bond_value_change = $ref->{'balance'}->{'bond-value'}->{'change'};
        my $account_value_initial = $ref->{'balance'}->{'account-value'}->{'initial'};
        my $account_value_current = $ref->{'balance'}->{'account-value'}->{'current'};
        my $account_value_change = $ref->{'balance'}->{'account-value'}->{'change'};
        my $pending_deposits_initial = $ref->{'balance'}->{'pending-deposits'}->{'initial'};
        my $pending_deposits_current = $ref->{'balance'}->{'pending-deposits'}->{'current'};
        my $pending_deposits_change = $ref->{'balance'}->{'pending-deposits'}->{'change'};
        my $in_call = $ref->{'balance'}->{'in-call'};
        my $in_potential_call = $ref->{'balance'}->{'in-potential-call'};

        print "account_id: " . $account_id . "\n";
        print "cash_balance_initial: " . $cash_balance_initial . "\n";
        print "cash_balance_current: " . $cash_balance_current . "\n";
        print "cash_balance_change: " . $cash_balance_change . "\n";
        print "mm_balance_initial: " . $mm_balance_initial . "\n";
        print "mm_balance_current: " . $mm_balance_current . "\n";
        print "mm_balance_change: " . $mm_balance_change . "\n";
        print "savings_balance_current: " . $savings_balance_current . "\n";
        print "ls_value_initial: " . $ls_value_initial . "\n";
        print "ls_value_current: " . $ls_value_current . "\n";
        print "ls_value_change: " . $ls_value_change . "\n";
        print "lo_value_initial: " . $lo_value_initial . "\n";
        print "lo_value_current: " . $lo_value_current . "\n";
        print "lo_value_change: " . $lo_value_change . "\n";
        print "so_value_initial: " . $so_value_initial . "\n";
        print "so_value_current: " . $so_value_current . "\n";
        print "so_value_change: " . $so_value_change . "\n";
        print "mf_value_initial: " . $mf_value_initial . "\n";
        print "mf_value_current: " . $mf_value_current . "\n";
        print "mf_value_change: " . $mf_value_change . "\n";
        print "bond_value_initial: " . $bond_value_initial . "\n";
        print "bond_value_current: " . $bond_value_current . "\n";
        print "bond_value_change: " . $bond_value_change . "\n";
        print "account_value_initial: " . $account_value_initial . "\n";
        print "account_value_current: " . $account_value_current . "\n";
        print "account_value_change: " . $account_value_change . "\n";
        print "pending_deposits_initial: " . $pending_deposits_initial . "\n";
        print "pending_deposits_current: " . $pending_deposits_current . "\n";
        print "pending_deposits_change: " . $pending_deposits_change . "\n";
        print "in_call: " . $in_call . "\n";
        print "in_potential_call: " . $in_potential_call . "\n";

        my $short_balance_initial = $ref->{'balance'}->{'short-balance'}->{'initial'};
        my $short_balance_current = $ref->{'balance'}->{'short-balance'}->{'current'};
        my $short_balance_change = $ref->{'balance'}->{'short-balance'}->{'change'};
        my $margin_balance_initial = $ref->{'balance'}->{'margin-balance'}->{'initial'};
        my $margin_balance_current = $ref->{'balance'}->{'margin-balance'}->{'current'};
        my $margin_balance_change = $ref->{'balance'}->{'margin-balance'}->{'change'};
        my $short_stock_initial = $ref->{'balance'}->{'short-stock-value'}->{'initial'};
        my $short_stock_current = $ref->{'balance'}->{'short-stock-value'}->{'current'};
        my $short_stock_change = $ref->{'balance'}->{'short-stock-value'}->{'change'};
        my $long_marginable_initial = $ref->{'balance'}->{'long-marginable-value'}->{'initial'};
        my $long_marginable_current = $ref->{'balance'}->{'long-marginable-value'}->{'current'};
        my $long_marginable_change = $ref->{'balance'}->{'long-marginable-value'}->{'change'};
        my $short_marginable_initial = $ref->{'balance'}->{'short-marginable-value'}->{'initial'};
        my $short_marginable_current = $ref->{'balance'}->{'short-marginable-value'}->{'current'};
        my $short_marginable_change = $ref->{'balance'}->{'short-marginable-value'}->{'change'};
        my $margin_equity_initial = $ref->{'balance'}->{'margin-equity'}->{'initial'};
        my $margin_equity_current = $ref->{'balance'}->{'margin-equity'}->{'current'};
        my $margin_equity_change = $ref->{'balance'}->{'margin-equity'}->{'change'};
        my $equity_percentage_initial = $ref->{'balance'}->{'equity-percentage'}->{'initial'};
        my $equity_percentage_current = $ref->{'balance'}->{'equity-percentage'}->{'current'};
        my $equity_percentage_change = $ref->{'balance'}->{'equity-percentage'}->{'change'};
        my $option_buying_power = $ref->{'balance'}->{'option-buying-power'};
        my $stock_buying_power = $ref->{'balance'}->{'stock-buying-power'};
        my $day_trading_buying_power = $ref->{'balance'}->{'day-trading-buying-power'};
        my $available_funds_for_trading = $ref->{'balance'}->{'available-funds-for-trading'};
        my $maintenance_req_initial = $ref->{'balance'}->{'maintenance-requirement'}->{'initial'};
        my $maintenance_req_current = $ref->{'balance'}->{'maintenance-requirement'}->{'current'};
        my $maintenance_req_change = $ref->{'balance'}->{'maintenance-requirement'}->{'change'};
        my $maintenance_call_value_initial = $ref->{'balance'}->{'maintenance-call-value'}->{'initial'};
        my $maintenance_call_value_current = $ref->{'balance'}->{'maintenance-call-value'}->{'current'};
        my $maintenance_call_value_potential = $ref->{'balance'}->{'maintenance-call-value'}->{'potential'};
        my $reg_t_call_value_initial = $ref->{'balance'}->{'regulation-t-call-value'}->{'initial'};
        my $reg_t_call_value_current = $ref->{'balance'}->{'regulation-t-call-value'}->{'current'};
        my $reg_t_call_value_potential = $ref->{'balance'}->{'regulation-t-call-value'}->{'potential'};
        my $day_trading_call_value_potential = $ref->{'balance'}->{'day-trading-call-value'}->{'potential'};
        my $day_trading_call_value_initial = $ref->{'balance'}->{'day-trading-call-value'}->{'initial'};
        my $day_equity_call_value = $ref->{'balance'}->{'day-equity-call-value'};



        print "short_balance_initial: " . $short_balance_initial . "\n";
        print "short_balance_current: " . $short_balance_current . "\n";
        print "short_balance_change: " . $short_balance_change . "\n";
        print "margin_balance_initial: " . $margin_balance_initial . "\n";
        print "margin_balance_current: " . $margin_balance_current . "\n";
        print "margin_balance_change: " . $margin_balance_change . "\n";
        print "short_stock_initial: " . $short_stock_initial . "\n";
        print "short_stock_current: " . $short_stock_current . "\n";
        print "short_stock_change: " . $short_stock_change . "\n";
        print "long_marginable_initial: " . $long_marginable_initial . "\n";
        print "long_marginable_current: " . $long_marginable_current . "\n";
        print "long_marginable_change: " . $long_marginable_change . "\n";
        print "short_marginable_initial: " . $short_marginable_initial . "\n";
        print "short_marginable_current: " . $short_marginable_current . "\n";
        print "short_marginable_change: " . $short_marginable_change . "\n";
        print "margin_equity_initial: " . $margin_equity_initial . "\n";
        print "margin_equity_current: " . $margin_equity_current . "\n";
        print "margin_equity_change: " . $margin_equity_change . "\n";
        print "equity_percentage_initial: " . $equity_percentage_initial . "\n";
        print "equity_percentage_current: " . $equity_percentage_current . "\n";
        print "equity_percentage_change: " . $equity_percentage_change . "\n";
        print "option_buying_power: " . $option_buying_power . "\n";
        print "stock_buying_power: " . $stock_buying_power . "\n";
        print "day_trading_buying_power: " . $day_trading_buying_power . "\n";
        print "available_funds_for_trading: " . $available_funds_for_trading . "\n";
        print "maintenance_req_initial: " . $maintenance_req_initial . "\n";
        print "maintenance_req_current: " . $maintenance_req_current . "\n";
        print "maintenance_req_change: " . $maintenance_req_change . "\n";
        print "maintenance_call_value_initial: " . $maintenance_call_value_initial . "\n";
        print "maintenance_call_value_current: " . $maintenance_call_value_current . "\n";
        print "maintenance_call_value_potential: " . $maintenance_call_value_potential . "\n";
        print "reg_t_call_value_initial: " . $reg_t_call_value_initial . "\n";
        print "reg_t_call_value_current: " . $reg_t_call_value_current . "\n";
        print "reg_t_call_value_potential: " . $reg_t_call_value_potential . "\n";
        print "day_trading_call_value_potential: " . $day_trading_call_value_potential . "\n";
        print "day_trading_call_value_initial: " . $day_trading_call_value_initial . "\n";
        print "day_equity_call_value: " . $day_equity_call_value . "\n";


        my @result = @{$ref->{'BalancePositions'}};

        #Declare array to store XML response after being formatted
#        my $array_ref;
        my @array;
#        my $row = 0;
#        my $sc_volume;
#        my $sp_volume;

        #Loop through xml results
        foreach (@result) {

#                my @child = @{$_->{'option-strike'}};

#                foreach (@child) {
#
#                #############################################################################################################
#
#                        my $call_bid = "$_->{call}->{'bid'}";
#                        my $call_ask = "$_->{call}->{'ask'}";
#                        my $put_bid = "$_->{put}->{'bid'}";
#                        my $put_ask = "$_->{put}->{'ask'}";
#                        my $call_delta= "$_->{call}->{'delta'}";
#                        my $put_delta= "$_->{put}->{'delta'}";
#                    	my $call_implied_volatility = "$_->{call}->{'implied-volatility'}";
#                    	my $put_implied_volatility = "$_->{put}->{'implied-volatility'}";
#                        my $call_open_interest = "$_->{call}->{'open-interest'}" || 0;
#                        my $put_open_interest = "$_->{put}->{'open-interest'}" || 0;
#
#                        $call_bid =~ s/([HASH]+)\(([^)]+)\)/0.00/g;
#                        $call_ask =~ s/([HASH]+)\(([^)]+)\)/0.00/g;
#                        $put_bid =~ s/([HASH]+)\(([^)]+)\)/0.00/g;
#                        $put_ask =~ s/([HASH]+)\(([^)]+)\)/0.00/g;
#                        $call_delta =~ s/([HASH]+)\(([^)]+)\)/0.00/g;
#                        $put_delta =~ s/([HASH]+)\(([^)]+)\)/0.00/g;
#                    	$call_implied_volatility =~ s/([HASH]+)\(([^)]+)\)/0.00/g;
#                    	$put_implied_volatility =~ s/([HASH]+)\(([^)]+)\)/0.00/g;
#                        $call_open_interest =~ s/([HASH]+)\(([^)]+)\)/0.00/g;
#                        $put_open_interest =~ s/([HASH]+)\(([^)]+)\)/0.00/g;
#
#                        no warnings;
#
#                        push @{ $array_ref }, "load_time";
#                        push @{ $array_ref }, "$_->{call}->{'option-symbol'}";
#			            push @{ $array_ref }, "$lastUnderlyingPrice";
#                        push @{ $array_ref }, "$call_bid";
#                        push @{ $array_ref }, "$call_ask";
#                        push @{ $array_ref }, "$_->{call}->{'bid-ask-size'}";
#                        push @{ $array_ref }, "$_->{call}->{'last'}";
#                        push @{ $array_ref }, "$call_delta";
#                        push @{ $array_ref }, "$sc_volume";
#			            push @{ $array_ref }, "$call_implied_volatility";
#                        push @{ $array_ref }, "$call_open_interest";
#                        push @{ $array_ref }, "$put_bid";
#                        push @{ $array_ref }, "$put_ask";
#                        push @{ $array_ref }, "$_->{put}->{'bid-ask-size'}";
#                        push @{ $array_ref }, "$_->{put}->{'last'}";
#                        push @{ $array_ref }, "$put_delta";
#                        push @{ $array_ref }, "$sp_volume";
#			            push @{ $array_ref }, "$put_implied_volatility";
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

                }

        return @array;

    }

1;
