#!/bin/sh

if [ "$1" = '-h' -o "$1" = '--help' ]; then
	cat << EOF
Usage: $0 [ arping|ping|clockdiff|tracepath ]
EOF
	exit 0
fi

ROOT="$(cd $(dirname $0); pwd)"

CMD="${1:-arping ping}"

export PATH="$1:$1/ping/:$PATH"

echo "PATH: '$PATH'"

for cmd in $CMD; do
	echo "=== Testing $cmd ==="
	echo "$cmd: $(command -v $cmd)"
	for i in $ROOT/$CMD/*.pl; do
		echo "run $i"
		$i
	done
done
