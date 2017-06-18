#!/usr/local/bin/perl

use strict;
use warnings;
use DateTime;
use DateTime::Format::Strptime;
use Cwd;
use DBI;
use threads;
use JSON;

use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname(dirname abs_path $0) . '/lib/';
use OPT::MultChainSputnik qw(launchChainSputnik get_credentials);

#use OPT::MultChainSputnik qw( launchChainSputnik );

#print dirname(dirname abs_path($0)) . '/lib/OPT/' . "\n";

#launchChainSputnik(my $symbol = 'QQQ', my $table='q_optsputnik', my $simulation=1);
#launchChainSputnik @{[(split//=>"QQQ q_optionsputnik 1")]};

#use CGI qw(:standard);

package Emp;

sub new {
    my $class = shift;
    my $self = { symbol => shift };
    bless $self, $class;
    return $self;
}

sub TO_JSON { return { %{ shift() } }; }

package main;

#Declare start timestamp
sub sleeping_sub ( $ $ $ );

my $nb_process;
my $i          = 0;
my @running    = ();
my @Threads;

##access db for latest equity information
my $sql_table = 'xxx';
my $rowcache;
my $max_rows = 1;

sub get_credentials {
    my ($file) = @_;
    open my $fh, "<", $file or die $!;

    my $line = <$fh>;
    chomp($line);
    return ($line)

};

my ($dbInfo, $pguser, $pgpass) = split /~/, get_credentials("/home/zad0xlik/.qtrack_pg.conf");

my $db = DBI->connect($dbInfo,
    $pguser,
    $pgpass,
    {AutoCommit=>1,RaiseError=>1,PrintError=>0}
) || die "Database connection not made: $DBI::errstr";

my $sth = $db->prepare( "
       select symbol from symbols
       where symbol in ('QQQ','PTN');
	")
  or die(qq(Can't prepare COLUMN query for " . $sql_table "));

$sth->execute()
  or die qq(Can't execute COLUMN " . $sql_table ");

my $cth = $db->prepare( "
       select count(symbol) from symbols
       where symbol in ('QQQ','PTN');
        ")
  or die(qq(Can't prepare COLUMN query for " . $sql_table "));

$cth->execute()
  or die qq(Can't execute COLUMN " . $sql_table ");

my @cnt = $cth->fetchrow_array;
$nb_process = $cnt[0];

my $JSON = JSON->new->utf8; $JSON->convert_blessed(1);

##potentially create loop for threading here
no warnings;
while ( my $row =
       shift( @{$rowcache} )
    || shift( @{ $rowcache = $sth->fetchall_arrayref( undef, $max_rows ) } ) )
{

    my $symbol = join('', @{$row});
    my $table = lc(substr($symbol, 0, 1)) . "_optsputnik";
    my $simulation = 1;

    @running = threads->list(threads::running);
    print "LOOP $i\n";
    print "  - BEGIN LOOP >> NB running threads = "
      . ( scalar @running ) . "\n";

    if ( scalar @running < $nb_process ) {

        #my $thread = threads->new( sub { system( ${prod_filter} ); } );
#        my $thread = threads->create( launchChainSputnik($symbol, $table, $simulation) );
        my $thread = threads->create( OPT::MultChainSpuntik::launchChainSputnik($symbol, $table, $simulation) );
        #my $thread = threads->create( launchChainSputnik @{[(split//=>"QQQ q_optionsputnik 1")]} );

        push( @Threads, $thread );
        my $tid = $thread->tid;
        print "  - starting thread $tid\n";
    }
    @running = threads->list(threads::running);
    print "  - AFTER STARTING >> NB running Threads = "
      . ( scalar @running ) . "\n";
    foreach my $thr (@Threads) {
        if ( $thr->is_running() ) {
            my $tid = $thr->tid;
            print "  - Thread $tid running\n";
        }
        elsif ( $thr->is_joinable() ) {
            my $tid = $thr->tid;
            $thr->join;
            print "  - Results for thread $tid:\n";
            print "  - Thread $tid has been joined\n";
        }
    }

    @running = threads->list(threads::running);
    print "  - END LOOP >> NB Threads = " . ( scalar @running ) . "\n";
    $i++;

}

print "\nJOINING pending threads\n";
while ( scalar @running != 0 ) {
    foreach my $thr (@Threads) {
        $thr->join if ( $thr->is_joinable() );
    }
    @running = threads->list(threads::running);
}

print "NB started threads = " . ( scalar @Threads ) . "\n";
print "End of main program\n";

sub sleeping_sub ( $ $ $ ) {
    sleep(4);
}

use warnings;

END {
    $db->disconnect if defined($db);
}
