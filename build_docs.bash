#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o xtrace

WITH_LOCAL=false
if [[ $# -gt 0 && $1 == --with-local ]]; then
	WITH_LOCAL=true
	readonly LOCAL_DIR=~/.local
fi

mkdir -p prefix
pushd prefix
readonly PREFIX=$PWD

mkdir -p src
pushd src

# Download the Qt source code for which documentation would like to be built.
readonly QT_VERSION=4.8.5
readonly QT_SRC_DIR=qt-everywhere-opensource-src-$QT_VERSION
readonly QT_SRC_TARBALL=$QT_SRC_DIR.tar.gz
if [[ ! -d $QT_SRC_DIR ]]; then
	wget "http://download.qt-project.org/official_releases/qt/4.8/$QT_VERSION/$QT_SRC_TARBALL" --output-document=- | tar -xz
fi

# Compile qdoc3 if it doesn't exist already.
if [[ ! -x "$PREFIX/bin/qdoc3" ]]; then
	# Grab the Qt 4.6.4 source code for qdoc3.
	readonly QT_46_SRC_DIR=qt-everywhere-opensource-src-4.6.4
	readonly QDOC3_DIR=tools/qdoc3
	readonly QT_46_SRC_TARBALL=$QT_46_SRC_DIR.tar.gz
	if [[ ! -d $QT_46_SRC_DIR ]]; then
		wget "http://download.qt-project.org/archive/qt/4.6/$QT_46_SRC_TARBALL" --output-document=- | tar -xz
	fi

	pushd $QT_46_SRC_DIR
	# Configure, and disable everything we possibly can. qdoc3 can be built without configuring using an existing Qt installation and just qmake'ing its .pro file, but using libraries from another version of Qt than what was intended is dangerous and usually ends up in memory errors. I tried building qdoc3 for 4.6.4 with Qt 4.8.5 headers and it blew up. So let's avoid that.
	./configure \
		-prefix "$PREFIX" \
		-fast \
		-nomake demos \
		-nomake examples \
		-opensource \
		-confirm-license \
		-no-largefile \
		-no-exceptions \
		-no-accessibility \
		-no-stl \
		-no-qt3support \
		-no-gif \
		-no-libtiff \
		-no-libpng \
		-no-libmng \
		-no-libjpeg \
		-no-nis \
		-no-cups \
		-no-iconv \
		-no-dbus \
		-no-separate-debug-info \
		-no-mmx \
		-no-3dnow \
		-no-sse \
		-no-sse2 \
		-no-optimized-qmake \
		-no-xmlpatterns \
		-no-multimedia \
		-no-phonon \
		-no-phonon-backend \
		-no-audio-backend \
		-no-openssl \
		-no-gtkstyle \
		-no-svg \
		-no-webkit \
		-no-javascript-jit \
		-no-script \
		-no-scripttools \
		-no-declarative

	# Make qdoc3 library requirements. Order matters!
	make sub-{tools-bootstrap,moc,corelib,xml}

	# Make and install qdoc3 itself.
	pushd $QDOC3_DIR
	make -j4
	make install
	popd # $QDOC3_DIR
	popd # $QT_46_SRC_DIR
fi

# Compile shiboken if it doesn't already exist.
if [[ ! -x "$PREFIX/bin/shiboken" ]]; then
	# Download and build shiboken.
	if [[ ! -d shiboken ]]; then
		git clone https://git.gitorious.org/pyside/shiboken.git
	fi
	mkdir -p shiboken/build
	pushd shiboken/build

	if $WITH_LOCAL; then
		EXTRA_CMAKE_FLAGS=("-DCMAKE_INSTALL_PREFIX=$LOCAL_DIR")
	fi

	cmake \
		-DCMAKE_INSTALL_PREFIX="$PREFIX" \
		"${EXTRA_CMAKE_FLAGS[@]:+${EXTRA_CMAKE_FLAGS[@]}}" \
		..
	make -j4
	make install

	# Save path to ShibokenConfig.cmake.
	readonly SHIBOKEN_CONFIG_DIR=$PWD/data

	popd # shiboken/build
fi

popd # src

# Add bin directory to PATH and rehash.
export PATH=$PWD/bin:$PATH
hash -r
if $WITH_LOCAL; then
	# Shiboken needs this to find symbols succesfully.
	export LD_LIBRARY_PATH=$LOCAL_DIR/lib
fi

# Download and build PySide API docs.
pushd src
if [[ ! -d pyside ]]; then
	git clone https://git.gitorious.org/pyside/pyside.git
fi
if [[ -d pyside/build ]]; then
	rm -r pyside/build
fi
mkdir -p pyside/build
readonly ABSOLUTE_QT_SRC_DIR=$PWD/$QT_SRC_DIR
pushd pyside/build
cmake .. \
	-DALTERNATIVE_QT_INCLUDE_DIR="$ABSOLUTE_QT_SRC_DIR/include" \
	-DQT_SRC_DIR="$ABSOLUTE_QT_SRC_DIR" \
	-DShiboken_DIR="$SHIBOKEN_CONFIG_DIR"
# Verbose so if it crashes we know where.
make VERBOSE=1 apidoc
popd # pyside/build
popd # src
