
executable('tst_rod', [
		'tst_rod.c',
		git_version_h
	],
	install: true)

lib = join_paths(meson.source_root(), 'tests/lib')
run = join_paths(meson.source_root(), 'tests/run.sh')
dest = join_paths(meson.build_root(), 'tests')
message('copying @0@ @1@ to @2@'.format(lib, run, dest))
run_command('cp', '-rv', lib, run, dest)
