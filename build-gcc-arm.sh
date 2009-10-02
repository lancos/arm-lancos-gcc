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
TOOLCHAIN_TARGET=arm-sidebranch-eabi

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

cd ${DOWNLOAD_DIR}
if [ ! -f ${DOWNLOAD_DIR}/binutils-2.18.50.0.7.tar.bz2 ]; then
wget http://www.kernel.org/pub/linux/devel/binutils/binutils-2.18.50.0.7.tar.bz2
fi
if [ ! -f ${DOWNLOAD_DIR}/gdb-6.8.tar.bz2 ]; then
wget http://ftp.gnu.org/pub/gnu/gdb/gdb-6.8.tar.bz2
fi
if [ ! -f ${DOWNLOAD_DIR}/gcc-4.3.1.tar.bz2 ]; then
wget http://ftp.gnu.org/pub/gnu/gcc/gcc-4.3.1/gcc-4.3.1.tar.bz2
fi
if [ ! -f ${DOWNLOAD_DIR}/gmp-4.2.2.tar.bz2 ]; then
wget http://ftp.sunet.se/pub/gnu/gmp/gmp-4.2.2.tar.bz2
fi
if [ ! -f ${DOWNLOAD_DIR}/mpfr-2.4.0.tar.bz2 ]; then
wget http://www.mpfr.org/mpfr-current/mpfr-2.4.0.tar.bz2
fi

cd ${CORTEX_TOPDIR}
if [ ! -f .binutils ]; then
rm -rf binutils-2.18.50.0.7
tar xjf ${DOWNLOAD_DIR}/binutils-2.18.50.0.7.tar.bz2
cd binutils-2.18.50.0.7
mkdir build
cd build
../configure --target=${TOOLCHAIN_TARGET} --prefix=${TOOLCHAIN_PATH} \
--enable-interwork --disable-multilib --with-gnu-as --with-gnu-ld --disable-nls \
2>&1 | tee configure.log
make -j3 all 2>&1 | tee make.log
make install 2>&1 | tee install.log
cd $CORTEX_TOPDIR
touch .binutils
fi

export PATH=${TOOLCHAIN_PATH}/bin:$PATH

cd ${CORTEX_TOPDIR}
if [ ! -f .gcc ]; then
rm -rf gcc-4.3.1
tar xjf ${DOWNLOAD_DIR}/gcc-4.3.1.tar.bz2
cd gcc-4.3.1
tar xjf ${DOWNLOAD_DIR}/gmp-4.2.2.tar.bz2
tar xjf ${DOWNLOAD_DIR}/mpfr-2.4.0.tar.bz2
ln -snf gmp-4.2.2 gmp
ln -snf mpfr-2.4.0 mpfr
cd libstdc++-v3
# uncomment AC_LIBTOOL_DLOPEN
sed -i 's@^AC_LIBTOOL_DLOPEN.*@# AC_LIBTOOL_DLOPEN@' configure.ac
autoconf
cd ..
mkdir build
cd build
../configure --target=${TOOLCHAIN_TARGET} --prefix=${TOOLCHAIN_PATH} \
--with-cpu=cortex-m3 --with-mode=thumb \
--enable-interwork --disable-multilib \
--enable-languages="c,c++" --with-newlib --without-headers \
--disable-shared --with-gnu-as --with-gnu-ld \
2>&1 | tee configure.log
make -j3 all-gcc 2>&1 | tee make.log
make install-gcc 2>&1 | tee install.log
cd ${TOOLCHAIN_PATH}/bin
# hack: newlib argz build needs arm-*-{eabi|elf}-cc, not arm-*-{eabi|elf}-gcc
ln -snf ${TOOLCHAIN_TARGET}-gcc ${TOOLCHAIN_TARGET}-cc
cd ${CORTEX_TOPDIR}
touch .gcc
fi

cd ${CORTEX_TOPDIR}
if [ ! -f .newlib ]; then
rm -rf newlib
mkdir newlib
cd newlib
cvs -z 9 -d :pserver:anoncvs@sources.redhat.com:/cvs/src login
cvs -z 9 -d :pserver:anoncvs@sources.redhat.com:/cvs/src co newlib
cd src
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
../configure --target=${TOOLCHAIN_TARGET} --prefix=${TOOLCHAIN_PATH} \
--enable-interwork \
--disable-newlib-supplied-syscalls --with-gnu-ld --with-gnu-as --disable-shared \
2>&1 | tee configure.log

#make -j3 CFLAGS_FOR_TARGET="-ffunction-sections -fdata-sections -DPREFER_SIZE_OVER_SPEED -D__OPTIMIZE_SIZE__ -Os -fomit-frame-pointer -mcpu=cortex-m3 -mthumb -D__thumb2__ -D__BUFSIZ__=256" \
#CCASFLAGS="-mcpu=cortex-m3 -mthumb -D__thumb2__" \
make -j3 CFLAGS_FOR_TARGET="-ffunction-sections -fdata-sections -DPREFER_SIZE_OVER_SPEED -D__OPTIMIZE_SIZE__ -Os -fomit-frame-pointer -D__BUFSIZ__=256" \
2>&1 | tee make.log
make install 2>&1 | tee install.log
cd ${CORTEX_TOPDIR}
touch .newlib
fi

cd ${CORTEX_TOPDIR}
if [ ! -f .gcc-full ]; then
cd gcc-4.3.1/build
#make -j3 CFLAGS="-mcpu=cortex-m3 -mthumb" all 2>&1 | tee make-full.log
make -j3 all 2>&1 | tee make-full.log
make install 2>&1 | tee install-full.log
cd ${CORTEX_TOPDIR}
touch .gcc-full
fi

cd ${CORTEX_TOPDIR}
if [ ! -f .gdb ]; then
rm -rf gdb-6.8
tar xjf ${DOWNLOAD_DIR}/gdb-6.8.tar.bz2
cd gdb-6.8
mkdir build
cd build
../configure --target=${TOOLCHAIN_TARGET} --prefix=${TOOLCHAIN_PATH}
make -j3 2>&1 | tee make.log
make install 2>&1 | tee install.log
cd ${CORTEX_TOPDIR}
touch .gdb
fi

