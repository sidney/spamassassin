#!/usr/bin/perl
# Does IO::Socket::connected() (getpeername) work on a socket that spamd
# accepts after the client has already half-closed or closed it?  spamd's
# accept_a_conn treats an undefined connected() as a failed accept and the
# child exits ("respawning server").  spamc writes its request and then
# calls shutdown(SHUT_WR), often before spamd accepts.
use strict;
use warnings;
use IO::Socket::UNIX;
use IO::Socket::IP;
use Socket qw(SOCK_STREAM SOMAXCONN SOL_SOCKET SO_LINGER);
use File::Temp qw(tempdir);
use POSIX ();

$| = 1;
my $req = "PING SPAMC/1.5\r\n\r\n";
my @cases = (
  [ 'wrote, still open',    sub { print {$_[0]} $req } ],
  [ 'wrote, half-closed',   sub { print {$_[0]} $req; shutdown($_[0], 1) } ],
  [ 'wrote, closed',        sub { print {$_[0]} $req; close $_[0] } ],
  [ 'closed, nothing sent', sub { close $_[0] } ],
);

sub check {
  my ($kind, $label, $acc) = @_;
  if (!$acc) { print "$^O $kind client $label: accept failed: $!\n"; return }
  $! = 0;
  my $c = $acc->connected;
  my $err = $!;
  my $line = $acc->getline;
  printf "%s %s client %s before accept: connected() %s; first read %s\n",
    $^O, $kind, $label, defined $c ? "defined" : "undef ($err)",
    defined $line ? "got request" : "EOF";
}

my $dir  = tempdir(CLEANUP => 1);
my $path = "$dir/p.sock";
my $usrv = IO::Socket::UNIX->new(Local => $path, Type => SOCK_STREAM,
                                 Listen => SOMAXCONN) or die "unix listen: $!\n";
my $tsrv = IO::Socket::IP->new(LocalHost => '127.0.0.1', LocalPort => 0,
                               Listen => 5) or die "tcp listen: $!\n";
for my $case (@cases) {
  my ($label, $act) = @$case;
  my $ucl = IO::Socket::UNIX->new(Peer => $path, Type => SOCK_STREAM)
    or die "unix connect: $!\n";
  $act->($ucl);
  select(undef, undef, undef, 0.3);
  check('unix', $label, scalar $usrv->accept);

  my $tcl = IO::Socket::IP->new(PeerHost => '127.0.0.1',
                                PeerPort => $tsrv->sockport) or die "tcp connect: $!\n";
  $act->($tcl);
  select(undef, undef, undef, 0.3);
  check('tcp', $label, scalar $tsrv->accept);
}
my @u = POSIX::uname();
print "uname: @u[0,2,4]\n";
