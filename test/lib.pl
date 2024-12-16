#!/usr/bin/perl -w

our @EXPORT_OK = qw(get_cmd);

sub get_cmd()
{
	my $cmd = shift;

	diag("Running as UID: $>");
	diag("PATH = $ENV{PATH}");
	diag("passed cmd: $cmd");
	printf("# actually used cmd: ");
	system("/bin/sh", "-c", "command -v $cmd");

	return "$cmd";
}

1;
