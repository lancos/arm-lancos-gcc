#!/bin/bash
#
# $Id: build-gcc-arm.sh,v 1.25 2010/08/25 15:14:29 claudio Exp $
#
# @brief Build cross compiler for ARM Cortex M3 processor
# 
# Builds a bare-metal cross GNU toolchain targetting the ARM Cortex M3
# microprocessor in EABI mode and using the newlib embedded C library.
#
# @version $Revision$
# @author  Claudio Lanconelli
# @note This script was tested on a Ubuntu Linux 8.04 (x86 32/64bit) and
#       Ubuntu 9.04 but with GCC 4.2.4 (newer version seems to rise some errors)
#       This script was tested also on a Fedora core 10 x86 32bit
#		Tested on Kubuntu 32bit 10.04 (gcc 4.4.3)
#
# @note Based on Leon Woestenberg <leon@sidebranch.com> http://www.sidebranch.com/
#
# @note You need to pre-install some Ubuntu packages on your host:
# sudo apt-get install flex bison autoconf texinfo gcc-4.2
# and for GDB: 
# sudo apt-get install libncurses5-dev 
#
# @note Richiede autoconf 2.65
#
# @note This script overrides gcc's autoconf 2.64 version dependency
# to 2.65.
#
# @note aggiunto insight-gdb e modificato opzioni della newlib, nonche`
# scaricamento della newlib da sito ufficiale.

#Impostiamo i flag per uscire al primo errore (anche usando il "make | tee")
set -o errexit
set -o pipefail

#export PATH=${HOME}/bin:${PATH}
#export LD_LIBRARY_PATH=${HOME}/lib:${LD_LIBRARY_PATH}
#echo $PATH
#echo $LD_LIBRARY_PATH

CORTEX_TOPDIR=`pwd`

#Per ubuntu 8.04, 8.10 e 9.04 va bene il gcc-4.2, per altre distro (FC10) utilizzare il gcc standard
# Non utilizzare gcc 4.3.2 che da` problemi a compilare GMP per macchine a 64bit (http://gmplib.org/)
export CC=gcc
#export CC=gcc-4.2
echo "gcc utilizzato: $CC"

DOWNLOAD_DIR=${CORTEX_TOPDIR}/downloads

BINUTILS_VER=2.21
GDB_VER=7.2
GCC_VER=4.5.2
#GMP_VER=5.0.1 performance <--> 4.3.2 stable
GMP_VER=4.3.2
MPFR_VER=2.4.2
MPC_VER=0.8.2
PPL_VER=0.10.2
CLOOGPPL_VER=0.15.9
NEWLIB_VER=1.19.0
#INSIGHT_VER=6.8-1
LIBELF_VER=0.8.13

#Snapshots releases
#BINUTILS_VER=2.20.51
#GDB_VER=6.8.50.20090916
#GCC_VER=4.5-20091029
#INSIGHT_VER=weekly-7.0.50-20091102

TOOLCHAIN_NAME=gcc${GCC_VER}-bu${BINUTILS_VER}-gdb${GDB_VER}-nl${NEWLIB_VER}
echo "Build toolchain $TOOLCHAIN_NAME"

#Dove verra` installato il toolchain
TOOLCHAIN_PATH=${HOME}/${TOOLCHAIN_NAME}

#Prefix del toolchain che stiamo costruendo
TOOLCHAIN_TARGET=arm-lancos-eabi

#Numero di compilazioni concorrenti (consigliabile 2+ per un dual-core o 4+ per un quad-core)
NUM_JOBS=2

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

if [ "$1" == "local" ]; then
	#Usa percorsi locali
	LOCAL_PATH=http://server.eptar.com/software/ARM/gcc-src
	echo "Download pacchetti da ${LOCAL_PATH}"
	BINUTILS_PATH=${LOCAL_PATH}
	GDB_PATH=${LOCAL_PATH}
	GCC_PATH=${LOCAL_PATH}
	GMP_PATH=${LOCAL_PATH}
	MPFR_PATH=${LOCAL_PATH}
	MPC_PATH=${LOCAL_PATH}
	PPL_PATH=${LOCAL_PATH}
	CLOOGPPL_PATH=${LOCAL_PATH}
	NEWLIB_PATH=${LOCAL_PATH}
	INSIGHT_PATH=${LOCAL_PATH}
	LIBELF_PATH=${LOCAL_PATH}
