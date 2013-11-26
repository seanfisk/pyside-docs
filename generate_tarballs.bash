#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o xtrace

mkdir -p dist

readonly VERSION=1.2.1

# Use GNU tar on Mac OS X (installed using Homebrew with `g' prefix). This script won't work with BSD tar.
if hash gtar >/dev/null 2>&1; then
	TAR=$(which gtar)
else
	TAR=$(which tar)
fi

if ! "$TAR" --version | grep --quiet --fixed-strings GNU; then
	echo 'This script requires GNU tar.' >&2
	exit 1
fi

for tree in pyside shiboken; do
	dir_name="$tree-$VERSION-docs"
	cp -r "prefix/src/$tree/build/doc/html" "dist/$dir_name"
	pushd dist
	"$TAR" --create --gzip --file="$dir_name.tar.gz" "$dir_name" &
	"$TAR" --create --xz --file="$dir_name.tar.xz" "$dir_name" &
	zip --recurse-paths --quiet "$dir_name.zip" "$dir_name" &
	popd # dist
done

wait # for subprocesses to complete
