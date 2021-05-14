#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (c) 2016-2021 Petr Vorel <pvorel@suse.cz>
# Copyright (c) 2014-2017 Oracle and/or its affiliates. All Rights Reserved.
# DEPENDENCY: veth kernel driver
# Based on code from LTP
# https://github.com/linux-test-project/ltp
# Author: Alexey Kodanev <alexey.kodanev@oracle.com>
# Author: Petr Vorel <pvorel@suse.cz>

[ -n "$TST_LIB_NET_LOADED" ] && return 0
TST_LIB_NET_LOADED=1

TST_OPTS="6$TST_OPTS"
TST_PARSE_ARGS_CALLER="$TST_PARSE_ARGS"
TST_PARSE_ARGS="tst_net_parse_args"
TST_USAGE_CALLER="$TST_USAGE"
TST_USAGE="tst_net_usage"
TST_SETUP_CALLER="$TST_SETUP"
TST_SETUP="tst_net_setup"

# Blank for an IPV4 test; 6 for an IPV6 test.
TST_IPV6=${TST_IPV6:-}
TST_IPVER=${TST_IPV6:-4}
# Blank for IPv4, '-6' for IPv6 test.
TST_IPV6_FLAG=${TST_IPV6_FLAG:-}

tst_net_parse_args()
{
	case $1 in
	6) TST_IPV6=6 TST_IPVER=6 TST_IPV6_FLAG="-6";;
	*) [ "$TST_PARSE_ARGS_CALLER" ] && $TST_PARSE_ARGS_CALLER "$1" "$2";;
	esac
}

tst_net_read_opts()
{
	local OPTIND
	while getopts ":$TST_OPTS" opt; do
		$TST_PARSE_ARGS "$opt" "$OPTARG"
	done
}

tst_net_usage()
{
	if [ -n "$TST_USAGE_CALLER" ]; then
		$TST_USAGE_CALLER
	else
		echo "Usage: $0 [-6]"
		echo "OPTIONS"
	fi
	echo "-6      IPv6 tests"
}

tst_net_remote_tmpdir()
{
	[ "$TST_NEEDS_TMPDIR" = 1 ] || return 0
	[ -n "$TST_USE_LEGACY_API" ] && tst_tmpdir
	tst_rhost_run -c "mkdir -p $TST_TMPDIR"
	tst_rhost_run -c "chmod 777 $TST_TMPDIR"
	export TST_TMPDIR_RHOST=1
}

tst_net_setup()
{
	tst_net_remote_tmpdir
	[ -n "$TST_SETUP_CALLER" ] && $TST_SETUP_CALLER
}

. tst_test.sh

if [ "$TST_PARSE_ARGS_CALLER" = "$TST_PARSE_ARGS" ]; then
	tst_res TWARN "TST_PARSE_ARGS_CALLER same as TST_PARSE_ARGS, unset it ($TST_PARSE_ARGS)"
	unset TST_PARSE_ARGS_CALLER
fi
if [ "$TST_SETUP_CALLER" = "$TST_SETUP" ]; then
	tst_res TWARN "TST_SETUP_CALLER same as TST_SETUP, unset it ($TST_SETUP)"
	unset TST_SETUP_CALLER
fi
if [ "$TST_USAGE_CALLER" = "$TST_USAGE" ]; then
	tst_res TWARN "TST_USAGE_CALLER same as TST_USAGE, unset it ($TST_USAGE)"
	unset TST_USAGE_CALLER
fi

init_ltp_netspace()
{
	export LTP_NETNS="ip netns exec ltp_ns"

	if [ ! -f /var/run/netns/ltp_ns ]; then
		tst_require_cmds ip
		tst_require_root

		ROD ip net add ltp_ns
		ROD ip li add name ltp_ns_veth1 type veth peer name ltp_ns_veth2
		ROD ip li set dev ltp_ns_veth1 netns ltp_ns
		ROD $LTP_NETNS ip li set lo up
	fi

	LHOST_IFACES="${LHOST_IFACES:-ltp_ns_veth2}"
	RHOST_IFACES="${RHOST_IFACES:-ltp_ns_veth1}"

	export TST_INIT_NETNS="no"

	tst_restore_ipaddr
	tst_restore_ipaddr rhost
}

