#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (c) 2023 Petr Vorel <pvorel@suse.cz>

# Confirm before proceeding, otherwise exit.
ask()
{
	local msg="$1"
	local answer

	printf "\n%s. Proceed? [N/y]: " "$msg"
	read -r answer
	case "$answer" in
		[Yy]*) : ;;
		*) exit 2
	esac
}

# Print error message and exit.
quit()
{
	printf "\n%s\n" "$@" >&2
	exit 1
}

# "Run or die". Run command and print failing command and exit on failure.
rod()
{
	"$@" || quit "$* failed"
}

# Print a header.
title()
{
	echo "===== $1 ====="
}
