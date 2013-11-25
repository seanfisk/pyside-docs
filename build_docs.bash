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
	# Build the Shiboken docs as well.
	make doc

	# Install Shiboken to the prefix.
	make install

	popd # shiboken/build
fi

# Save path to ShibokenConfig.cmake.
readonly SHIBOKEN_CONFIG_DIR=shiboken/build/data

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
	# Apply patch to account for bugs:
	# - sphinx-build doesn't need to by run with a Python interpreter. In the case of my machine, sphinx-build is stubbed out by pyenv and is actually a bash script, so this causes generation to fail.
	# - shiboken doesn't accept the argument `--documentation-only', despite being documented as accepting it.
	patch -p1 -d pyside <<'EOF'
diff --git a/doc/CMakeLists.txt b/doc/CMakeLists.txt
index 967c289..9a0f972 100644
--- a/doc/CMakeLists.txt
+++ b/doc/CMakeLists.txt
@@ -15,7 +15,7 @@ if (${SPHINX_BUILD} MATCHES "SPHINX_BUILD-NOTFOUND")
 endif()
 add_custom_target(apidoc
                   COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_CURRENT_BINARY_DIR}/rst
-                  COMMAND ${SHIBOKEN_PYTHON_INTERPRETER} ${SPHINX_BUILD} -b html  ${CMAKE_CURRENT_BINARY_DIR}/rst html
+                  COMMAND ${SPHINX_BUILD} -b html  ${CMAKE_CURRENT_BINARY_DIR}/rst html
                  )
 
 # create conf.py based on conf.py.in
@@ -29,7 +29,6 @@ add_custom_target("docrsts"
             --api-version=${SUPPORTED_QT_VERSION}
             --typesystem-paths="${pyside_SOURCE_DIR}${PATH_SEP}${QtCore_SOURCE_DIR}${PATH_SEP}${QtDeclarative_SOURCE_DIR}${PATH_SEP}${QtGui_SOURCE_DIR}${PATH_SEP}${QtGui_BINARY_DIR}${PATH_SEP}${QtHelp_SOURCE_DIR}${PATH_SEP}${QtMaemo5_SOURCE_DIR}${PATH_SEP}${QtMultimedia_SOURCE_DIR}${PATH_SEP}${QtNetwork_SOURCE_DIR}${PATH_SEP}${QtOpenGL_SOURCE_DIR}${PATH_SEP}${QtScript_SOURCE_DIR}${PATH_SEP}${QtScriptTools_SOURCE_DIR}${PATH_SEP}${QtSql_SOURCE_DIR}${PATH_SEP}${QtSvg_SOURCE_DIR}${PATH_SEP}${QtTest_SOURCE_DIR}${PATH_SEP}${QtUiTools_SOURCE_DIR}${PATH_SEP}${QtWebKit_SOURCE_DIR}${PATH_SEP}${QtXml_SOURCE_DIR}${PATH_SEP}${QtXmlPatterns_SOURCE_DIR}${PATH_SEP}${phonon_SOURCE_DIR}"
             --library-source-dir=${QT_SRC_DIR}
-            --documentation-only
             --documentation-data-dir=${DOC_DATA_DIR}
             --output-directory=${CMAKE_CURRENT_BINARY_DIR}/rst
             --documentation-code-snippets-dir=${CMAKE_CURRENT_SOURCE_DIR}/codesnippets${PATH_SEP}${CMAKE_CURRENT_SOURCE_DIR}/codesnippets/examples
EOF
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

# Account for a bug (?) in the build process.
cp PySide/QtCore/typesystem_core.xml doc

# Verbose so if it crashes we know where.
make VERBOSE=1 apidoc

popd # pyside/build
popd # src