else
	#Usa percorsi remoti (tramite wget)
	BINUTILS_PATH=http://ftp.gnu.org/pub/gnu/binutils
	#BINUTILS_PATH=ftp://sourceware.org/pub/binutils/releases

	GDB_PATH=http://ftp.gnu.org/pub/gnu/gdb
	#GDB_PATH=ftp://sourceware.org/pub/gdb/releases

	GCC_PATH=http://ftp.gnu.org/pub/gnu/gcc/gcc-${GCC_VER}
	#GCC_PATH=ftp://sourceware.org/pub/gcc/releases/gcc-${GCC_VER}

	NEWLIB_PATH=ftp://sources.redhat.com/pub/newlib
	#NEWLIB_PATH=ftp://sourceware.org/pub/newlib

	GMP_PATH=http://ftp.gnu.org/pub/gnu/gmp
	MPFR_PATH=http://www.mpfr.org/mpfr-current
	MPC_PATH=http://www.multiprecision.org/mpc/download
	PPL_PATH=ftp://ftp.cs.unipr.it/pub/ppl/releases/${PPL_VER}
	CLOOGPPL_PATH=ftp://gcc.gnu.org/pub/gcc/infrastructure
	INSIGHT_PATH=ftp://sourceware.org/pub/insight/releases
	LIBELF_PATH=http://www.mr511.de/software

	#Snapshots path
	#BINUTILS_PATH=ftp://sourceware.org/pub/binutils/snapshots
	#GDB_PATH=ftp://sourceware.org/pub/gdb/snapshots/current
	#GCC_PATH=ftp://sourceware.org/pub/gcc/snapshots/${GCC_VER}
	#INSIGHT_PATH=ftp://sourceware.org/pub/insight/snapshots/current
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
	wget ${GCC_PATH}/gcc-${GCC_VER}.tar.bz2
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
#if [ ! -f ${DOWNLOAD_DIR}/insight-${INSIGHT_VER}.tar.bz2 ]; then
#	wget ${INSIGHT_PATH}/insight-${INSIGHT_VER}.tar.bz2
#fi
if [ ! -f ${DOWNLOAD_DIR}/mpc-${MPC_VER}.tar.gz ]; then
	wget ${MPC_PATH}/mpc-${MPC_VER}.tar.gz
fi
if [ ! -f ${DOWNLOAD_DIR}/ppl-${PPL_VER}.tar.bz2 ]; then
	wget ${PPL_PATH}/ppl-${PPL_VER}.tar.bz2
fi
if [ ! -f ${DOWNLOAD_DIR}/cloog-ppl-${CLOOGPPL_VER}.tar.gz ]; then
	wget ${CLOOGPPL_PATH}/cloog-ppl-${CLOOGPPL_VER}.tar.gz
fi
if [ ! -f ${DOWNLOAD_DIR}/libelf-${LIBELF_VER}.tar.gz ]; then
	wget ${LIBELF_PATH}/libelf-${LIBELF_VER}.tar.gz
fi

echo "Start building static libs..."
mkdir -p ${CORTEX_TOPDIR}/static

echo "Build LIBELF"
cd ${CORTEX_TOPDIR}
if [ ! -f .libelf ]; then
	rm -rf libelf-${LIBELF_VER}
	tar xfz ${DOWNLOAD_DIR}/libelf-${LIBELF_VER}.tar.gz
	cd libelf-${LIBELF_VER}
	mkdir build
	cd build
#	../configure --prefix=${HOME} --enable-extended-format 2>&1 | tee configure.log
	../configure --prefix=${CORTEX_TOPDIR}/static --disable-shared --enable-extended-format 2>&1 | tee configure.log
	make -j${NUM_JOBS} 2>&1 | tee make.log
	make install 2>&1 | tee makeinstall.log
	cd ${CORTEX_TOPDIR}
	touch .libelf
fi

echo "Build GMP"
cd ${CORTEX_TOPDIR}
if [ ! -f .libgmp ]; then
	rm -rf gmp-${GMP_VER}
	tar xfj ${DOWNLOAD_DIR}/gmp-${GMP_VER}.tar.bz2
	cd gmp-${GMP_VER}
	mkdir build
	cd build
#	../configure --prefix=${HOME} --enable-cxx 2>&1 | tee configure.log
	../configure --prefix=${CORTEX_TOPDIR}/static --enable-cxx --enable-fft --enable-mpbsd --disable-shared --enable-static 2>&1 | tee configure.log
	make -j${NUM_JOBS} 2>&1 | tee make.log
	make install 2>&1 | tee makeinstall.log
	cd ${CORTEX_TOPDIR}
	touch .libgmp
