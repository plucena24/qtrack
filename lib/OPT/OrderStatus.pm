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

my $stable = 'balpos_stocks';
my $otable = 'balpos_options';

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

#        my (@sa1, @oa1) = order_pull();
        my ($sarray, $oarray)  = order_pull();
            my @sa1 = @{$sarray};
            my @oa1 = @{$oarray};
        my @sa2;
        my @oa2;

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

        my $sins = $dbh2->prepare("INSERT INTO ". $stable ." (load_time, cash_balance_current, margin_balance_current, account_value_current, symbol, position_type, quantity, last) VALUES(?, ?, ?, ?, ?, ?, ?, ?)");
        my $oins = $dbh2->prepare("INSERT INTO ". $otable ." (load_time, cash_balance_current, margin_balance_current, account_value_current, symbol, quantity, position_type, average_price, current_value, put_call, last) VALUES( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
        #############################################################################################################

        while (42) {

            my $dt = DateTime->now( time_zone => 'America/New_York' );

            my $hms = $dt->hms;

            if (@skeep) {

                #move data to array1 - change shallow copy to deep copy
                @sa1 = map { [ @$_ ] } @sa2;

                #print $a1[1][1];

                #replace date time
                foreach my $row (@{skeep})
                {
                    $row->[0] =~ s/load_time/$hms/g;
                }

                #insert changese into db
                my @tuple_status;
                $sins->execute_for_fetch( sub { shift @skeep }, \@tuple_status);

            }

            if (@okeep) {

                #move data to array1 - change shallow copy to deep copy
                @oa1 = map { [ @$_ ] } @oa2;

                #replace date time
                foreach my $row (@{okeep})
                {
                    $row->[0] =~ s/load_time/$hms/g;
                }

                #insert changese into db
                my @otuple_status;
                $oins->execute_for_fetch( sub { shift @okeep }, \@otuple_status);

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
                ($sarray, $oarray) = order_pull();
                @sa2 = @{$sarray};
                @oa2 = @{$oarray};

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

            for my $x (0..$#oa1)
            {
                undef @oload;

                @oarray1 = @{$oa1[$x]};
                @oarray2 = @{$oa2[$x]};

                @oload = compare(\@oarray1, \@oarray2);
                if (scalar(grep {defined $_} @oload) > 0) {

                    print "\n array 1 - ";
#                    print values @{$oa1[$x]};
                    print @{oarray1};

                    print "\n array 2 - ";
#                    print values @{$oa1[$x]};
                    print @{oarray2};

                    foreach (@oload)
                    {
                        print "\n array diff - \n";
                        print @_;
                    }


                    push @okeep, $oa2[$x];

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

	my (@oarray1, @oarray2) = @_;
        my @intersection = ();
        my @difference = ();
        my %count = ();
        
        foreach my $element (@oarray1, @oarray2) { $count{$element}++ }
        foreach my $element (keys %count) {
            push @{ $count{$element} > 1 ? \@intersection : \@difference }, $element;
#            print "XXX -> ";
#            print values @{$difference[0]};
#            print "<- XXX";
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
        if (not defined $ref->{'balance'}) {
                print "\n no results came back\n";
                return 1;
        }

        my $cash_balance_current = $ref->{'balance'}->{'cash-balance'}->{'current'};
        my $margin_balance_current = $ref->{'balance'}->{'margin-balance'}->{'current'};
        my $account_value_current = $ref->{'balance'}->{'account-value'}->{'current'};

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
                    my $stocks_quantity =  $_->{'quantity'}; # + int(rand(90));

                    my @quote = $_->{'quote'};
                    foreach (@quote)
                    {
                        my $stock_symbol = $_->{'symbol'};
                        my $stock_last = $_->{'last'};

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

                }

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

                my $options_quantity =  $_->{'quantity'}; # + int(rand(90));
                my $options_position_type = $_->{'position-type'};
                my $options_average_price = $_->{'average-price'};
                my $options_current_value = $_->{'current-value'};
                my $options_put_call = $_->{'put-call'};

                my @quote = $_->{'quote'};
                foreach (@quote)
                {

                    my $options_symbol = $_->{'symbol'};
                    my $options_last = $_->{'last'};

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

        }

        return (\@sarray, \@oarray);

    }

1;
