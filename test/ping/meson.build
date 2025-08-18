# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (c) 2021-2025 Petr Vorel <pvorel@suse.cz>

message('Build directory is: ' + meson.current_build_dir())

foreach t : ['ping-01-basics.t', 'ping-02-errors.t' ]
  test(t, find_program(t), args: ping)
endforeach

test('json', find_program('test_json.py', required : true), args: ping)