fi

echo "Build MPFR"
cd ${CORTEX_TOPDIR}
if [ ! -f .libmpfr ]; then
	rm -rf mpfr-${MPFR_VER}
	tar xfj ${DOWNLOAD_DIR}/mpfr-${MPFR_VER}.tar.bz2
	cd mpfr-${MPFR_VER}
	mkdir build
	cd build
	../configure --prefix=${CORTEX_TOPDIR}/static --with-gmp=${CORTEX_TOPDIR}/static --enable-thread-safe --disable-shared --enable-static
	make -j${NUM_JOBS} 2>&1 | tee make.log
	make install 2>&1 | tee makeinstall.log
	cd ${CORTEX_TOPDIR}
	touch .libmpfr
fi

echo "Build PPL"
cd ${CORTEX_TOPDIR}
if [ ! -f .libppl ]; then
	rm -rf ppl-${PPL_VER} 
	tar xfj ${DOWNLOAD_DIR}/ppl-${PPL_VER}.tar.bz2
	cd ppl-${PPL_VER}
	mkdir build
	cd build
#	../configure --prefix=${HOME} --with-libgmp-prefix=${HOME} --with-libgmpxx-prefix=${HOME} 2>&1 | tee configure.log
	../configure --prefix=${CORTEX_TOPDIR}/static --with-libgmp-prefix=${CORTEX_TOPDIR}/static --with-libgmpxx-prefix=${CORTEX_TOPDIR}/static --disable-debugging --disable-assertions --disable-ppl_lcdd --disable-ppl_lpsol --disable-shared --enable-static
	make -j${NUM_JOBS} 2>&1 | tee make.log
	make install 2>&1 | tee makeinstall.log
	cd ${CORTEX_TOPDIR}
	touch .libppl
fi

echo "Build CLOOG"
cd ${CORTEX_TOPDIR}
if [ ! -f .libcloog ]; then
	rm -rf cloog-ppl-${CLOOGPPL_VER}
	tar xfz ${DOWNLOAD_DIR}/cloog-ppl-${CLOOGPPL_VER}.tar.gz
	cd cloog-ppl-${CLOOGPPL_VER}
	mkdir build
	cd build
#	../configure --prefix=${HOME} --with-gmp=${HOME} --with-ppl=${HOME} 2>&1 | tee configure.log
	../configure --prefix=${CORTEX_TOPDIR}/static --with-gmp=${CORTEX_TOPDIR}/static --with-ppl=${CORTEX_TOPDIR}/static --with-bits=gmp --disable-shared --enable-static --with-host-libstdcxx="-lstdc++"
	make -j${NUM_JOBS} 2>&1 | tee make.log
	make install 2>&1 | tee makeinstall.log
	cd ${CORTEX_TOPDIR}
	touch .libcloog
fi

echo "Build MPC"
cd ${CORTEX_TOPDIR}
if [ ! -f .libmpc ]; then
	rm -rf mpc-${MPC_VER}
	tar xfz ${DOWNLOAD_DIR}/mpc-${MPC_VER}.tar.gz
	cd mpc-${MPC_VER}
	mkdir build
	cd build
	../configure --prefix=${CORTEX_TOPDIR}/static --with-gmp=${CORTEX_TOPDIR}/static --with-mpfr=${CORTEX_TOPDIR}/static --disable-shared --enable-static
	make -j${NUM_JOBS} 2>&1 | tee make.log
	make install 2>&1 | tee makeinstall.log
	cd ${CORTEX_TOPDIR}
	touch .libmpc
fi

echo ".Done"
echo "Start building tools..."
echo "Build BINUTILS"
cd ${CORTEX_TOPDIR}
if [ ! -f .binutils ]; then
	rm -rf binutils-${BINUTILS_VER}
	tar xfj ${DOWNLOAD_DIR}/binutils-${BINUTILS_VER}.tar.bz2
