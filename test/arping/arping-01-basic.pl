#!/usr/bin/perl -w

use Test::Command tests => 2;
use Test::More;

# -V
{
    my $cmd = Test::Command->new(cmd => 'arping -V');
    $cmd->exit_is_num(0);
	subtest 'output' => sub {
		$cmd->stdout_like(qr/^arping from iputils /, 'Print version');
		$cmd->stdout_like(qr/libcap: (yes|no), IDN: (yes|no), NLS: (yes|no), error.h: (yes|no), getrandom\(\): (yes|no), __fpending\(\): (yes|no)$/, 'Print config');
	}
}
