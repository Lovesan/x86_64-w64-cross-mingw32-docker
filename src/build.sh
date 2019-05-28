#!/bin/bash
set -exo pipefail

gcc_version=$1
if [ -z $gcc_version ]; then
    >&2 "Usage $0 <version>"
    exit 1
fi

topdir=/app
srcdir=$topdir/src
builddir=$topdir/xbuild
prefix=/opt/x86_64-w64-cross-mingw32
sysroot=$prefix
build=`dpkg-architecture --query DEB_BUILD_GNU_TYPE`
host=$build
target=x86_64-w64-mingw32
base_config_args="--prefix=$prefix \
                  --build=$build \
                  --host=$host \
                  --with-sysroot=$sysroot \
                  --enable-shared \
                  --disable-static"
nproc=$((`grep -c ^processor /proc/cpuinfo` + 1))
gmp_version=6.1.2
mpfr_version=4.0.2
mpc_version=1.1.0
isl_version=0.18
mingw_version=v6.0.0
binutils_version=2.32
mingw_dist_url=https://downloads.sourceforge.net/project/mingw-w64/mingw-w64/mingw-w64-release

function mkdir_cd {
    mkdir -p $1 && cd $1
}

function download_gnu {
    local ext
    ext=$3
    if [ -z $ext ]; then
        ext=bz2
    fi
    cd $srcdir
    if [ ! -f $1-$2.tar.$ext ]; then
        wget -q https://ftp.gnu.org/gnu/$1/$1-$2.tar.$ext
    fi
    tar xaf $1-$2.tar.$ext
}

function download_gcc {
    cd $srcdir
    if [ ! -f gcc-$gcc_version.tar.xz ]; then
        wget -q https://ftp.gnu.org/gnu/gcc/gcc-$gcc_version/gcc-$gcc_version.tar.xz
    fi
    tar xaf gcc-$gcc_version.tar.xz
}

function download_isl {
    cd $srcdir
    if [ ! -f isl-$isl_version.tar.bz2 ]; then
        wget -q https://gcc.gnu.org/pub/gcc/infrastructure/isl-${isl_version}.tar.bz2
    fi
    tar xaf isl-${isl_version}.tar.bz2 && \
    cd isl-$isl_version && autoreconf -vfi
}

function download_mingw {
    cd $srcdir
    if [ ! -f mingw-w64-$mingw_version.tar.bz2 ]; then
        wget -q $mingw_dist_url/mingw-w64-${mingw_version}.tar.bz2
    fi
    tar xaf mingw-w64-${mingw_version}.tar.bz2    
}

function remove_la {
    for f in `find $prefix/ -type f -iname '*.la'`; do rm $f; done
}

function make_symlinks {
    cd $prefix
    mkdir $target
    mkdir lib
    ln -s $target mingw
    ln -s lib lib64
    cd mingw
    mkdir lib
    ln -s lib lib64
}

function do_make {
    make -j $nproc $@
}

function do_make_install {
    do_make $@ && make install
}

function do_make_install_strip {
    do_make $@ && make install-strip
}

function configure_binutils {
    $srcdir/binutils-${binutils_version}/configure --prefix=$prefix \
                                                   --with-sysroot=$sysroot \
                                                   --build=$build \
                                                   --host=$host \
                                                   --target=$target \
                                                   --disable-isl-version-check \
                                                   --disable-nls \
                                                   --disable-rpath \
                                                   --disable-multilib                           
}

function configure_headers {
    $srcdir/mingw-w64-$mingw_version/mingw-w64-headers/configure --prefix=$prefix/$target \
                                                                 --host=$target \
                                                                 --enable-idl \
                                                                 --enable-secure-api
}

function configure_crt {
    $srcdir/mingw-w64-$mingw_version/mingw-w64-crt/configure --prefix=$prefix/$target \
                                                             --with-sysroot=$sysroot/$target \
                                                             --host=$target \
                                                             --disable-lib32
}

function configure_winpthreads {
    $srcdir/mingw-w64-$mingw_version/mingw-w64-libraries/winpthreads/configure \
        --prefix=$prefix/$target \
        --with-sysroot=$sysroot/$target \
        --host=$target \
        --enable-static --enable-shared
}

function configure_gcc {
    $srcdir/gcc-$gcc_version/configure --prefix=$prefix \
                                       --with-sysroot=$sysroot \
                                       --build=$build \
                                       --host=$host \
                                       --target=$target \
                                       --enable-shared \
                                       --enable-static \
                                       --disable-isl-version-check \
                                       --disable-multilib \
                                       --disable-nls \
                                       --enable-lto \
                                       --enable-languages=c,c++ \
                                       --disable-bootstrap \
                                       --disable-symvers \
                                       --disable-rpath \
                                       --without-x \
                                       --enable-graphite \
                                       --enable-libgomp \
                                       --disable-win32-registry \
                                       --disable-libstdcxx-debug \
                                       --enable-libstdcxx-pch \
                                       --enable-libatomic \
                                       --enable-threads=posix
}

function link_sources {
    ln -s $srcdir/gmp-$gmp_version $1/gmp && \
    ln -s $srcdir/mpfr-$mpfr_version $1/mpfr && \
    ln -s $srcdir/mpc-$mpc_version $1/mpc && \
    ln -s $srcdir/isl-$isl_version $1/isl
}

function build_binutils {
    mkdir_cd $builddir/binutils && \
    configure_binutils && do_make_install_strip
}

function build_headers {
    mkdir_cd $builddir/mingw-w64-headers && \
    configure_headers && do_make_install
}

function build_crt {
    mkdir_cd $builddir/mingw-w64-crt
    configure_crt && do_make_install && \
    mkdir_cd $builddir/winpthreads && \
    configure_winpthreads && do_make_install
}

function build_gcc {
    mkdir_cd $builddir/gcc && \
    configure_gcc && \
    do_make all-gcc && \
    make install-gcc && \
    build_crt && \
    cd $builddir/gcc && \
    do_make_install_strip
}

mkdir -p $prefix
mkdir -p $srcdir
mkdir -p $builddir
make_symlinks

download_gnu gmp $gmp_version
download_gnu mpfr $mpfr_version
download_gnu mpc $mpc_version gz
download_isl
download_mingw
download_gnu binutils $binutils_version
download_gcc

link_sources "binutils-$binutils_version"
link_sources "gcc-$gcc_version"

build_headers
build_binutils
build_gcc
