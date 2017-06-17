#!/usr/local/bin/perl

use strict;
use warnings;
use LWP::UserAgent;
use Math::BigInt;
use Date::Format;
use DBI;
use Cwd;
use CGI qw(:standard);
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname(dirname abs_path $0) . '/sql/';

### Must have space and comma
my $symbols = $ARGV[0];
my $sql_query = $ARGV[1];
my $sql_location = dirname(dirname abs_path($0)); 
my $sqlFile = ${sql_location}."/sql/".${sql_query}.".sql";

##########################################################################################################$
#connect to db
##########################################################################################################$

sub get_credentials {
    my ($file) = @_;
    open my $fh, "<", $file or die $!;

    my $line = <$fh>;
    chomp($line);
    return ($line)

};

my ($dbInfo, $pguser, $pgpass) = split /~/, get_credentials("/home/zad0xlik/.qtrack_pg.conf");

#Connect to SQL SERVER for insert
my $dbh = DBI->connect($dbInfo,
 	$pguser,
	$pgpass,
	{AutoCommit=>1,RaiseError=>1,PrintError=>0}
	) || die "Database connection not made: $DBI::errstr";

	#load sql file
	open (SQL, "$sqlFile")
	    or die (qq(Can't prepare "$sqlFile"));
        
	my $array_ref;
	while (my $sqlStatement = <SQL>) {
	    
	    #remove lines that start with "--"
	    if ($sqlStatement =~ /^\s*\--/ ) {
		next;
	    }
	    
	    #replace variable if found
	    $sqlStatement =~ s/&symbols/$symbols/g;
	    
	    #push into array
	    push @{ $array_ref }, $sqlStatement;
	
	}        

	#print final query to file for testing and log purposes (should be commented out in production)
	my $filename = ${sql_location}."/logs/".${sql_query}.'_'.${symbols}.'_fmt.sql';
	open(my $fh, '>', $filename) or die "Could not open file '$filename' $!";
	print $fh "@{ $array_ref }";
	close $fh;


my $alis = $dbh->prepare("@{ $array_ref }")
                or die (qq(Can't prepare "@{ $array_ref }"));
                
        $alis->execute()
                or die qq(Can't execute "@{ $array_ref }");


