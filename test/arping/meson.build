# Copyright (c) 2021 Petr Vorel <pvorel@suse.cz>

foreach dst : [ 'localhost', '127.0.0.1' ] + ipv6_dst
  foreach switch : [ '', '-4' ] + ipv6_switch
	args = [ '-c1', dst ]
	should_fail = false

	if switch != ''
	  args = [switch] + args
	  if (switch == '-4' and dst == '::1') or (switch == '-6' and dst == '127.0.0.1')
		 should_fail = true
	  endif
	endif

	name = 'ping ' + ' '.join(args)
	test(name, ping, args : args, should_fail : should_fail)
  endforeach
endforeach

ping_tests_opt = [
  [ '-c1' ],
  [ '-c5', '-i0.1' ],
  [ '-c1', '-I', 'lo' ],
  [ '-c1', '-w1' ],
  [ '-c1', '-W1' ],
  [ '-c1', '-W1.1' ],
]
foreach dst : [ '127.0.0.1' ] + ipv6_dst
  foreach args : ping_tests_opt
	args += [ dst ]
	name = 'ping ' + ' '.join(args)
	test(name, ping, args : args)
  endforeach
endforeach

ping_tests_opt_fail = [
  [ '-c1.1' ],
  [ '-I', 'nonexisting' ],
  [ '-w0.1' ],
  [ '-w0,1' ],
]
foreach dst : [ '127.0.0.1' ] + ipv6_dst
  foreach args : ping_tests_opt_fail
	args += [ dst ]
	name = 'ping ' + ' '.join(args)
	test(name, ping, args : args, should_fail : true)
  endforeach
endforeach

ping_tests_user_fail = [
  [ '-c1', '-i0.001' ], # -c1 required to quit ping when running as root
]
foreach dst : [ '127.0.0.1' ] + ipv6_dst
  foreach args : ping_tests_user_fail
	args += [ dst ]
	name = 'ping ' + ' '.join(args)
	test(name, ping, args : args, should_fail : not run_as_root)
  endforeach
endforeach
