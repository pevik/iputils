#!/usr/bin/perl -w

use Socket qw(AF_INET AF_INET6 AF_UNSPEC SOCK_STREAM AI_CANONNAME);
use Socket::GetAddrInfo qw(getaddrinfo);
use Test::Command tests => 11;
use Test::More;

diag("Running as UID: $>");
diag("PATH = $ENV{PATH}");
my $ping = $ARGV[0] // 'ping';
diag("passed cmd: $ping");
printf("# actually used cmd: ");
system("/bin/sh", "-c", "command -v $ping");

sub get_canonname
{
	my $host = shift;
	my $family = shift // AF_UNSPEC;

	my $hints = {
		flags     => AI_CANONNAME,
		family    => $family,
		socktype  => SOCK_STREAM,
	};

	die "invalid family: '$family'" unless ($family == AF_INET || $family == AF_INET6 || $family == AF_UNSPEC);

	my ($err, @res) = getaddrinfo($host, undef, $hints);
	die "getaddrinfo error: $err\n" if $err;

	foreach my $ai (@res) {
		return $ai->{canonname} if $ai->{canonname};
	}
}

# -V
{
    my $cmd = Test::Command->new(cmd => "$ping -V");
    $cmd->exit_is_num(0);
	subtest 'output' => sub {
		$cmd->stdout_like(qr/^ping from iputils /, 'Print version');
		$cmd->stdout_like(qr/libcap: (yes|no), IDN: (yes|no), NLS: (yes|no), error.h: (yes|no), getrandom\(\): (yes|no), __fpending\(\): (yes|no)$/, 'Print config');
	}
}

# 127.0.0.1
{
    my $cmd = Test::Command->new(cmd => "$ping -c1 127.0.0.1");
    $cmd->exit_is_num(0);
	subtest 'output' => sub {
		$cmd->stdout_like(qr/64 bytes from 127\.0\.0\.1/, 'Ping received from 127.0.0.1');
		$cmd->stdout_like(qr/0% packet loss/, 'No packet loss');
		$cmd->stdout_like(qr/time=\d+\.\d+ ms/, 'Ping time present');
		$cmd->stdout_like(qr~rtt min/avg/max/mdev = \d+\.\d{3}/\d+\.\d{3}/\d+\.\d{3}/\d+\.\d{3} ms$~,
			'RTT time present');
		$cmd->stdout_like(qr{^PING 127\.0\.0\.1 \(127\.0\.0\.1\) 56\(84\) bytes of data\.
64 bytes from 127\.0\.0\.1: icmp_seq=1 ttl=\d+ time=\d\.\d{3} ms

--- 127.0.0.1 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time \d+ms
rtt min/avg/max/mdev = \d+\.\d{3}/\d+\.\d{3}/\d+\.\d{3}/\d+\.\d{3} ms$},
'Entire ping output matched exactly');
	}
}

# ::1
SKIP: {
    if ($ENV{SKIP_IPV6}) {
        skip 'IPv6 tests', 2;
    }
    my $cmd = Test::Command->new(cmd => "$ping -c1 ::1");
    $cmd->exit_is_num(0);
	subtest 'output' => sub {
		$cmd->stdout_like(qr/64 bytes from ::1/, 'Ping received from ::1');
		$cmd->stdout_like(qr/0% packet loss/, 'No packet loss');
		$cmd->stdout_like(qr/time=\d+\.\d+ ms/, 'Ping time present');
		$cmd->stdout_like(qr~rtt min/avg/max/mdev = \d+\.\d{3}/\d+\.\d{3}/\d+\.\d{3}/\d+\.\d{3} ms$~,
			'RTT time present');
		$cmd->stdout_like(qr{^PING ::1 \(::1\) 56 data bytes
64 bytes from ::1: icmp_seq=1 ttl=\d+ time=\d\.\d{3} ms

--- ::1 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time \d+ms
rtt min/avg/max/mdev = \d+\.\d{3}/\d+\.\d{3}/\d+\.\d{3}/\d+\.\d{3} ms$},
'Entire ping output matched exactly');
	}
}

my $localhost = "localhost";
my $localhost_cannon_ipv4 = get_canonname($localhost, AF_INET);
my $localhost_cannon_ipv6 = get_canonname($localhost, AF_INET6);
diag("localhost_cannon_ipv4: '$localhost_cannon_ipv4'");
diag("localhost_cannon_ipv6: '$localhost_cannon_ipv6'");
die "Undefined cannonical name for $localhost on IPv4" unless defined $localhost_cannon_ipv4;
die "Undefined cannonical name for $localhost on IPv6" unless defined $localhost_cannon_ipv6;

# localhost
{
    my $cmd = Test::Command->new(cmd => "$ping -c1 $localhost");
    $cmd->exit_is_num(0);
}

# -4 localhost
{
    my $cmd = Test::Command->new(cmd => "$ping -c1 -4 $localhost");
    $cmd->exit_is_num(0);
	subtest 'output' => sub {
		$cmd->stdout_like(qr/64 bytes from $localhost_cannon_ipv4 \(127\.0\.0\.1\)/, "Ping received from $localhost (IPv4)");
		$cmd->stdout_like(qr/0% packet loss/, 'No packet loss');
		$cmd->stdout_like(qr/time=\d+\.\d+ ms/, 'Ping time present');
		$cmd->stdout_like(qr~rtt min/avg/max/mdev = \d+\.\d{3}/\d+\.\d{3}/\d+\.\d{3}/\d+\.\d{3} ms$~,
			'RTT time present');
		$cmd->stdout_like(qr{^PING $localhost_cannon_ipv4 \(127\.0\.0\.1\) 56\(84\) bytes of data\.
64 bytes from $localhost_cannon_ipv4 \(127\.0\.0\.1\): icmp_seq=1 ttl=\d+ time=\d\.\d{3} ms

--- $localhost_cannon_ipv4 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time \d+ms
rtt min/avg/max/mdev = \d+\.\d{3}/\d+\.\d{3}/\d+\.\d{3}/\d+\.\d{3} ms$},
'Entire ping output matched exactly');
	}
}

# -6 localhost
SKIP: {
    if ($ENV{SKIP_IPV6}) {
        skip 'IPv6 tests', 2;
    }
    my $cmd = Test::Command->new(cmd => "$ping -c1 -6 $localhost");
    $cmd->exit_is_num(0);
	subtest 'output' => sub {
		$cmd->stdout_like(qr/64 bytes from $localhost_cannon_ipv6 \(::1\)/, "Ping received from $localhost (IPv6)");
		$cmd->stdout_like(qr/0% packet loss/, 'No packet loss');
		$cmd->stdout_like(qr/time=\d+\.\d+ ms/, 'Ping time present');
		$cmd->stdout_like(qr~rtt min/avg/max/mdev = \d+\.\d{3}/\d+\.\d{3}/\d+\.\d{3}/\d+\.\d{3} ms$~,
			'RTT time present');
	}
}
