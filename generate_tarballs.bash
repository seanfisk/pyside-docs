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

SOFTWARE_NAMES=(pyside shiboken apiextractor)
SOFTWARE_DIRS=(pyside/build shiboken/build shiboken/build/ApiExtractor)
for ((i=0;i<${#SOFTWARE_NAMES[@]};++i)) do
	dir_name="${SOFTWARE_NAMES[$i]}-$VERSION-docs"
	cp -r "prefix/src/${SOFTWARE_DIRS[$i]}/doc/html" "dist/$dir_name"
	pushd dist
	"$TAR" --create --gzip --file="$dir_name.tar.gz" "$dir_name" &
	"$TAR" --create --xz --file="$dir_name.tar.xz" "$dir_name" &
	zip --recurse-paths --quiet "$dir_name.zip" "$dir_name" &
	popd # dist
done

wait # for subprocesses to complete
