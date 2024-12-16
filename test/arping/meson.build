# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (c) 2021-2025 Petr Vorel <pvorel@suse.cz>

message('Build directory is: ' + meson.current_build_dir())

cur_build = meson.current_build_dir()
build_root = meson.build_root()
rel_path = cur_build.replace(build_root + '/', '')

foreach t : ['arping-01-basic.pl']
  test(rel_path + '/' + t, find_program(t), args: arping)
endforeach
