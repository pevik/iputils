#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (c) 2018-2025 Petr Vorel <pvorel@suse.cz>
set -ex

zypper --non-interactive install --no-recommends \
	clang \
	docbook_5 \
	docbook5-xsl-stylesheets \
	file \
	gcc \
	gettext-tools \
	git \
	iproute2 \
	jq \
	libcap-devel \
	libcap-progs \
	libidn2-devel \
	libxslt-tools \
	meson \
	ninja \
	perl-Test-Command \
	pkg-config
