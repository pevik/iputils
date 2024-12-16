#!/usr/bin/perl -w

use Test::Command tests => 2;
use Test::More;

diag("Running as UID: $>");
diag("PATH = $ENV{PATH}");
my $tracepath = $ARGV[0] // 'tracepath';
diag("passed cmd: $tracepath");
printf("# actually used cmd: ");
system("/bin/sh", "-c", "command -v $tracepath");

# -V
{
    my $cmd = Test::Command->new(cmd => "$tracepath -V");
    $cmd->exit_is_num(0);
	subtest 'output' => sub {
		$cmd->stdout_like(qr/^tracepath from iputils /, 'Print version');
		$cmd->stdout_like(qr/libcap: (yes|no), IDN: (yes|no), NLS: (yes|no), error.h: (yes|no), getrandom\(\): (yes|no), __fpending\(\): (yes|no)$/, 'Print config');
	}
}