#	patch -p0 <binutils.patch	#necessario solo per binutils 2.20
	cd binutils-${BINUTILS_VER}

	# hack: allow autoconf version 2.65 instead of 2.64
	sed -i 's@\(.*_GCC_AUTOCONF_VERSION.*\)2.64\(.*\)@\12.65\2@' config/override.m4
	autoconf
	mkdir build
	cd build
	../configure --target=${TOOLCHAIN_TARGET} --prefix=${TOOLCHAIN_PATH} \
	--enable-interwork --disable-multilib --with-gnu-as --with-gnu-ld --disable-nls --with-float=soft\
	--with-gmp=${CORTEX_TOPDIR}/static --with-mpfr=${CORTEX_TOPDIR}/static --with-mpc=${CORTEX_TOPDIR}/static \
	--with-ppl=${CORTEX_TOPDIR}/static --with-cloog=${CORTEX_TOPDIR}/static \
	2>&1 | tee configure.log

#	--with-gmp= --with-mpfr= --with-float=soft --with-sysroot=
	make -j${NUM_JOBS} all 2>&1 | tee make.log
	make install 2>&1 | tee install.log
	cd $CORTEX_TOPDIR
	touch .binutils
fi

#Aggiungiamo il path del nuovo compilatore
export PATH=${TOOLCHAIN_PATH}/bin:$PATH

echo "Build GCC (first half)"
cd ${CORTEX_TOPDIR}
if [ ! -f .gcc ]; then
	rm -rf gcc-${GCC_VER}
	tar xfj ${DOWNLOAD_DIR}/gcc-${GCC_VER}.tar.bz2
#	patch -p0 <gcc.patch
	cd gcc-${GCC_VER}
#	tar xfj ${DOWNLOAD_DIR}/gmp-${GMP_VER}.tar.bz2
#	tar xfj ${DOWNLOAD_DIR}/mpfr-${MPFR_VER}.tar.bz2
#	tar xfz ${DOWNLOAD_DIR}/mpc-${MPC_VER}.tar.gz
#	ln -snf gmp-${GMP_VER} gmp
#	ln -snf mpfr-${MPFR_VER} mpfr
#	ln -snf mpc-${MPC_VER} mpc

	#cd libstdc++-v3
	## uncomment AC_LIBTOOL_DLOPEN
	#sed -i 's@^AC_LIBTOOL_DLOPEN.*@# AC_LIBTOOL_DLOPEN@' configure.ac
	#autoconf
	#cd ..

	# hack: allow autoconf version 2.65 instead of 2.64
	sed -i 's@\(.*_GCC_AUTOCONF_VERSION.*\)2.64\(.*\)@\12.65\2@' config/override.m4
	autoconf

	mkdir build
	cd build
	../configure --target=${TOOLCHAIN_TARGET} --prefix=${TOOLCHAIN_PATH} \
	--with-cpu=cortex-m3 --with-mode=thumb --enable-interwork --disable-multilib \
	--enable-languages="c,c++" --with-newlib --without-headers \
	--disable-shared --with-gnu-as --with-gnu-ld \
	--enable-stage1-checking=all --enable-lto \
	--disable-nls --with-host-libstdcxx='-lstdc++' \
	--with-tune=cortex-m3 --with-float=soft --disable-__cxa_atexit \
	--with-gmp=${CORTEX_TOPDIR}/static --with-mpfr=${CORTEX_TOPDIR}/static --with-mpc=${CORTEX_TOPDIR}/static \
	--with-libelf=${CORTEX_TOPDIR}/static --with-ppl=${CORTEX_TOPDIR}/static --with-cloog=${CORTEX_TOPDIR}/static \
	2>&1 | tee configure.log

#	--enable-target-optspace

	make -j${NUM_JOBS} all-gcc 2>&1 | tee make.log
	make install-gcc 2>&1 | tee install.log
	cd ${TOOLCHAIN_PATH}/bin
	# hack: newlib argz build needs arm-*-{eabi|elf}-cc, not arm-*-{eabi|elf}-gcc
	ln -snf ${TOOLCHAIN_TARGET}-gcc ${TOOLCHAIN_TARGET}-cc
	cd ${CORTEX_TOPDIR}
	touch .gcc
fi

