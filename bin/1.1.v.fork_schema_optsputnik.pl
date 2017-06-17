use LWP::Simple;
use Parallel::ForkManager;
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname(dirname abs_path $0) . '/bin/';

my @workers=(


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