# Run command on remote host.
# tst_rhost_run -c CMD [-b] [-s] [-u USER]
# Options:
# -b run in background
# -c CMD specify command to run (this must be binary, not shell builtin/function)
# -s safe option, if something goes wrong, will exit with TBROK
# -u USER for ssh (default root)
# RETURN: 0 on success, 1 on failure
# TST_NET_RHOST_RUN_DEBUG=1 enables debugging
tst_rhost_run()
{
	local post_cmd=' || echo RTERR'
	local user="root"
	local ret=0
	local cmd out output rcmd sh_cmd safe

	local OPTIND
	while getopts :bc:su: opt; do
		case "$opt" in
		b) post_cmd=" > /dev/null 2>&1 &"
		   out="1> /dev/null"
		;;
		c) cmd="$OPTARG" ;;
		s) safe=1 ;;
		u) user="$OPTARG" ;;
		*) tst_brk TBROK "tst_rhost_run: unknown option: $OPTARG" ;;
		esac
	done

	if [ -z "$cmd" ]; then
		[ "$safe" ] && \
			tst_brk TBROK "tst_rhost_run: command not defined"
		tst_res TWARN "tst_rhost_run: command not defined"
		return 1
	fi

	sh_cmd="$cmd $post_cmd"

	rcmd="$LTP_NETNS sh -c"

	if [ "$TST_NET_RHOST_RUN_DEBUG" = 1 ]; then
		tst_res TINFO "tst_rhost_run: cmd: $cmd"
		tst_res TINFO "NETNS: $rcmd \"$sh_cmd\" $out 2>&1"
	fi

	output=$($rcmd "$sh_cmd" $out 2>&1 || echo 'RTERR')

	echo "$output" | grep -q 'RTERR$' && ret=1
	if [ $ret -eq 1 ]; then
		output=$(echo "$output" | sed 's/RTERR//')
		[ "$safe" ] && \
			tst_brk TBROK "'$cmd' failed on '$RHOST': '$output'"
	fi

	[ -z "$out" -a -n "$output" ] && echo "$output"

	return $ret
}

# Run command on both lhost and rhost.
# tst_net_run [-s] [-l LPARAM] [-r RPARAM] [ -q ] CMD [ARG [ARG2]]
# Options:
# -l LPARAM: parameter passed to CMD in lhost
# -r RPARAM: parameter passed to CMD in rhost
# -q: quiet mode (suppress failure warnings)
# CMD: command to run (this must be binary, not shell builtin/function due
# tst_rhost_run() limitation)
# RETURN: 0 on success, 1 on missing CMD or exit code on lhost or rhost
tst_net_run()
{
	local cmd
	local lparams
	local rparams
	local lsafe
	local rsafe
	local lret
	local rret
	local quiet

	local OPTIND
	while getopts l:qr:s opt; do
		case "$opt" in
		l) lparams="$OPTARG" ;;
		q) quiet=1 ;;
		r) rparams="$OPTARG" ;;
		s) lsafe="ROD"; rsafe="-s" ;;
		*) tst_brk TBROK "tst_net_run: unknown option: $OPTARG" ;;
		esac
	done
	shift $((OPTIND - 1))
	cmd="$1"
	shift

	if [ -z "$cmd" ]; then
		[ -n "$lsafe" ] && \
			tst_brk TBROK "tst_net_run: command not defined"
		tst_res TWARN "tst_net_run: command not defined"
		return 1
	fi

	$lsafe $cmd $lparams $@
	lret=$?
	tst_rhost_run $rsafe -c "$cmd $rparams $@"
	rret=$?

	if [ -z "$quiet" ]; then
		[ $lret -ne 0 ] && tst_res TWARN "tst_net_run: lhost command failed: $lret"
		[ $rret -ne 0 ] && tst_res TWARN "tst_net_run: rhost command failed: $rret"
	fi

	[ $lret -ne 0 ] && return $lret
	return $rret
}

EXPECT_RHOST_PASS()
{
	local log="$TMPDIR/log.$$"

	tst_rhost_run -c "$*" > $log
	if [ $? -eq 0 ]; then
		tst_res TPASS "$* passed as expected"
	else
		tst_res TFAIL "$* failed unexpectedly"
		cat $log
	fi

	rm -f $log
}

EXPECT_RHOST_FAIL()
{
	local log="$TMPDIR/log.$$"

	tst_rhost_run -c "$*" > $log
	if [ $? -ne 0 ]; then
		tst_res TPASS "$* failed as expected"
	else
		tst_res TFAIL "$* passed unexpectedly"
		cat $log
	fi

	rm -f $log
}

