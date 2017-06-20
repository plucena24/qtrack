use LWP::Simple;
use Parallel::ForkManager;
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname(dirname abs_path $0) . '/bin/';

my @workers=(		

  ["perl " . dirname(dirname abs_path $0) . "/bin/sql_execute.pl "," a schema_optsputnik "]
, ["perl " . dirname(dirname abs_path $0) . "/bin/sql_execute.pl "," b schema_optsputnik "]
, ["perl " . dirname(dirname abs_path $0) . "/bin/sql_execute.pl "," c schema_optsputnik "]
, ["perl " . dirname(dirname abs_path $0) . "/bin/sql_execute.pl "," d schema_optsputnik "]
, ["perl " . dirname(dirname abs_path $0) . "/bin/sql_execute.pl "," e schema_optsputnik "]
, ["perl " . dirname(dirname abs_path $0) . "/bin/sql_execute.pl "," f schema_optsputnik "]
, ["perl " . dirname(dirname abs_path $0) . "/bin/sql_execute.pl "," g schema_optsputnik "]
, ["perl " . dirname(dirname abs_path $0) . "/bin/sql_execute.pl "," h schema_optsputnik "]
, ["perl " . dirname(dirname abs_path $0) . "/bin/sql_execute.pl "," i schema_optsputnik "]
, ["perl " . dirname(dirname abs_path $0) . "/bin/sql_execute.pl "," j schema_optsputnik "]
, ["perl " . dirname(dirname abs_path $0) . "/bin/sql_execute.pl "," k schema_optsputnik "]
, ["perl " . dirname(dirname abs_path $0) . "/bin/sql_execute.pl "," l schema_optsputnik "]
, ["perl " . dirname(dirname abs_path $0) . "/bin/sql_execute.pl "," m schema_optsputnik "]
, ["perl " . dirname(dirname abs_path $0) . "/bin/sql_execute.pl "," n schema_optsputnik "]
, ["perl " . dirname(dirname abs_path $0) . "/bin/sql_execute.pl "," o schema_optsputnik "]
, ["perl " . dirname(dirname abs_path $0) . "/bin/sql_execute.pl "," p schema_optsputnik "]
, ["perl " . dirname(dirname abs_path $0) . "/bin/sql_execute.pl "," q schema_optsputnik "]
, ["perl " . dirname(dirname abs_path $0) . "/bin/sql_execute.pl "," r schema_optsputnik "]
, ["perl " . dirname(dirname abs_path $0) . "/bin/sql_execute.pl "," s schema_optsputnik "]
, ["perl " . dirname(dirname abs_path $0) . "/bin/sql_execute.pl "," t schema_optsputnik "]
, ["perl " . dirname(dirname abs_path $0) . "/bin/sql_execute.pl "," u schema_optsputnik "]
, ["perl " . dirname(dirname abs_path $0) . "/bin/sql_execute.pl "," v schema_optsputnik "]
, ["perl " . dirname(dirname abs_path $0) . "/bin/sql_execute.pl "," w schema_optsputnik "]
, ["perl " . dirname(dirname abs_path $0) . "/bin/sql_execute.pl "," x schema_optsputnik "]
, ["perl " . dirname(dirname abs_path $0) . "/bin/sql_execute.pl "," y schema_optsputnik "]
, ["perl " . dirname(dirname abs_path $0) . "/bin/sql_execute.pl "," z schema_optsputnik "]

);

# Max 30 processes for parallel download
my $pm = Parallel::ForkManager->new(30);

WORKERS:
foreach my $jobarray (@workers) {
  $pm->start and next WORKERS; # do the fork

  my ($job, $fn) = @$jobarray;
  #warn "Cannot get $fn from $job" if getstore($job, $fn) != RC_OK;
  #warn "Cannot execute $fn for $job" if system(${$job.$fn}) != RC_OK;
  print "execute - $job$fn \n";
  #execute child
  system($job.$fn);

  $pm->finish; # do the exit in the child process
}
$pm->wait_all_children;

system($mstring1);


