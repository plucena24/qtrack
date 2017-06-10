#!/usr/bin/perl
package OPT::MultChainSpuntik;

use strict;
use warnings;
use XML::Simple;
use XML::Parser;
use DBI;
use Data::Dumper;
use LWP::UserAgent;
use DateTime;
use Benchmark qw( cmpthese );
use threads;
use threads::shared;

use Exporter qw(import);
our @EXPORT_OK = qw(launchChainSputnik get_credentials);

    sub launchChainSputnik {

#        my $symbol = $ARGV[0];
#        my $table = $ARGV[1];
#        my $simulation = 1;

        #############################################################################################################
        #set variables
        #############################################################################################################
        my @array1;
        my @array2;
        my @load;
        my @a1 = chain_pull($symbol, $simulation);
        my @a2 = chain_pull($symbol, $simulation);
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


        my $ins = $dbh2->prepare("INSERT INTO ". $table ." (load_time, call_option_symbol, call_bid, call_ask, call_bid_ask_size, call_last, call_delta, call_volume, call_open_interest, put_bid, put_ask, put_bid_ask_size, put_last, put_delta, put_volume, put_open_interest) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
        #load_time, call_option_symbol, call_bid, call_ask, call_bid_ask_size, call_last, call_delta, call_volume, put_bid, put_ask, put_bid_ask_size, put_last, put_delta, put_volume
        #?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
        #############################################################################################################


        #############################################################################################################
        #run loop to ping server - get new data
        #if (array is not empty) {
        #       the print
        #   } else {request again from server}
        #############################################################################################################


        #my $counter = 1;

        #while ($counter >= 0) {
        while (42) {

            #Declare timestamp
            #1. combine load_date with date_time
            #2. move timestampt to est time zone
            #my $dt = DateTime->now;
            my $dt = DateTime->now( time_zone => 'America/New_York' );
            #print "$dt \n";

            #my $ymd = $dt->ymd('/');
            my $hms = $dt->hms;

            if (@keep) {

                #move data to array1 - change shallow copy to deep copy
                #shallow copy: @a1 = @a2; copies only the references
                #deep copy: @a1 = dclone(@a2); or @a1 = map { [ @$_ ] } @a2; copies underlying data - takes more resources
                #@a1 = @a2;
                @a1 = map { [ @$_ ] } @a2;

                #print $a1[1][1];

                #replace date time
                foreach my $row (@{keep})
                {
                    #$row->[0] =~ s/load_date/$ymd/g;
                    $row->[0] =~ s/load_time/$hms/g;
                    #print values $row;
                }

                #insert changese into db
                my @tuple_status;
                $ins->execute_for_fetch( sub { shift @keep }, \@tuple_status);

            }

            undef @a2;
            undef @load;
            undef @keep;
            undef @array1;
            undef @array2;

            #$simulation = 0; #= int(rand(2)); #set back to 0 for market after hours
            print "simulation[ $symbol ] = $simulation - $hms \n";

            do {
                #loop until you get answer
                @a2 = chain_pull($symbol, $simulation);
            } while (@a2 == 1);


            for my $i (0..$#a1)
            {
                undef @load;
                @array1 = values $a1[$i];
                @array2 = values $a2[$i];
                @load = compare(\@array1, \@array2);
                if (scalar(grep {defined $_} @load) > 0) {

                    print "\nchange found - details\n $hms \n";
                    #print scalar(grep {defined $_} @load), "\n";

                    push @keep, $a2[$i];
                    #print values $a2[$i];

                }
            }
        }

    };

    #############################################################################################################
    #thread requests - also this should set PERL_DESTRUCT_LEVEL to 2 - to give memory back
    #############################################################################################################

    sub get_credentials {
        my ($file) = @_;
        open my $fh, "<", $file or die $!;

        my $line = <$fh>;
        chomp($line);
        return ($line)

    };


    #############################################################################################################
#compare two arrays to see if anything has changed
#############################################################################################################
    sub compare{
        
        my @intersection = ();
        my @difference = ();
        my %count = ();
        
        foreach my $element (@array1, @array2) { $count{$element}++ }
        foreach my $element (keys %count) {
            push @{ $count{$element} > 1 ? \@intersection : \@difference }, $element;
        };
            
        return @difference;
        
    };


    #############################################################################################################
    #subroutine for pulling option chains
    #############################################################################################################
    sub chain_pull{

        my $ua = LWP::UserAgent->new();

        $ua->cookie_jar({});

        my $symbols = $_[0];
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


        $url = 'https://apis.tdameritrade.com/apps/200/'.
               'OptionChain?source='.$source.
               '&symbol='.$symbols.
               '&quotes=true';

        $response = $ua->get($url);

        #if server doesnt reply leave sub and try again
        if ($response->is_success) {
                #would be more effecient to change to scalar - $response->content_ref();
                #my $buf = $response->content;
                my $buf = $response->content_ref();
        } else {
                print "\n ...server not reached...\n";
                return 1;
        }

        my $xs = XML::Simple->new();
        my $ref = $xs->XMLin($response->content, ForceArray => ['optionchain'], KeyAttr => {});

        #check if anyhing came back else exist and re-request
        #unless (@{ $val // [] }) {
        #... # stuff to do if the array is empty
        #}
        if (not defined $ref->{'option-chain-results'}->{'option-date'}) {
                print "\n no results came back\n";
                return 1;
        }

        my @result = @{$ref->{'option-chain-results'}->{'option-date'}};

        #Declare array to store XML response after being formatted
        my $array_ref;
        my @array;
        my $row = 0;
        my $sc_volume;
        my $sp_volume;

        #Loop through xml results
        foreach (@result) {

                my @child = @{$_->{'option-strike'}};

                ##count number of children in a node
                my $ctrcount = scalar(grep {defined $_} @{$_->{'option-strike'}});

                foreach (@child) {

                #############################################################################################################
                #set simumation for after hours
                #############################################################################################################

                if ($simulation == 1) {
                    if (int(rand(2)) == 1) {
                        $sc_volume = int(rand(10)) + $_->{call}->{'volume'};
                    } else {$sc_volume = "$_->{call}->{'volume'}";}

                    if (int(rand(2)) == 1) {
                        $sp_volume = int(rand(10)) + $_->{put}->{'volume'};
                    } else {$sp_volume = "$_->{put}->{'volume'}";}

                }else {
                    $sc_volume = "$_->{call}->{'volume'}";
                    $sp_volume = "$_->{put}->{'volume'}";
                }
                #############################################################################################################

                        my $call_bid = "$_->{call}->{'bid'}";
                        my $call_ask = "$_->{call}->{'ask'}";
                        my $put_bid = "$_->{put}->{'bid'}";
                        my $put_ask = "$_->{put}->{'ask'}";
                        my $call_delta= "$_->{call}->{'delta'}";
                        my $put_delta= "$_->{put}->{'delta'}";
                        my $call_open_interest = "$_->{call}->{'open-interest'}" || 0;
                        my $put_open_interest = "$_->{put}->{'open-interest'}" || 0;

                        $call_bid =~ s/([HASH]+)\(([^)]+)\)/0.00/g;
                        $call_ask =~ s/([HASH]+)\(([^)]+)\)/0.00/g;
                        $put_bid =~ s/([HASH]+)\(([^)]+)\)/0.00/g;
                        $put_ask =~ s/([HASH]+)\(([^)]+)\)/0.00/g;
                        $call_delta =~ s/([HASH]+)\(([^)]+)\)/0.00/g;
                        $put_delta =~ s/([HASH]+)\(([^)]+)\)/0.00/g;
                        $call_open_interest =~ s/([HASH]+)\(([^)]+)\)/0.00/g;
                        $put_open_interest =~ s/([HASH]+)\(([^)]+)\)/0.00/g;

                        no warnings;

                        push @{ $array_ref }, "load_time";
                        push @{ $array_ref }, "$_->{call}->{'option-symbol'}";
                        push @{ $array_ref }, "$call_bid";
                        push @{ $array_ref }, "$call_ask";
                        push @{ $array_ref }, "$_->{call}->{'bid-ask-size'}";
                        push @{ $array_ref }, "$_->{call}->{'last'}";
                        push @{ $array_ref }, "$call_delta";
                        push @{ $array_ref }, "$sc_volume";
                        push @{ $array_ref }, "$call_open_interest";
                        push @{ $array_ref }, "$put_bid";
                        push @{ $array_ref }, "$put_ask";
                        push @{ $array_ref }, "$_->{put}->{'bid-ask-size'}";
                        push @{ $array_ref }, "$_->{put}->{'last'}";
                        push @{ $array_ref }, "$put_delta";
                        push @{ $array_ref }, "$sp_volume";
                        push @{ $array_ref }, "$put_open_interest";

                        use warnings;

                        foreach my $array_ref (@{$array_ref})
                        {
                                $array_ref =~ s/([HASH]+)\(([^)]+)\)//g;
                        }
                        push @{$array[$row]}, @{ $array_ref };
                        $row++;

                        @{ $array_ref } = ();

                        }

                }

        return @array;

    };