# Get test interface names for local/remote host.
# tst_get_ifaces [TYPE]
# TYPE: { lhost | rhost }; Default value is 'lhost'.
tst_get_ifaces()
{
	local type="${1:-lhost}"
	if [ "$type" = "lhost" ]; then
		echo "$LHOST_IFACES"
	else
		echo "$RHOST_IFACES"
	fi
}

# Get count of test interfaces for local/remote host.
tst_get_ifaces_cnt()
{
	tst_require_cmds awk
	local type="${1:-lhost}"
	echo "$(tst_get_ifaces $type)" | awk '{print NF}'
}

# Get HW addresses from defined test interface names.
# tst_get_hwaddrs [TYPE]
# TYPE: { lhost | rhost }; Default value is 'lhost'.
tst_get_hwaddrs()
{
	local type="${1:-lhost}"
	local addr=
	local list=

	for eth in $(tst_get_ifaces $type); do

		local addr_path="/sys/class/net/${eth}/address"

		case $type in
		lhost) addr=$(cat $addr_path) ;;
		rhost) addr=$(tst_rhost_run -s -c "cat $addr_path")
		esac

		[ -z "$list" ] && list="$addr" || list="$list $addr"
	done
	echo "$list"
}

# Get test HW address.
# tst_hwaddr [TYPE] [LINK]
# TYPE: { lhost | rhost }; Default value is 'lhost'.
# LINK: link number starting from 0. Default value is '0'.
tst_hwaddr()
{
	tst_require_cmds awk

	local type="${1:-lhost}"
	local link_num="${2:-0}"
	local hwaddrs=
	link_num=$(( $link_num + 1 ))
	[ "$type" = "lhost" ] && hwaddrs=$LHOST_HWADDRS || hwaddrs=$RHOST_HWADDRS
	echo "$hwaddrs" | awk '{ print $'"$link_num"' }'
}

# Get test interface name.
# tst_iface [TYPE] [LINK]
# TYPE: { lhost | rhost }; Default value is 'lhost'.
# LINK: link number starting from 0. Default value is '0'.
tst_iface()
{
	tst_require_cmds awk

	local type="${1:-lhost}"
	local link_num="${2:-0}"
	link_num="$(( $link_num + 1 ))"
	echo "$(tst_get_ifaces $type)" | awk '{ print $'"$link_num"' }'
}

# Get IP address
# tst_ipaddr [TYPE]
# TYPE: { lhost | rhost }; Default value is 'lhost'.
tst_ipaddr()
{
	local type="${1:-lhost}"
	if [ "$TST_IPV6" ]; then
		[ "$type" = "lhost" ] && echo "$IPV6_LHOST" || echo "$IPV6_RHOST"
	else
		[ "$type" = "lhost" ] && echo "$IPV4_LHOST" || echo "$IPV4_RHOST"
	fi
}

