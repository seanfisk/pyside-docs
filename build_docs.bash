#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o xtrace

mkdir -p src

# Grab the Qt source code for which documentation would like to be built.
pushd src
readonly QT_VERSION=4.8.5
readonly QT_SRC_DIR=qt-everywhere-opensource-src-$QT_VERSION
readonly QT_SRC_TARBALL=$QT_SRC_DIR.tar.gz
if [[ ! -d $QT_SRC_DIR ]]; then
	wget "http://download.qt-project.org/official_releases/qt/4.8/$QT_VERSION/$QT_SRC_TARBALL" --output-document=- | tar -xz
fi

# Grab the Qt 4.6.4 source code for qdoc3.
readonly QT_46_SRC_DIR=qt-everywhere-opensource-src-4.6.4
readonly QDOC3_DIR=tools/qdoc3
readonly QT_46_SRC_TARBALL=$QT_46_SRC_DIR.tar.gz
if [[ ! -d $QT_46_SRC_DIR ]]; then
	wget "http://download.qt-project.org/archive/qt/4.6/$QT_46_SRC_TARBALL" --output-document=- | tar -xz
fi

# Compile qdoc3.
pushd $QT_46_SRC_DIR
# Configure, and disable everything we possibly can. qdoc3 can be built without configuring using an existing Qt installation and just qmake'ing its .pro file, but using libraries from another version of Qt than what was intended is dangerous and usually ends up in memory errors. I tried building qdoc3 for 4.6.4 with Qt 4.8.5 headers and it blew up. So let's avoid that.
./configure \
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
	-no-rpath \
	-no-nis \
	-no-cups \
	-no-iconv \
	-no-pch \
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

# Make qdoc3 itself.
pushd $QDOC3_DIR
make -j4
popd # $QDOC3_DIR
popd # $QT_46_SRC_DIR

popd # src

# Copy qdoc3 to bin directory.
mkdir -p bin
cp src/$QT_46_SRC_DIR/bin/qdoc3 bin

# Download and build shiboken.
pushd src
if [[ ! -d shiboken ]]; then
	git clone https://git.gitorious.org/pyside/shiboken.git
fi
mkdir -p shiboken/build
pushd shiboken/build
cmake ..
make -j4

# Save path to ShibokenConfig.cmake.
readonly SHIBOKEN_CONFIG_DIR=$PWD/data

popd # shiboken/build
popd # src

# Copy shiboken to bin directory.
cp src/shiboken/build/generator/shiboken bin

# Add bin directory to PATH and rehash.
export PATH=$PWD/bin:$PATH
hash -r

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
