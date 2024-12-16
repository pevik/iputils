#!/usr/bin/perl -w

use Test::Command tests => 2;
use Test::More;

diag("Running as UID: $>");
diag("PATH = $ENV{PATH}");
my $clockdiff = $ARGV[0] // 'clockdiff';
diag("passed cmd: $clockdiff");
printf("# actually used cmd: ");
system("/bin/sh", "-c", "command -v $clockdiff");

# -V
{
    my $cmd = Test::Command->new(cmd => "$clockdiff -V");
    $cmd->exit_is_num(0);
	subtest 'output' => sub {
		$cmd->stdout_like(qr/^clockdiff from iputils /, 'Print version');
		$cmd->stdout_like(qr/libcap: (yes|no), IDN: (yes|no), NLS: (yes|no), error.h: (yes|no), getrandom\(\): (yes|no), __fpending\(\): (yes|no)$/, 'Print config');
	}
}