# Get IP address of unused network, specified either counter and type
# or by net and host.
# counter mode:
# tst_ipaddr_un [-h MIN,MAX] [-n MIN,MAX] [-p] [-c COUNTER] [TYPE]
# net & host mode:
# tst_ipaddr_un [-h MIN,MAX] [-n MIN,MAX] [-p] NET_ID [HOST_ID]
#
# TYPE: { lhost | rhost } (default: 'lhost')
# NET_ID: integer or hex value of net (IPv4: 3rd octet <0,255>, IPv6: 3rd
# hextet <0,65535>)
# HOST_ID: integer or hex value of host (IPv4: 4th octet <0,255>, IPv6: the
# last hextet <0, 65535>, default: 0)
#
# OPTIONS
# -c COUNTER: integer value for counting HOST_ID and NET_ID (default: 1)
#
# -h: specify *host* address range (HOST_ID)
# -h MIN,MAX or -h MIN or -h ,MAX
#
# -n: specify *network* address range (NET_ID)
# -n MIN,MAX or -n MIN or -n ,MAX
#
# -p: print also prefix
tst_ipaddr_un()
{
	local default_max=255
	[ "$TST_IPV6" ] && default_max=65535
	local max_net_id=$default_max
	local min_net_id=0

	local counter host_id host_range is_counter max_host_id min_host_id net_id prefix tmp type

	local OPTIND
	while getopts "c:h:n:p" opt; do
		case $opt in
			c) counter="$OPTARG";;
			h)
				if echo $OPTARG | grep -q ','; then # 'min,max' or 'min,' or ',max'
					min_host_id="$(echo $OPTARG | cut -d, -f1)"
					max_host_id="$(echo $OPTARG | cut -d, -f2)"
				else # min
					min_host_id="$OPTARG"
				fi
				;;
			n)
				if echo $OPTARG | grep -q ','; then # 'min,max' or 'min,' or ',max'
					min_net_id="$(echo $OPTARG | cut -d, -f1)"
					max_net_id="$(echo $OPTARG | cut -d, -f2)"
				else # min
					min_net_id="$OPTARG"
				fi
				;;
			m)
				! tst_is_int "$OPTARG" || [ "$OPTARG" -lt 0 ]|| [ "$OPTARG" -gt $max_net_id ] && \
					tst_brk TBROK "tst_ipaddr_un: -m must be integer <0,$max_net_id> ($OPTARG)"
				[ "$OPTARG" -gt $max_net_id ] && \
					tst_brk TBROK "tst_ipaddr_un: -m cannot be higher than $max_net_id ($OPTARG)"
				max_host_id="$OPTARG"
				;;
			p) [ "$TST_IPV6" ] && prefix="/64" || prefix="/24";;
		esac
	done
	shift $(($OPTIND - 1))
	[ $# -eq 0 -o "$1" = "lhost" -o "$1" = "rhost" ] && is_counter=1

	if [ -z "$min_host_id" ]; then
		[ "$is_counter" ] && min_host_id=1 || min_host_id=0
	fi
	if [ -z "$max_host_id" ]; then
		[ "$is_counter" ] && max_host_id=$((default_max - 1)) || max_host_id=$default_max
	fi

	! tst_is_int "$min_host_id" || ! tst_is_int "$max_host_id" || \
		[ $min_host_id -lt 0 -o $min_host_id -gt $default_max ] || \
		[ $max_host_id -lt 0 -o $max_host_id -gt $default_max ] && \
		tst_brk TBROK "tst_ipaddr_un: HOST_ID must be int in range <0,$default_max> ($min_host_id,$max_host_id)"
	! tst_is_int "$min_net_id" || ! tst_is_int "$max_net_id" || \
		[ $min_net_id -lt 0 -o $min_net_id -gt $default_max ] || \
		[ $max_net_id -lt 0 -o $max_net_id -gt $default_max ] && \
		tst_brk TBROK "tst_ipaddr_un: NET_ID must be int in range <0,$default_max> ($min_net_id,$max_net_id)"

	[ $min_host_id -gt $max_host_id ] && \
		tst_brk TBROK "tst_ipaddr_un: max HOST_ID ($max_host_id) must be >= min HOST_ID ($min_host_id)"
	[ $min_net_id -gt $max_net_id ] && \
		tst_brk TBROK "tst_ipaddr_un: max NET_ID ($max_net_id) must be >= min NET_ID ($min_net_id)"

	# counter
	host_range=$((max_host_id - min_host_id + 1))
	if [ "$is_counter" ]; then
		[ -z "$counter" ] && counter=1
		[ $counter -lt 1 ] && counter=1
		type="${1:-lhost}"
		tmp=$((counter * 2))
		[ "$type" = "rhost" ] && tmp=$((tmp - 1))
		net_id=$(((tmp - 1) / host_range))
		host_id=$((tmp - net_id * host_range + min_host_id - 1))
	else # net_id & host_id
		net_id="$1"
		host_id="${2:-0}"
		if [ "$TST_IPV6" ]; then
			net_id=$(printf %d $net_id)
			host_id=$(printf %d $host_id)
		fi
		host_id=$((host_id % host_range + min_host_id))
	fi

	net_id=$((net_id % (max_net_id - min_net_id + 1) + min_net_id))

	if [ -z "$TST_IPV6" ]; then
		echo "${IPV4_NET16_UNUSED}.${net_id}.${host_id}${prefix}"
		return
	fi

	[ $host_id -gt 0 ] && host_id="$(printf %x $host_id)" || host_id=
	[ $net_id -gt 0 ] && net_id="$(printf %x $net_id)" || net_id=
	[ "$net_id" ] && net_id=":$net_id"
	echo "${IPV6_NET32_UNUSED}${net_id}::${host_id}${prefix}"
}

