#!/bin/sh

dir="$(dirname $0)"
export PATH="$dir/lib:$dir/lib/tests:$PATH"
echo "run tst_rhost_run.sh"
tst_rhost_run.sh

# vim: set ft=sh ts=4 sts=4 sw=4 expandtab :
