#!/bin/bash
#
# $Id$
#
# @brief Build cross compiler for ARM Cortex M3 processor
# 
# Builds a bare-metal cross GNU toolchain targetting the ARM Cortex M3
# microprocessor in EABI mode and using the newlib embedded C library.
#
# @note The newlib C library is checked out from CVS, so for a
# deterministic build you must fix this. I tested toolchains around
# July 12th 2008. Also, it means the cvs checkout asks for a password;
# use 'anoncvs'.
#
# @note This script overrides newlib's autoconf 2.59 version dependency
# to 2.61.
#
# @version 2008-07-12
# @author Leon Woestenberg <leon@sidebranch.com>
# @see http://www.sidebranch.com/
# @note This script was tested on a Ubuntu Linux 8.04 x86 host.
#
# @note You need to pre-install some Ubuntu packages on your host:
# sudo apt-get install flex bison autoconf texinfo
# and for GDB: 
# sudo apt-get install libncurses5-dev 
#
# Modifiche da parte di lancos, tra cui aggiunto insight-gdb e modificato
# opzioni della newlib, nonche` scaricamento della newlib da sito ufficiale.

set -e

CORTEX_TOPDIR=`pwd`

DOWNLOAD_DIR=${CORTEX_TOPDIR}/downloads

#Dove verra` installato il toolchain
TOOLCHAIN_PATH=${HOME}/stm32

#TOOLCHAIN_TARGET=arm-elf
TOOLCHAIN_TARGET=arm-lancos-eabi

mkdir -p ${TOOLCHAIN_PATH}

if touch ${TOOLCHAIN_PATH}/need_write_access_here
  then
	echo "Install dir: ${TOOLCHAIN_PATH}"
	rm -f ${TOOLCHAIN_PATH}/need_write_access_here
  else
	echo "Need ${TOOLCHAIN_PATH} directory with write access."
	exit 1
fi

if [ ! -d ${DOWNLOAD_DIR} ]; then
	mkdir ${DOWNLOAD_DIR}
fi

BINUTILS_VER=2.19.1
GDB_VER=6.8
GCC_VER=4.4.1
GMP_VER=4.3.1
MPFR_VER=2.4.1
NEWLIB_VER=1.17.0
INSIGHT_VER=6.8-1

if [ "$1" == "local" ]; then
#Usa percorsi locali
LOCAL_PATH=http://server.eptar.com/software/ARM/gcc-src
echo "Download pacchetti da ${LOCAL_PATH}"
BINUTILS_PATH=${LOCAL_PATH}
GDB_PATH=${LOCAL_PATH}
GCC_PATH=${LOCAL_PATH}
GMP_PATH=${LOCAL_PATH}
MPFR_PATH=${LOCAL_PATH}
NEWLIB_PATH=${LOCAL_PATH}
INSIGHT_PATH=${LOCAL_PATH}
else
#Usa percorsi remoti (tramite wget)
BINUTILS_PATH=http://ftp.gnu.org/pub/gnu/binutils
GDB_PATH=http://ftp.gnu.org/pub/gnu/gdb
GCC_PATH=http://ftp.gnu.org/pub/gnu/gcc
GMP_PATH=http://ftp.gnu.org/pub/gnu/gmp
MPFR_PATH=http://www.mpfr.org/mpfr-current
NEWLIB_PATH=ftp://sources.redhat.com/pub/newlib
INSIGHT_PATH=ftp://sourceware.org/pub/insight/releases
fi

#Inizia download (solo se necessario)
cd ${DOWNLOAD_DIR}
if [ ! -f ${DOWNLOAD_DIR}/binutils-${BINUTILS_VER}.tar.bz2 ]; then
	wget ${BINUTILS_PATH}/binutils-${BINUTILS_VER}.tar.bz2
fi
if [ ! -f ${DOWNLOAD_DIR}/gdb-${GDB_VER}.tar.bz2 ]; then
	wget ${GDB_PATH}/gdb-${GDB_VER}.tar.bz2