# tst_init_iface [TYPE] [LINK]
# TYPE: { lhost | rhost }; Default value is 'lhost'.
# LINK: link number starting from 0. Default value is '0'.
tst_init_iface()
{
	local type="${1:-lhost}"
	local link_num="${2:-0}"
	local iface="$(tst_iface $type $link_num)"
	tst_res TINFO "initialize '$type' '$iface' interface"

	if [ "$type" = "lhost" ]; then
		if ip xfrm state 1>/dev/null 2>&1; then
			ip xfrm policy flush || return $?
			ip xfrm state flush || return $?
		fi
		ip link set $iface down || return $?
		ip route flush dev $iface || return $?
		ip addr flush dev $iface || return $?
		ip link set $iface up
		return $?
	fi

	if tst_rhost_run -c "ip xfrm state 1>/dev/null 2>&1"; then
		tst_rhost_run -c "ip xfrm policy flush" || return $?
		tst_rhost_run -c "ip xfrm state flush" || return $?
	fi
	tst_rhost_run -c "ip link set $iface down" || return $?
	tst_rhost_run -c "ip route flush dev $iface" || return $?
	tst_rhost_run -c "ip addr flush dev $iface" || return $?
	tst_rhost_run -c "ip link set $iface up"
}

# tst_add_ipaddr [TYPE] [LINK] [-a IP] [-d] [-q] [-s]
# Options:
# TYPE: { lhost | rhost }, default value is 'lhost'
# LINK: link number starting from 0, default value is '0'
# -a IP: IP address to be added, default value is
# $(tst_ipaddr)/$IPV{4,6}_{L,R}PREFIX
# -d: delete address instead of adding
# -q: quiet mode (don't print info)
# -s: safe option, if something goes wrong, will exit with TBROK
tst_add_ipaddr()
{
	local action="add"
	local addr dad lsafe mask quiet rsafe

	local OPTIND
	while getopts a:dqs opt; do
		case "$opt" in
		a) addr="$OPTARG" ;;
		d) action="del" ;;
		q) quiet=1 ;;
		s) lsafe="ROD"; rsafe="-s" ;;
		*) tst_brk TBROK "tst_add_ipaddr: unknown option: $OPTARG" ;;
		esac
	done
	shift $((OPTIND - 1))

	local type="${1:-lhost}"
	local link_num="${2:-0}"
	local iface=$(tst_iface $type $link_num)

	if [ "$TST_IPV6" ]; then
		dad="nodad"
		[ "$type" = "lhost" ] && mask=$IPV6_LPREFIX || mask=$IPV6_RPREFIX
	else
		[ "$type" = "lhost" ] && mask=$IPV4_LPREFIX || mask=$IPV4_RPREFIX
	fi
	[ -n "$addr" ] || addr="$(tst_ipaddr $type)"
	echo $addr | grep -q / || addr="$addr/$mask"

	if [ $type = "lhost" ]; then
		[ "$quiet" ] || tst_res TINFO "$action local addr $addr"
		$lsafe ip addr $action $addr dev $iface $dad
		return $?
	fi

	[ "$quiet" ] || tst_res TINFO "$action remote addr $addr"
	tst_rhost_run $rsafe -c "ip addr $action $addr dev $iface $dad"
}

# tst_del_ipaddr [ tst_add_ipaddr options ]
# Delete IP address
tst_del_ipaddr()
{
	tst_add_ipaddr -d $@
}

# tst_restore_ipaddr [TYPE] [LINK]
# Restore default ip addresses defined in network.sh
# TYPE: { lhost | rhost }; Default value is 'lhost'.
# LINK: link number starting from 0. Default value is '0'.
tst_restore_ipaddr()
{
	tst_require_cmds ip
	tst_require_root

	local type="${1:-lhost}"
	local link_num="${2:-0}"

	tst_init_iface $type $link_num || return $?

	local ret=0
	local backup_tst_ipv6=$TST_IPV6
	TST_IPV6= tst_add_ipaddr $type $link_num || ret=$?
	TST_IPV6=6 tst_add_ipaddr $type $link_num || ret=$?
	TST_IPV6=$backup_tst_ipv6

	return $ret
}

# tst_wait_ipv6_dad [LHOST_IFACE] [RHOST_IFACE]
# wait for IPv6 DAD completion
tst_wait_ipv6_dad()
{
	local ret=
	local i=
	local iface_loc=${1:-$(tst_iface)}
	local iface_rmt=${2:-$(tst_iface rhost)}

	for i in $(seq 1 50); do
		ip a sh $iface_loc | grep -q tentative
		ret=$?

		tst_rhost_run -c "ip a sh $iface_rmt | grep -q tentative"

		[ $ret -ne 0 -a $? -ne 0 ] && return

		[ $(($i % 10)) -eq 0 ] && \
			tst_res TINFO "wait for IPv6 DAD completion $((i / 10))/5 sec"

		tst_sleep 100ms
	done
}

