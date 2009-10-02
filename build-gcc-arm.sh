#!/bin/bash
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

set -e

CORTEX_TOPDIR=`pwd`

DOWNLOAD_DIR=${CORTEX_TOPDIR}/downloads

TOOLCHAIN_PATH=${HOME}/stm32

#TOOLCHAIN_TARGET=arm-elf
#TOOLCHAIN_TARGET=arm-sidebranch-eabi
TOOLCHAIN_TARGET=arm-lancos-eabi

mkdir -p ${TOOLCHAIN_PATH}
touch ${TOOLCHAIN_PATH}/need_write_access_here
if [ ! ?$ -eq 0 ]; then
  echo "Need ${TOOLCHAIN_PATH} directory with write access."
  exit 1
fi
rm -f ${TOOLCHAIN_PATH}/need_write_access_here

if [ ! -d ${DOWNLOAD_DIR} ]; then
mkdir ${DOWNLOAD_DIR}
fi

BINUTILS_VER=2.19.1
GDB_VER=6.8
#GCC_VER=4.3.4
GCC_VER=4.4.1
GMP_VER=4.3.1
MPFR_VER=2.4.1
NEWLIB_VER=1.17.0
INSIGHT_VER=6.8-1

cd ${DOWNLOAD_DIR}
#if [ ! -f ${DOWNLOAD_DIR}/binutils-2.19.51.0.1.tar.bz2 ]; then
#wget http://www.kernel.org/pub/linux/devel/binutils/binutils-2.19.51.0.1.tar.bz2
#fi
if [ ! -f ${DOWNLOAD_DIR}/binutils-${BINUTILS_VER}.tar.bz2 ]; then
wget http://ftp.gnu.org/pub/gnu/binutils/binutils-${BINUTILS_VER}.tar.bz2
fi
if [ ! -f ${DOWNLOAD_DIR}/gdb-${GDB_VER}.tar.bz2 ]; then
wget http://ftp.gnu.org/pub/gnu/gdb/gdb-${GDB_VER}.tar.bz2
fi
if [ ! -f ${DOWNLOAD_DIR}/gcc-${GCC_VER}.tar.bz2 ]; then
wget http://ftp.gnu.org/pub/gnu/gcc/gcc-${GCC_VER}/gcc-${GCC_VER}.tar.bz2
fi
if [ ! -f ${DOWNLOAD_DIR}/gmp-${GMP_VER}.tar.bz2 ]; then
wget http://ftp.gnu.org/pub/gnu/gmp/gmp-${GMP_VER}.tar.bz2
fi
if [ ! -f ${DOWNLOAD_DIR}/mpfr-${MPFR_VER}.tar.bz2 ]; then
wget http://www.mpfr.org/mpfr-current/mpfr-${MPFR_VER}.tar.bz2
fi
if [ ! -f ${DOWNLOAD_DIR}/newlib-${NEWLIB_VER}.tar.gz ]; then
wget ftp://sources.redhat.com/pub/newlib/newlib-${NEWLIB_VER}.tar.gz
fi
if [ ! -f ${DOWNLOAD_DIR}/insight-${INSIGHT_VER}.tar.bz2 ]; then
wget ftp://sourceware.org/pub/insight/releases/insight-${INSIGHT_VER}.tar.bz2
fi

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


export PATH=${TOOLCHAIN_PATH}/bin:$PATH

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
--enable-interwork --enable-multilib \
--enable-languages="c,c++" --with-newlib --without-headers \
--disable-shared --with-gnu-as --with-gnu-ld \
2>&1 | tee configure.log

#--disable-multilib \

make -j4 all-gcc 2>&1 | tee make.log
make install-gcc 2>&1 | tee install.log
cd ${TOOLCHAIN_PATH}/bin
# hack: newlib argz build needs arm-*-{eabi|elf}-cc, not arm-*-{eabi|elf}-gcc
ln -snf ${TOOLCHAIN_TARGET}-gcc ${TOOLCHAIN_TARGET}-cc
cd ${CORTEX_TOPDIR}
touch .gcc
fi

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

# hack: disable libgloss for the target, presumably not buildable for armv7t
# (this no longer seems necessary with latest newlib snapshots, commented out)
#sed -i 's@.*noconfigdirs=\"\$noconfigdirs target-libffi target-qthreads\".*@noconfigdirs="\$noconfigdirs target-libffi target-qthreads target-libgloss\"@' \
#configure.ac
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
--enable-interwork --enable-multilib --enable-target-optspace --disable-nls --with-gnu-as --with-gnu-ld --disable-newlib-supplied-syscalls \
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

cd ${CORTEX_TOPDIR}
if [ ! -f .gcc-full ]; then
cd gcc-${GCC_VER}/build
#make -j4 CFLAGS="-mcpu=cortex-m3 -mthumb" all 2>&1 | tee make-full.log
make -j4 all 2>&1 | tee make-full.log
make install 2>&1 | tee install-full.log
cd ${CORTEX_TOPDIR}
touch .gcc-full
fi

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

