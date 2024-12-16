# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (c) 2021 Petr Vorel <pvorel@suse.cz>

if build_arping == true
  test('arping tests', find_program('run.sh'), args: ['arping'])
  subdir('arping')
endif

if build_clockdiff == true
  subdir('clockdiff')
endif

if build_ping == true
  test('ping tests', find_program('run.sh'), args: ['ping'])
  subdir('ping')
endif

if build_tracepath == true
  subdir('tracepath')
endif