# tst_set_sysctl NAME VALUE [safe]
# It can handle netns case when sysctl not namespaceified.
tst_set_sysctl()
{
	local name="$1"
	local value="$2"
	local safe=
	[ "$3" = "safe" ] && safe="-s"

	local rparam=

	tst_net_run $safe -r '-e' "sysctl -q -w $name=$value"
}

tst_cleanup_rhost()
{
	tst_rhost_run -c "rm -rf $TST_TMPDIR"
}

tst_default_max_pkt()
{
	local mtu="$(cat /sys/class/net/$(tst_iface)/mtu)"

	echo "$((mtu + mtu / 10))"
}

# Management Link
export PASSWD="${PASSWD:-}"

# Test Links
# IPV{4,6}_{L,R}HOST can be set with or without prefix (e.g. IP or IP/prefix),
# but if you use IP/prefix form, /prefix will be removed by tst_net_vars.
IPV4_LHOST="${IPV4_LHOST:-10.0.0.2/24}"
IPV4_RHOST="${IPV4_RHOST:-10.0.0.1/24}"
IPV6_LHOST="${IPV6_LHOST:-fd00:1:1:1::2/64}"
IPV6_RHOST="${IPV6_RHOST:-fd00:1:1:1::1/64}"

# tst_net_ip_prefix
# Strip prefix from IP address and save both If no prefix found sets
# default prefix.
#
# tst_net_iface_prefix reads prefix and interface from rtnetlink.
# If nothing found sets default prefix value.
#
# tst_net_vars exports environment variables related to test links and
# networks that aren't reachable through the test links.
#
# For full list of exported environment variables see:
# tst_net_ip_prefix -h
# tst_net_iface_prefix -h
# tst_net_vars -h
if [ -z "$_tst_net_parse_variables" ]; then
	eval $(tst_net_ip_prefix $IPV4_LHOST || echo "exit $?")
	eval $(tst_net_ip_prefix -r $IPV4_RHOST || echo "exit $?")
	eval $(tst_net_ip_prefix $IPV6_LHOST || echo "exit $?")
	eval $(tst_net_ip_prefix -r $IPV6_RHOST || echo "exit $?")
fi

[ "$TST_INIT_NETNS" != "no" ] && init_ltp_netspace

if [ -z "$_tst_net_parse_variables" ]; then
	eval $(tst_net_iface_prefix $IPV4_LHOST || echo "exit $?")
	eval $(tst_rhost_run -c 'tst_net_iface_prefix -r '$IPV4_RHOST \
		|| echo "exit $?")
	eval $(tst_net_iface_prefix $IPV6_LHOST || echo "exit $?")
	eval $(tst_rhost_run -c 'tst_net_iface_prefix -r '$IPV6_RHOST \
		|| echo "exit $?")

	eval $(tst_net_vars $IPV4_LHOST/$IPV4_LPREFIX \
		$IPV4_RHOST/$IPV4_RPREFIX || echo "exit $?")
	eval $(tst_net_vars $IPV6_LHOST/$IPV6_LPREFIX \
		$IPV6_RHOST/$IPV6_RPREFIX || echo "exit $?")

	tst_res TINFO "Network config (local -- remote):"
	tst_res TINFO "$LHOST_IFACES -- $RHOST_IFACES"
	tst_res TINFO "$IPV4_LHOST/$IPV4_LPREFIX -- $IPV4_RHOST/$IPV4_RPREFIX"
	tst_res TINFO "$IPV6_LHOST/$IPV6_LPREFIX -- $IPV6_RHOST/$IPV6_RPREFIX"
	export _tst_net_parse_variables="yes"
fi

# Warning: make sure to set valid interface names and IP addresses below.
# Set names for test interfaces, e.g. "eth0 eth1"
# This is fallback for LHOST_IFACES in case tst_net_vars finds nothing or we
# want to use more ifaces.
export LHOST_IFACES RHOST_IFACES
# Set corresponding HW addresses, e.g. "00:00:00:00:00:01 00:00:00:00:00:02"
export LHOST_HWADDRS="$(tst_get_hwaddrs lhost)"
export RHOST_HWADDRS="$(tst_get_hwaddrs rhost)"
