#!/usr/bin/perl -w

use Test::Command tests => 11;
use Test::More;

diag("Running as UID: $>");
diag("PATH = $ENV{PATH}");
my $ping = $ARGV[0] // 'ping';
diag("passed cmd: $ping");
printf("# actually used cmd: ");
system("/bin/sh", "-c", "command -v $ping");

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

# localhost
{
    my $cmd = Test::Command->new(cmd => "$ping -c1 localhost");
    $cmd->exit_is_num(0);
}

# -4 localhost
{
    my $cmd = Test::Command->new(cmd => "$ping -c1 -4 localhost");
    $cmd->exit_is_num(0);
	subtest 'output' => sub {
		$cmd->stdout_like(qr/64 bytes from localhost \(127\.0\.0\.1\)/, 'Ping received from localhost');
		$cmd->stdout_like(qr/0% packet loss/, 'No packet loss');
		$cmd->stdout_like(qr/time=\d+\.\d+ ms/, 'Ping time present');
		$cmd->stdout_like(qr~rtt min/avg/max/mdev = \d+\.\d{3}/\d+\.\d{3}/\d+\.\d{3}/\d+\.\d{3} ms$~,
			'RTT time present');
		$cmd->stdout_like(qr{^PING localhost \(127\.0\.0\.1\) 56\(84\) bytes of data\.
64 bytes from localhost \(127\.0\.0\.1\): icmp_seq=1 ttl=\d+ time=\d\.\d{3} ms

--- localhost ping statistics ---
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
    my $cmd = Test::Command->new(cmd => "$ping -c1 -6 localhost");
    $cmd->exit_is_num(0);
	subtest 'output' => sub {
		$cmd->stdout_like(qr/64 bytes from localhost \(::1\)/, 'Ping received from localhost');
		$cmd->stdout_like(qr/0% packet loss/, 'No packet loss');
		$cmd->stdout_like(qr/time=\d+\.\d+ ms/, 'Ping time present');
		$cmd->stdout_like(qr~rtt min/avg/max/mdev = \d+\.\d{3}/\d+\.\d{3}/\d+\.\d{3}/\d+\.\d{3} ms$~,
			'RTT time present');
	}
}
