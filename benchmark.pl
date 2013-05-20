#!/usr/bin/env perl
#
# This is the prototypical perl file; extend this with more best-practices
# when able.

use warnings;
use strict;

use Getopt::Long;
use Pod::Usage;
use Data::Dumper;
use File::Util;

File::Util::flock_rules( qw/ NOBLOCKEX IGNORE / );

# change the following to the top of your dev tree
use Find::Lib libs => ['../../common/perllib', '../common/perllib','.'];

use Chegg::Std;
use Chegg::Pipeline::Execute;

my($PROG) = $0 =~ m@/([^/]+)$@;
my($help, $man);
my($debug_tags) = '';
my($s) = Chegg::Std->new($PROG);
my(@verbose) = ();
my($e) = Chegg::Pipeline::Execute->new($PROG);

my($DATA_DIR) = '/Users/jric/dev/test/data';
my($VAR_DIR) = "$DATA_DIR/../var";
my(%BENCHMARKS) = (
  'node0.8' => '/Users/jric/dev/test/js/test-IO-perf.js',
  'python2' => '/Users/jric/dev/test/python/test_IO_perf.py'
);
my $NUM_RUNS = 20;

sub processCmdlineArgs {
  Getopt::Long::Configure ("bundling");

  my($args_ok) =
    GetOptions (
      'help|h'      => \$help,
      'man'         => \$man,
      'd|debug=s'   => \$debug_tags,
      'v|verbose'   => \@verbose
      );

  if (!$args_ok) { pod2usage(); die "failed to process options"; }

  if (defined($help)) { pod2usage(0); }
  if (defined($man)) { pod2usage(-exitstatus => 0, -verbose => 2); }
  (my @unexpected_args) = @ARGV;
  if (0) { pod2usage('not enough args'); }
  if (@unexpected_args) { pod2usage('too many args'); }
  my($status) = $s->setDebug($debug_tags);
  if ($status) { print STDOUT $status; exit(0); }
}

sub prepTest {
  my($cmd) = "rm -r $VAR_DIR/news.yahoo.com";
  my($status) = $e->execute_get_status($cmd);
  if ($status->errors()) { return $status; }
  $cmd = "cp -rp $DATA_DIR/news.yahoo.com $VAR_DIR/news.yahoo.com";
  $status = $e->execute_get_status($cmd);
  
  return $status;
}

# Runs benchmarks at given level of parallelism
# $timins_ref:  will be populated like:
#   { (node0.8|python2) => { <parallelism> => timings } }
sub runTest {
  my($timings_ref, $parallel) = @_;
  
  foreach my $benchmark ('node0.8', 'python2') {
    my $run_time = 0;
    my $cmd = $BENCHMARKS{$benchmark} .
      " --parallel $parallel $VAR_DIR/news.yahoo.com";
    for(my $count = 0; $count < $NUM_RUNS; $count++) {
      my $status = prepTest();
      if ($status->errors()) { return $status; }
      my $time_start = time();
      $status = $e->execute_get_status($cmd);
      my $time_end = time();
      if ($status->errors()) { return $status; }
      $run_time += $time_end - $time_start;
    }
    
    $timings_ref->{$benchmark}->{$parallel} = $run_time;
  }
  
  return Chegg::Status->new();
}

sub runTests {
  my %timings;
  
  for(my $parallel = 1; $parallel < 200; ) {    
    my $status = runTest(\%timings, $parallel);
#    last; # DEBUG
    if ($parallel < 10) { $parallel++; }
    elsif ($parallel < 100) { $parallel += 10; }
    else { $parallel += 50; }
  }
  
  print "system\tparallelism\ttime\n";
  foreach my $benchmark (keys(%timings)) {
    foreach my $parallel (sort(keys(%{$timings{$benchmark}}))) {
      print "$benchmark\t$parallel\t$timings{$benchmark}->{$parallel}\n";
    }
  }
  
  return Chegg::Status->new();
}

sub main {
  $s->announceMyself();
  processCmdlineArgs();
  
  my $status = runTests();
  if ($status->errors()) { $s->error($status->errorMsg()); }
  
  return $status->errors();
}

exit main();

__END__

=head1 benchmark.pl

    benchmark.pl - run a node program and a python program with varying levels
      of parallelism; run 20 trials at each level; prep before each trial;
      record results

=head1 SYNOPSIS

benchmark.pl [options] [file ...]

 REQUIRED ARGS:

 OPTIONS:
   GENERIC:
   -h, --help           : brief help message
   --man                : full documentation  
   -d, --debug [tag(s)] : see debug messages; special tags:
     ?   : what are the possible debug tags I can use?
     *   : show me all possible debugging output
     a,b : show me debugging output for both tags a and b

=head1 DESCRIPTION

B<This program> will read the given input file(s) and do something
useful with the contents thereof.

=cut

