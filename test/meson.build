# Copyright (c) 2021 Petr Vorel <pvorel@suse.cz>
# TODO: ::1 generates DEPRECATION: ":" is not allowed in test name "ping -c1 ::1", it has been replaced with "_"

# GitHub CI does not have working IPv6
# https://github.com/actions/virtual-environments/issues/668
ipv6_dst = []
ipv6_switch = []
r = run_command('ip', '-6', 'a')
if r.stdout().strip().contains('::1')
  message('IPv6 enabled')
  ipv6_dst = [ '::1' ]
  ipv6_switch = [ '-6' ]
else
  message('WARNING: IPv6 disabled')
endif

run_as_root = false
r = run_command('id', '-u')
if r.stdout().strip().to_int() == 0
  message('running as root')
  run_as_root = true
else
  message('running as normal user')
endif

subdir('arping')
subdir('ping')