fi
if [ ! -f ${DOWNLOAD_DIR}/gcc-${GCC_VER}.tar.bz2 ]; then
	wget ${GCC_PATH}/gcc-${GCC_VER}/gcc-${GCC_VER}.tar.bz2
fi
if [ ! -f ${DOWNLOAD_DIR}/gmp-${GMP_VER}.tar.bz2 ]; then
	wget ${GMP_PATH}/gmp-${GMP_VER}.tar.bz2
fi
if [ ! -f ${DOWNLOAD_DIR}/mpfr-${MPFR_VER}.tar.bz2 ]; then
	wget ${MPFR_PATH}/mpfr-${MPFR_VER}.tar.bz2
fi
if [ ! -f ${DOWNLOAD_DIR}/newlib-${NEWLIB_VER}.tar.gz ]; then
	wget ${NEWLIB_PATH}/newlib-${NEWLIB_VER}.tar.gz
fi
if [ ! -f ${DOWNLOAD_DIR}/insight-${INSIGHT_VER}.tar.bz2 ]; then
	wget ${INSIGHT_PATH}/insight-${INSIGHT_VER}.tar.bz2
fi

#Build BINUTILS
cd ${CORTEX_TOPDIR}
if [ ! -f .binutils ]; then
rm -rf binutils-${BINUTILS_VER}
tar xjf ${DOWNLOAD_DIR}/binutils-${BINUTILS_VER}.tar.bz2
cd binutils-${BINUTILS_VER}

# hack: allow autoconf version 2.61 instead of 2.59
sed -i 's@\(.*_GCC_AUTOCONF_VERSION.*\)2.59\(.*\)@\12.61\2@' config/override.m4
autoconf
mkdir build
cd build
../configure --target=${TOOLCHAIN_TARGET} --prefix=${TOOLCHAIN_PATH} \
--enable-interwork --disable-multilib --with-gnu-as --with-gnu-ld --disable-nls \
2>&1 | tee configure.log
make -j4 all 2>&1 | tee make.log
make install 2>&1 | tee install.log
cd $CORTEX_TOPDIR
touch .binutils
fi

#Aggiungiamo il path del nuovo compilatore
export PATH=${TOOLCHAIN_PATH}/bin:$PATH

#Build GCC
cd ${CORTEX_TOPDIR}
if [ ! -f .gcc ]; then
rm -rf gcc-${GCC_VER}
tar xjf ${DOWNLOAD_DIR}/gcc-${GCC_VER}.tar.bz2
cd gcc-${GCC_VER}
tar xjf ${DOWNLOAD_DIR}/gmp-${GMP_VER}.tar.bz2
tar xjf ${DOWNLOAD_DIR}/mpfr-${MPFR_VER}.tar.bz2
ln -snf gmp-${GMP_VER} gmp
ln -snf mpfr-${MPFR_VER} mpfr

#cd libstdc++-v3
## uncomment AC_LIBTOOL_DLOPEN
#sed -i 's@^AC_LIBTOOL_DLOPEN.*@# AC_LIBTOOL_DLOPEN@' configure.ac
#autoconf
#cd ..

# hack: allow autoconf version 2.61 instead of 2.59
sed -i 's@\(.*_GCC_AUTOCONF_VERSION.*\)2.59\(.*\)@\12.61\2@' config/override.m4
autoconf

mkdir build
cd build
../configure --target=${TOOLCHAIN_TARGET} --prefix=${TOOLCHAIN_PATH} \
--with-cpu=cortex-m3 --with-mode=thumb \
--enable-interwork --disable-multilib \
--enable-languages="c,c++" --with-newlib --without-headers \
--disable-shared --with-gnu-as --with-gnu-ld \
2>&1 | tee configure.log

make -j4 all-gcc 2>&1 | tee make.log
make install-gcc 2>&1 | tee install.log
cd ${TOOLCHAIN_PATH}/bin
# hack: newlib argz build needs arm-*-{eabi|elf}-cc, not arm-*-{eabi|elf}-gcc
ln -snf ${TOOLCHAIN_TARGET}-gcc ${TOOLCHAIN_TARGET}-cc
cd ${CORTEX_TOPDIR}
touch .gcc
fi

