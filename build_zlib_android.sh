#!/bin/bash

# Example
# buildzlibandroid 1 65 1

# Script arguments:
# $1: <major> representing the major boost version number to install
# $2: <minor> representing the minor boost version number to install
# $3: <patch> representing the patch boost version number to install
# $4: 'force' if installation should proceed even if /usr/local/include/boost already exists, it removes /usr/local/include/boost and /usr/local/lib/lobboost_*!

SAVE=`pwd`

# major version number, typically 1
if [[ ! $1 ]];then
    MAJOR=1
else
    MAJOR=$1
fi

# minor version number, e.g. 65 
if [[ ! $2 ]];then
    MINOR=2
else
    MINOR=$2
fi

# patch number, typically a low number, often 0
if [[ ! $3 ]];then
    PATCH=11
else
    PATCH=$3
fi

# build APP
APP_NAME=zlib
# Directory where to unzip the tarball
DIR1=${APP_NAME}-${MAJOR}.${MINOR}.${PATCH}
echo "build: ${DIR1}"

# Directory where to copy from DIR1, and having some subsequent changes
DIR2=${MAJOR}.${MINOR}.${PATCH}
TARNAME=${APP_NAME}-${MAJOR}.${MINOR}.${PATCH}.tar.xz

DOWNLOAD="https://zlib.net/zlib-1.2.11.tar.xz"

BUILD_DIR=~/${APP_NAME}/build/arm64-v8a
INSTALL_DIR=~/${APP_NAME}/install/arm64-v8a

# $NDK is the installation root for the Android NDK
# After Android Studio is installed we assume the Android NDK is located here
NDK=/opt/android-ndk/ndk

# Path to Android toolchain (i.e. android compilers etc), relative to ~/boost
REL_TOOLCHAIN=android-tool-chain/arm64-v8a

ABS_TOOLCHAIN=~/${APP_NAME}/${REL_TOOLCHAIN}

mkdir -p ~/${APP_NAME}
cd ~/${APP_NAME}

if [ "$4" = "force" ]; then
    # Force boost to be downloaded and unpacked again
    rm -f ${TARNAME}
    sudo rm -rf ${DIR1}
    sudo rm -rf ${DIR2}
fi

if [ -e ${TARNAME} ]; then
    echo ${TARNAME} already exists, no need to download from ${DOWNLOAD}
else
    echo Downloading ${TARNAME}
    wget -c "$DOWNLOAD" -O ${TARNAME}
fi


if [ -d ${DIR1} ]; then
    echo folder ${DIR1} already exists, no need to uncompress tarball ${TARNAME}
else
    echo uncompressing tarball
    tar -vxf ${TARNAME}
fi


if [ -d ${DIR2} ]; then
    echo folder ${DIR2} already exists, no need to copy from ${DIR1}
else
    cp -R ${DIR1} ${DIR2}
fi

if [ -d ${ABS_TOOLCHAIN} ]; then
    echo folder ${ABS_TOOLCHAIN} already exists, no need to use make_standalone_toolchain.py to create standalone toolchain.
else
    # Create a standalone toolchain for arm64-v8a as described in https://developer.android.com/ndk/guides/standalone_toolchain.html
    # arm64 implies arm64-v8a, and the default STL is gnustl and api=21, but we set it anyway.
    # The install dir is relative to the current directory - i.e. so it is ~/boost/android-tool-chain/arm64-v8a, these folders are created automatically
    echo creating toolchain ${ABS_TOOLCHAIN}
    $NDK/build/tools/make_standalone_toolchain.py --arch arm64 --api 21 --stl=gnustl --install-dir=$REL_TOOLCHAIN
fi

# Add the standalone toolchain to the search path.
export PATH=${ABS_TOOLCHAIN}/bin:$PATH

echo "PATH=$PATH"
echo

# Tell configure what tools to use.
target_host=aarch64-linux-android
export AR=$target_host-ar
export AS=$target_host-clang
export CC=$target_host-clang
export CXX=$target_host-clang++
export LD=$target_host-ld
export STRIP=$target_host-strip

echo "------------ $AR --------------"
$AR -V

echo "------------ $CC --------------"
$CC --version

echo "------------ $LD --------------"
$LD --version

echo "------------ $STRIP --------------"
$STRIP --version

# Tell configure what flags Android requires.
export CFLAGS="-fPIE -fPIC"
export LDFLAGS="-pie"

#" -march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=softfp"\
#" --sysroot=/home/david/Android/Sdk/ndk-bundle/platforms/android-9/arch-arm"\

CXXFLAGS=\
"-I${ABS_TOOLCHAIN}/sysroot/usr/include"\
" -I${ABS_TOOLCHAIN}/include/c++/4.9.x"\
" -fPIC -Wno-unused-variable"\
" -std=c++11"

echo "CXXFLAGS=$CXXFLAGS"
echo

LINKFLAGS=\
" -L${ABS_TOOLCHAIN}/sysroot/usr/lib"

echo "LINKFLAGS=$LINKFLAGS"
echo

cd ${DIR2}

CHOST=arm \
CC=$CC \
AR=$AR \
./configure \
--prefix=$INSTALL_DIR
make
make install

echo
if [ $? -eq 0 ]
then
  echo "Successfully built ${APP_NAME} libraries"
else
  echo "Error building ${APP_NAME} libraries, return code: $?" >&2
fi

cd $SAVE
