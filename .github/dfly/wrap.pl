# SPAMD_FORKER wrapper: wrap.pl DIR - PERL SATest.pl ...
# Runs the command, logs signals the wrapper receives and how the
# command's process ended. The child gets the wrapper's inherited
# signal dispositions back before exec.
use strict; use warnings;
use POSIX qw(strftime);
use Time::HiRes qw(time);
my ($dir, $kt, @cmd) = @ARGV;
sub logit {
  my $t = time;
  open(my $fh, '>>', "$dir/wrap.log") or return;
  printf $fh "%s.%03d wrapper %d: %s\n", strftime('%H:%M:%S', gmtime $t),
    ($t - int $t) * 1000, $$, $_[0];
  close $fh;
}
my @sigs = grep { exists $SIG{$_} } qw(HUP INT QUIT USR1 USR2 ALRM TERM
  PIPE TTIN TTOU XCPU XFSZ VTALRM PROF WINCH INFO);
my %orig = map { $_ => $SIG{$_} } @sigs;
$SIG{$_} = sub { logit("received SIG$_[0]") } for @sigs;
my $pid = fork;
defined $pid or die "fork: $!";
if (!$pid) {
  $SIG{$_} = (defined $orig{$_} && $orig{$_} eq 'IGNORE') ? 'IGNORE' : 'DEFAULT' for @sigs;
  exec @cmd;
  die "exec: $!";
}
logit("started $pid");
waitpid($pid, 0);
my $st = $?;
logit(sprintf("pid %d ended: wait status %d, exit %d, signal %d%s",
  $pid, $st, $st >> 8, $st & 127, ($st & 128) ? ', core dumped' : ''));