#Build NEWLIB
cd ${CORTEX_TOPDIR}
if [ ! -f .newlib ]; then
#rm -rf newlib
#mkdir newlib
#cd newlib
#cvs -z 9 -d :pserver:anoncvs@sources.redhat.com:/cvs/src login
#cvs -z 9 -d :pserver:anoncvs@sources.redhat.com:/cvs/src co newlib
#cd src

rm -rf newlib-${NEWLIB_VER}
tar xfz ${DOWNLOAD_DIR}/newlib-${NEWLIB_VER}.tar.gz
cd newlib-${NEWLIB_VER}

# hack: allow autoconf version 2.61 instead of 2.59
sed -i 's@\(.*_GCC_AUTOCONF_VERSION.*\)2.59\(.*\)@\12.61\2@' config/override.m4
autoconf
mkdir build
cd build
# note: this needs arm-*-{eabi|elf}-cc to exist or link to arm-*-{eabi|elf}-gcc
#../configure --target=${TOOLCHAIN_TARGET} --prefix=${TOOLCHAIN_PATH} \
#--enable-interwork --disable-newlib-supplied-syscalls --with-gnu-ld --with-gnu-as --disable-shared \
#2>&1 | tee configure.log

../configure --target=${TOOLCHAIN_TARGET} --prefix=${TOOLCHAIN_PATH} \
--enable-interwork --disable-multilib --enable-target-optspace --disable-nls --with-gnu-as --with-gnu-ld --disable-newlib-supplied-syscalls \
--enable-newlib-elix-level=1 --disable-newlib-io-float --disable-newlib-atexit-dynamic-alloc --enable-newlib-reent-small --disable-shared \
--enable-newlib-multithread \
2>&1 | tee configure.log

#make -j4 CFLAGS_FOR_TARGET="-ffunction-sections -fdata-sections -DPREFER_SIZE_OVER_SPEED -D__OPTIMIZE_SIZE__ -Os -fomit-frame-pointer -D__BUFSIZ__=256" \
make -j4 CFLAGS_FOR_TARGET="-DREENTRANT_SYSCALLS_PROVIDED" \
2>&1 | tee make.log
make install 2>&1 | tee install.log
cd ${CORTEX_TOPDIR}
touch .newlib
fi

#Finish to build GCC
cd ${CORTEX_TOPDIR}
if [ ! -f .gcc-full ]; then
cd gcc-${GCC_VER}/build
make -j4 all 2>&1 | tee make-full.log
make install 2>&1 | tee install-full.log
cd ${CORTEX_TOPDIR}
touch .gcc-full
fi

#Build GDB
cd ${CORTEX_TOPDIR}
if [ ! -f .gdb ]; then
rm -rf gdb-${GDB_VER}
tar xjf ${DOWNLOAD_DIR}/gdb-${GDB_VER}.tar.bz2
cd gdb-${GDB_VER}
mkdir build
cd build
../configure --target=${TOOLCHAIN_TARGET} --prefix=${TOOLCHAIN_PATH}
make -j4 2>&1 | tee make.log
make install 2>&1 | tee install.log
cd ${CORTEX_TOPDIR}
touch .gdb
fi

#Build INSIGHT
cd ${CORTEX_TOPDIR}
if [ ! -f .insight ]; then
rm -rf insight-${INSIGHT_VER}
tar xfj ${DOWNLOAD_DIR}/insight-${INSIGHT_VER}.tar.bz2
cd insight-${INSIGHT_VER}
mkdir build
cd build
../configure --target=${TOOLCHAIN_TARGET} --prefix=${TOOLCHAIN_PATH}
make -j4 2>&1 | tee make.log
make install 2>&1 | tee install.log
cd ${CORTEX_TOPDIR}
touch .insight
fi
