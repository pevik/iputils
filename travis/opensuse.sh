#!/bin/sh
# Copyright (c) 2018 Petr Vorel <pvorel@suse.cz>

zypper --version

zypper --non-interactive install --no-recommends \
	clang \
	docbook_5 \
	docbook5-xsl-stylesheets \
	gcc \
	gettext-tools \
	libcap-devel \
	libcap-progs \
	libidn2-devel \
	libnettle-devel \
	libxslt-tools \
	make \
	meson \
	ninja \
	openssl-devel \
	pkg-config \
	which
ret=$?

echo "=== START /var/log/zypper.log ==="
cat /var/log/zypper.log
echo "=== END /var/log/zypper.log ==="
exit $ret