echo "Build NEWLIB"
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
	patch -p0 <newlib_mktime.diff
	cd newlib-${NEWLIB_VER}

	# hack: allow autoconf version 2.65 instead of 2.64
	sed -i 's@\(.*_GCC_AUTOCONF_VERSION.*\)2.64\(.*\)@\12.65\2@' config/override.m4
	autoconf
	mkdir build
	cd build
	#note: this needs arm-*-{eabi|elf}-cc to exist or link to arm-*-{eabi|elf}-gcc
	../configure --target=${TOOLCHAIN_TARGET} --prefix=${TOOLCHAIN_PATH} \
	--enable-interwork --disable-multilib --enable-target-optspace --disable-nls --with-gnu-as --with-gnu-ld --disable-newlib-supplied-syscalls \
	--enable-newlib-elix-level=1 --disable-newlib-io-float --disable-newlib-atexit-dynamic-alloc --enable-newlib-reent-small --disable-shared \
	--enable-newlib-multithread \
	2>&1 | tee configure.log
	make -j${NUM_JOBS} CFLAGS_FOR_TARGET="-DREENTRANT_SYSCALLS_PROVIDED -DSMALL_MEMORY -DHAVE_ASSERT_FUNC" 2>&1 | tee make.log
	make install 2>&1 | tee install.log
	cd ${CORTEX_TOPDIR}
	touch .newlib
fi

echo "Build GCC (second half)"
cd ${CORTEX_TOPDIR}
if [ ! -f .gcc-full ]; then
	cd gcc-${GCC_VER}/build
	make -j${NUM_JOBS} all 2>&1 | tee make-full.log
	make install 2>&1 | tee install-full.log
	cd ${CORTEX_TOPDIR}
	touch .gcc-full
fi

echo "Build GDB"
cd ${CORTEX_TOPDIR}
if [ ! -f .gdb ]; then
	rm -rf gdb-${GDB_VER}
	tar xfj ${DOWNLOAD_DIR}/gdb-${GDB_VER}.tar.bz2
	cd gdb-${GDB_VER}
	mkdir build
	cd build
	../configure --target=${TOOLCHAIN_TARGET} --prefix=${TOOLCHAIN_PATH} --enable-werror
	make -j${NUM_JOBS} 2>&1 | tee make.log
	make install 2>&1 | tee install.log
	cd ${CORTEX_TOPDIR}
	touch .gdb
fi

#N.B. Insight reinstalla anche il GDB, percio` probabilmente dovrebbero essere mutualmente esclusivi
#     per ora manteniamo commentato INSIGHT che comunque funziona male. Preferibile a INSIGHT e` la coppia GDB + Eclipse
#Build INSIGHT
#cd ${CORTEX_TOPDIR}
#if [ ! -f .insight ]; then
#	rm -rf insight-${INSIGHT_VER}
#	tar xfj ${DOWNLOAD_DIR}/insight-${INSIGHT_VER}.tar.bz2
#	cd insight-${INSIGHT_VER}
#	mkdir build
#	cd build
#	../configure --target=${TOOLCHAIN_TARGET} --prefix=${TOOLCHAIN_PATH}
#	make -j${NUM_JOBS} 2>&1 | tee make.log
#	make install 2>&1 | tee install.log
#	cd ${CORTEX_TOPDIR}
#	touch .insight
#fi

echo "Done. Stripping binaries..."
cd ${TOOLCHAIN_PATH}/libexec/gcc/arm-lancos-eabi/${GCC_VER}
strip cc1
strip cc1plus

cd ${TOOLCHAIN_PATH}/bin
strip arm-lancos-eabi-addr2line
strip arm-lancos-eabi-ar
strip arm-lancos-eabi-as
strip arm-lancos-eabi-c++
strip arm-lancos-eabi-c++filt
strip arm-lancos-eabi-cpp
strip arm-lancos-eabi-g++
strip arm-lancos-eabi-gcc
strip arm-lancos-eabi-gcc-${GCC_VER}
strip arm-lancos-eabi-gcov
strip arm-lancos-eabi-gdb
strip arm-lancos-eabi-gdbtui
strip arm-lancos-eabi-gprof
strip arm-lancos-eabi-ld
strip arm-lancos-eabi-nm
strip arm-lancos-eabi-objcopy
strip arm-lancos-eabi-objdump
strip arm-lancos-eabi-ranlib
strip arm-lancos-eabi-readelf
strip arm-lancos-eabi-run
strip arm-lancos-eabi-size
strip arm-lancos-eabi-strings
strip arm-lancos-eabi-strip

cd ${CORTEX_TOPDIR}
if [ ! -f .targz ]; then
	echo "Done. Build TAR GZ package..."
	cd ${TOOLCHAIN_PATH}/..
	tar cfj ${TOOLCHAIN_NAME}.tar.bz2 ${TOOLCHAIN_NAME}
	echo "TAR GZ Done"
	cd ${CORTEX_TOPDIR}
	touch .targz
fi
echo "Done."
