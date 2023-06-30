#!/bin/sh -eu
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (c) 2023 Petr Vorel <pvorel@suse.cz>
# Tag iputils release.

basedir="$(dirname "$0")"
cd "$basedir/.."
. "$basedir/lib.sh"

upstream_git="iputils/iputils"
tag="$(date +%Y%m%d)"
old_tag="$(git describe --abbrev=0)"
tag_msg="iputils-$tag"
relnotes="/tmp/$(basename $upstream_git)-release-$tag"

if ! git ls-remote --get-url origin | grep -q $upstream_git; then
	quit "Not an upstream project"
fi

if ! git --no-pager diff --exit-code; then
	quit "Please commit your changes before making new release"
fi

if git show "$tag" 2> /dev/null; then
	quit "Tag '$tag' already exists"
fi

if grep -q "version.*$tag" meson.build; then
	quit "Tag '$tag' already in meson.build file"
fi

title "git tag"
echo "new tag: '$tag', previous tag: '$old_tag'"
sed --in-place "s/version : '.*')/version : '$tag')/" meson.build
git add meson.build
rod git commit -S --signoff --message "release: $tag_msg" meson.build
rod git tag --sign --annotate "$tag" --message "$tag_msg"
git --no-pager show "$tag" --show-signature

ask "Please check tag and signature"

title "Creating release notes skeletion"
cat > "$relnotes" <<EOF
TODO: Add changelog

## credit
Many thanks to the people contributing to this release:
\`\`\`
    $ git shortlog -sen $old_tag..
EOF
git shortlog -s -n "$old_tag".. >> "$relnotes"

cat >> "$relnotes" <<EOF
\`\`\`

Also thanks to patch reviewers:

$ git log $old_tag.. | grep -Ei '(reviewed|acked)-by:' | sed 's/.*by: //' | sort | uniq -c | sort -n -r
\`\`\`
EOF

git log "$old_tag".. | grep -Ei '(reviewed|acked)-by:' | sed 's/.*by: //' | sort | uniq -c | sort -n -r >> "$relnotes"

cat >> "$relnotes" <<EOF
\`\`\`

and testers:
$ git log $old_tag.. | grep -Ei 'tested-by:' | sed 's/.*by: //' | sort | uniq -c | sort -n -r
\`\`\`
EOF
git log "$old_tag".. | grep -Ei 'tested-by:' | sed 's/.*by: //' | sort | uniq -c | sort -n -r >> "$relnotes"
echo '```'  >> "$relnotes"

title "git push"
ask "Pushing changes to upstream git"
rod git push origin master:master
git push origin "$tag"
