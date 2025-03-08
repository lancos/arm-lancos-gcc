#!/bin/bash
#
# @brief Build cross compiler for ARM Cortex M0/M3/M4/M7 processors
#
# Builds a bare-metal cross GNU toolchain targetting the ARM CortexM
# microprocessor in EABI mode and using the newlib embedded C library.
#
# @author  Claudio Lanconelli
# @note This script was tested on Kubuntu 64bit 18/20.04/22.04
#
# @note Based on Leon Woestenberg <leon@sidebranch.com> http://www.sidebranch.com/
#
# @note You need to pre-install some Ubuntu packages on your host:
# sudo apt-get install build-essential bison autoconf2.69 autoconf texinfo zlib1g-dev libelf-dev
# and for GDB: 
# sudo apt-get install libncurses5-dev libgmp-dev (quest'ultimo non dovrebbe servire se GDB implementasse correttamente il configure)
#
# @note Need autoconf 2.69

#Impostiamo i flag per uscire al primo errore (anche usando il "make | tee")
set -o errexit
set -o pipefail
#set -o nounset		#set -u
#set -o xtrace		#set -x

#export PATH=${HOME}/bin:${PATH}
#export LD_LIBRARY_PATH=${HOME}/lib:${LD_LIBRARY_PATH}
#echo $PATH
#echo $LD_LIBRARY_PATH

CORTEX_TOPDIR=`pwd`
BUILD_DATE=`date +%y%m%d`

#Di solito e` sufficiente il gcc della propria distribuzione
export CC=gcc
#export CC=gcc-4.2
echo "gcc utilizzato: $CC"

DOWNLOAD_DIR=${CORTEX_TOPDIR}/downloads

BINUTILS_VER=2.44
GDB_VER=16.2
GCC_VER=14.2.0
GMP_VER=6.3.0
MPFR_VER=4.2.1
MPC_VER=1.3.1
#PPL_VER=1.0
ISL_VER=0.26
#CLOOG_VER=0.18.1
NEWLIB_VER=4.5.0.20241231
#LIBELF_VER=0.8.13
EXPAT_VER=2.6.4
EXPAT_VERDIR=R_2_6_4
#ZLIB_VER=1.2.11

#Aggiungere o meno le librerie per la gestione widechar/multi-byte char
ENABLE_WCMB=no
#ENABLE_WCMB=yes

AUTOCONF_VERMIN=2.69
AUTOCONF_VERSION=`autoconf --version | head -n 1 | cut -d' ' -f4`

if [ "${AUTOCONF_VERMIN}" != "${AUTOCONF_VERSION}" ]; then
	AUTOCONF=autoconf${AUTOCONF_VERMIN}
	AUTOCONF_VERSION=`${AUTOCONF} --version | head -n 1 | cut -d' ' -f4`
else
	AUTOCONF=autoconf
fi

AUTOCONF_VER_INT=`echo "scale=1; ${AUTOCONF_VERSION}*100.0" | bc | cut -d'.' -f 1`
AUTOCONF_VERMIN_INT=`echo "scale=1; ${AUTOCONF_VERMIN}*100.0" | bc | cut -d'.' -f 1`

if [ ${AUTOCONF_VERMIN_INT} -ne ${AUTOCONF_VER_INT} ]; then
	echo "!  Autoconf version = ${AUTOCONF_VERSION} (${AUTOCONF_VER_INT}), Required = ${AUTOCONF_VERMIN} (${AUTOCONF_VERMIN_INT})"
	exit 1
else
	echo "Ok Autoconf version = ${AUTOCONF_VERSION} (${AUTOCONF_VER_INT}), Required = ${AUTOCONF_VERMIN} (${AUTOCONF_VERMIN_INT})"
fi

TOOLCHAIN_NAME="gcc${GCC_VER}-bu${BINUTILS_VER}-gdb${GDB_VER}-nl${NEWLIB_VER}-multilib"
if [ "${ENABLE_WCMB}" == "yes" ]; then
	TOOLCHAIN_NAME="${TOOLCHAIN_NAME}-wcmb"
fi

TOOLCHAINLIB_NAME="gmp${GMP_VER}-mpfr${MPFR_VER}-mpc${MPC_VER}-isl${ISL_VER}-expat${EXPAT_VER}"
echo "Build toolchain ${TOOLCHAIN_NAME}"
echo "toolchain libs ${TOOLCHAINLIB_NAME}"

#Dove verra` installato il toolchain
TOOLCHAIN_PATH=${HOME}/${TOOLCHAIN_NAME}

#Prefix del toolchain che stiamo costruendo
TOOLCHAIN_TARGET=arm-lancos-eabi

mkdir -p ${TOOLCHAIN_PATH}

if touch ${TOOLCHAIN_PATH}/toolchain_libs
  then
	echo "Install dir: ${TOOLCHAIN_PATH}"
	echo "${TOOLCHAINLIB_NAME}" >${TOOLCHAIN_PATH}/toolchain_libs
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
	ISL_PATH=${LOCAL_PATH}
	PPL_PATH=${LOCAL_PATH}
	CLOOG_PATH=${LOCAL_PATH}
	NEWLIB_PATH=${LOCAL_PATH}
	#LIBELF_PATH=${LOCAL_PATH}
	EXPAT_PATH=${LOCAL_PATH}
	ZLIB_PATH=${LOCAL_PATH}
else
	#Usa percorsi remoti (tramite wget)
	BINUTILS_PATH=http://ftp.gnu.org/pub/gnu/binutils
	#BINUTILS_PATH=ftp://sourceware.org/pub/binutils/releases

	GDB_PATH=http://ftp.gnu.org/pub/gnu/gdb
	#GDB_PATH=ftp://sourceware.org/pub/gdb/releases

	GCC_PATH=http://ftp.gnu.org/pub/gnu/gcc/gcc-${GCC_VER}
	#GCC_PATH=ftp://sourceware.org/pub/gcc/releases/gcc-${GCC_VER}

	#NEWLIB_PATH=ftp://sources.redhat.com/pub/newlib
	NEWLIB_PATH=ftp://sourceware.org/pub/newlib

	GMP_PATH=http://ftp.gnu.org/pub/gnu/gmp
	#MPFR_PATH=http://www.mpfr.org/mpfr-current
	MPFR_PATH=https://www.mpfr.org/mpfr-${MPFR_VER}
	#MPC_PATH=http://www.multiprecision.org/mpc/download
	MPC_PATH=http://ftp.gnu.org/gnu/mpc
	PPL_PATH=ftp://ftp.cs.unipr.it/pub/ppl/releases/${PPL_VER}
	ISL_PATH=https://sourceforge.net/projects/libisl/files/isl-${ISL_VER}.tar.xz/download
	CLOOG_PATH=ftp://gcc.gnu.org/pub/gcc/infrastructure
	#LIBELF_PATH=http://www.mr511.de/software
	#EXPAT_PATH=http://sourceforge.net/projects/expat/files/expat/${EXPAT_VER}
	EXPAT_PATH=https://github.com/libexpat/libexpat/releases/download/${EXPAT_VERDIR}
	ZLIB_PATH=http://zlib.net


	#Snapshots path
	#BINUTILS_PATH=ftp://sourceware.org/pub/binutils/snapshots
	#GDB_PATH=ftp://sourceware.org/pub/gdb/snapshots/current
	#GCC_PATH=ftp://sourceware.org/pub/gcc/snapshots/${GCC_VER}
fi

#Inizia download (solo se necessario)
cd ${DOWNLOAD_DIR}
if [ ! -f binutils-${BINUTILS_VER}.tar.xz ]; then
	wget ${BINUTILS_PATH}/binutils-${BINUTILS_VER}.tar.xz
fi
if [ ! -f gdb-${GDB_VER}.tar.xz ]; then
	wget ${GDB_PATH}/gdb-${GDB_VER}.tar.xz
fi
if [ ! -f gcc-${GCC_VER}.tar.xz ]; then
	wget ${GCC_PATH}/gcc-${GCC_VER}.tar.xz
fi
if [ ! -f gmp-${GMP_VER}.tar.xz ]; then
	wget ${GMP_PATH}/gmp-${GMP_VER}.tar.xz
fi
if [ ! -f mpfr-${MPFR_VER}.tar.xz ]; then
	wget --no-check-certificate ${MPFR_PATH}/mpfr-${MPFR_VER}.tar.xz
fi
if [ ! -f newlib-${NEWLIB_VER}.tar.gz ]; then
	wget ${NEWLIB_PATH}/newlib-${NEWLIB_VER}.tar.gz
fi
if [ ! -f mpc-${MPC_VER}.tar.gz ]; then
	wget ${MPC_PATH}/mpc-${MPC_VER}.tar.gz
fi
#if [ ! -f ppl-${PPL_VER}.tar.bz2 ]; then
#	wget ${PPL_PATH}/ppl-${PPL_VER}.tar.bz2
#fi
if [ ! -f isl-${ISL_VER}.tar.xz ]; then
	wget -O isl-${ISL_VER}.tar.xz ${ISL_PATH}
fi
#if [ ! -f cloog-${CLOOG_VER}.tar.gz ]; then
#	wget ${CLOOG_PATH}/cloog-${CLOOG_VER}.tar.gz
#fi
#if [ ! -f libelf-${LIBELF_VER}.tar.gz ]; then
#	wget ${LIBELF_PATH}/libelf-${LIBELF_VER}.tar.gz
#fi
#if [ ! -f zlib-${ZLIB_VER}.tar.gz ]; then
#	wget ${ZLIB_PATH}/zlib-${ZLIB_VER}.tar.gz
#fi
if [ ! -f expat-${EXPAT_VER}.tar.gz ]; then
	wget ${EXPAT_PATH}/expat-${EXPAT_VER}.tar.gz
fi

#Vista MinGW workaround (da Yagarto)
echo "${OSTYPE}"
if [ "${OSTYPE}" == "msys" ]; then
	export CFLAGS="-D__USE_MINGW_ACCESS -pipe"
	NUM_JOBS=1
else
	#Numero di compilazioni concorrenti (consigliabile 2+ per un dual-core o 4+ per un quad-core)
	NUM_JOBS=`getconf _NPROCESSORS_ONLN`
fi

if [ "z$NUM_JOBS" == "z" ]; then
	NUM_JOBS=2
fi
echo "Build with $NUM_JOBS parallel jobs"

echo "Start building static libs..."
mkdir -p ${CORTEX_TOPDIR}/static

echo "Build EXPAT"
cd ${CORTEX_TOPDIR}
if [ ! -f .libexpat ]; then
	rm -rf expat-${EXPAT_VER}
	tar xfz ${DOWNLOAD_DIR}/expat-${EXPAT_VER}.tar.gz
	cd expat-${EXPAT_VER}
	mkdir build
	cd build
	../configure --prefix=${CORTEX_TOPDIR}/static --disable-shared \
		--without-docbook \
		2>&1 | tee configure.log
	make -j${NUM_JOBS} 2>&1 | tee make.log
	make install 2>&1 | tee install.log
	cd ${CORTEX_TOPDIR}
	touch .libexpat
fi

#echo "Build LIBELF"
#cd ${CORTEX_TOPDIR}
#if [ ! -f .libelf ]; then
#	rm -rf libelf-${LIBELF_VER}
#	tar xfz ${DOWNLOAD_DIR}/libelf-${LIBELF_VER}.tar.gz
#	cd libelf-${LIBELF_VER}
#	mkdir build
#	cd build
#	../configure --prefix=${CORTEX_TOPDIR}/static --disable-shared --enable-extended-format \
#		2>&1 | tee configure.log
#	make -j${NUM_JOBS} 2>&1 | tee make.log
#	make install 2>&1 | tee makeinstall.log
#	cd ${CORTEX_TOPDIR}
#	touch .libelf
#fi

echo "Build GMP"
cd ${CORTEX_TOPDIR}
if [ ! -f .libgmp ]; then
	rm -rf gmp-${GMP_VER}
	tar xfJ ${DOWNLOAD_DIR}/gmp-${GMP_VER}.tar.xz
	cd gmp-${GMP_VER}
	mkdir build
	cd build
	#Forziamo ABI=32 quando compiliamo in mingw32, questo per evitare mismatch 64bit su core2 e win32
	if [ "${OSTYPE}" == "msys" ]; then
		GMPABI="ABI=32"
	else
		GMPABI=
	fi
	echo "Build GMP with ${GMPABI}"
	../configure ${GMPABI} --prefix=${CORTEX_TOPDIR}/static --enable-cxx --enable-fft \
		--disable-shared --enable-static 2>&1 | tee configure.log
	make -j${NUM_JOBS} 2>&1 | tee make.log
	make check 2>&1 | tee makecheck.log
	make install 2>&1 | tee makeinstall.log
	cd ${CORTEX_TOPDIR}
	touch .libgmp
fi

echo "Build MPFR"
cd ${CORTEX_TOPDIR}
if [ ! -f .libmpfr ]; then
	rm -rf mpfr-${MPFR_VER}
	tar xfJ ${DOWNLOAD_DIR}/mpfr-${MPFR_VER}.tar.xz
	cd mpfr-${MPFR_VER}
	mkdir build
	cd build
	../configure --prefix=${CORTEX_TOPDIR}/static --with-gmp=${CORTEX_TOPDIR}/static --enable-thread-safe \
		--disable-shared --enable-static 2>&1 | tee configure.log
	make -j${NUM_JOBS} 2>&1 | tee make.log
	make check 2>&1 | tee makecheck.log
	make install 2>&1 | tee makeinstall.log
	cd ${CORTEX_TOPDIR}
	touch .libmpfr
fi

echo "Build MPC"
cd ${CORTEX_TOPDIR}
if [ ! -f .libmpc ]; then
	rm -rf mpc-${MPC_VER}
	tar xfz ${DOWNLOAD_DIR}/mpc-${MPC_VER}.tar.gz
	cd mpc-${MPC_VER}
	mkdir build
	cd build
	../configure --prefix=${CORTEX_TOPDIR}/static --with-gmp=${CORTEX_TOPDIR}/static --with-mpfr=${CORTEX_TOPDIR}/static \
		--disable-shared --enable-static 2>&1 | tee configure.log
	make -j${NUM_JOBS} 2>&1 | tee make.log
	make install 2>&1 | tee makeinstall.log
	cd ${CORTEX_TOPDIR}
	touch .libmpc
fi

#echo "Build PPL"
#cd ${CORTEX_TOPDIR}
#if [ ! -f .libppl ]; then
#	rm -rf ppl-${PPL_VER}
#	tar xfj ${DOWNLOAD_DIR}/ppl-${PPL_VER}.tar.bz2
#	cd ppl-${PPL_VER}
#	mkdir build
#	cd build
#	../configure --prefix=${CORTEX_TOPDIR}/static --with-gmp=${CORTEX_TOPDIR}/static \
#		--disable-debugging --disable-assertions --disable-documentation \
#		--disable-ppl_lcdd --disable-ppl_lpsol --disable-ppl_pips \
#		--disable-shared --enable-static 2>&1 | tee configure.log
#	make -j${NUM_JOBS} 2>&1 | tee make.log
#	#Il make check richiede MOLTO tempo
#	make -j${NUM_JOBS} check 2>&1 | tee makecheck.log
#	make install 2>&1 | tee makeinstall.log
#	cd ${CORTEX_TOPDIR}
#	touch .libppl
#fi

#export CFLAGS=-I${CORTEX_TOPDIR}/static/include
#export LDFLAGS=-L${CORTEX_TOPDIR}/static/lib

echo "Build ISL"
cd ${CORTEX_TOPDIR}
if [ ! -f .libisl ]; then
	rm -rf isl-${ISL_VER}
	tar xfJ ${DOWNLOAD_DIR}/isl-${ISL_VER}.tar.xz
	cd isl-${ISL_VER}
	mkdir build
	cd build
	../configure --prefix=${CORTEX_TOPDIR}/static \
		--with-gmp=build --with-gmp-builddir=${CORTEX_TOPDIR}/gmp-${GMP_VER}/build \
		--disable-shared --enable-static 2>&1 | tee configure.log
	make -j${NUM_JOBS} 2>&1 | tee make.log
	make check 2>&1 | tee makecheck.log
	make install 2>&1 | tee makeinstall.log
	cd ${CORTEX_TOPDIR}
	touch .libisl
fi

#echo "Build CLOOG"
#cd ${CORTEX_TOPDIR}
#if [ ! -f .libcloog ]; then
#	rm -rf cloog-${CLOOG_VER}
#	tar xfz ${DOWNLOAD_DIR}/cloog-${CLOOG_VER}.tar.gz
#	cd cloog-${CLOOG_VER}
#	patch -p1 < ../cloog_islver.patch
#	if [ "${OSTYPE}" == "msys" ]; then
#		patch -p1 < ../cloog_isl_mingw.patch
#	fi
#	mkdir build
#	cd build
#	../configure --prefix=${CORTEX_TOPDIR}/static \
#		--with-gmp=build --with-gmp-builddir=${CORTEX_TOPDIR}/gmp-${GMP_VER}/build \
#		--with-isl=bundled \
#		--disable-shared --enable-static 2>&1 | tee configure.log
#	make -j${NUM_JOBS} 2>&1 | tee make.log
#	make check 2>&1 | tee makecheck.log
#	make install 2>&1 | tee makeinstall.log
#	cd ${CORTEX_TOPDIR}
#	touch .libcloog
#fi

#echo "Build ZLIB"
#cd ${CORTEX_TOPDIR}
#if [ ! -f .libzlib ]; then
#	rm -rf zlib-${ZLIB_VER}
#	tar xfz ${DOWNLOAD_DIR}/zlib-${ZLIB_VER}.tar.gz
#	cd zlib-${ZLIB_VER}
#	./configure --prefix=${CORTEX_TOPDIR}/static --static 2>&1 | tee configure.log
#	make -j${NUM_JOBS} 2>&1 | tee make.log
#	make check 2>&1 | tee makecheck.log
#	make install 2>&1 | tee makeinstall.log
#	cd ${CORTEX_TOPDIR}
#	touch .libzlib
#fi

echo ".Done"
echo "Start building tools..."
echo "Build BINUTILS"
cd ${CORTEX_TOPDIR}
if [ ! -f .binutils ]; then
	rm -rf binutils-${BINUTILS_VER}
	tar xfJ ${DOWNLOAD_DIR}/binutils-${BINUTILS_VER}.tar.xz
	cd binutils-${BINUTILS_VER}
#	patch -p0 < ../binutils-svc.patch	#necessario per binutils 2.21

#	if [ ${AUTOCONF_VERMIN} != ${AUTOCONF_VERSION} ]; then
#		# hack: allow autoconf version 2.6x instead of 2.64
#		sed -i "s@\(.*_GCC_AUTOCONF_VERSION.*\)${AUTOCONF_VERMIN}\(.*\)@\1${AUTOCONF_VERSION}\2@" config/override.m4
#	fi
	${AUTOCONF}
	mkdir build
	cd build
	../configure --target=${TOOLCHAIN_TARGET} --prefix=${TOOLCHAIN_PATH} \
		--disable-shared \
		--enable-interwork \
		--enable-multilib \
		--with-gnu-as \
		--with-gnu-ld \
		--disable-nls \
		--with-system-zlib \
		--with-gmp=${CORTEX_TOPDIR}/static \
		--with-mpfr=${CORTEX_TOPDIR}/static \
		--with-mpc=${CORTEX_TOPDIR}/static \
		--with-isl=${CORTEX_TOPDIR}/static \
		2>&1 | tee configure.log

#	--with-sysroot=
#	--enable-plugins --disable-sim --disable-readline --disable-libdecnumber --disable-gdb
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
	tar xfJ ${DOWNLOAD_DIR}/gcc-${GCC_VER}.tar.xz
#	patch -p0 <gcc_libgcc_divide_exceptions.patch
	cd gcc-${GCC_VER}
#	patch -p0 < ../gcc_multilib.patch

#	if [ ${AUTOCONF_VERMIN} != ${AUTOCONF_VERSION} ]; then
#		# hack: allow autoconf version 2.6x instead of 2.64
#		sed -i "s@\(.*_GCC_AUTOCONF_VERSION.*\)${AUTOCONF_VERMIN}\(.*\)@\1${AUTOCONF_VERSION}\2@" config/override.m4
#	fi
	${AUTOCONF}

	mkdir build
	cd build
	#OS dependant options
	if [ "${OSTYPE}" == "msys" ]; then
		GCC_CONF_OPTS="--disable-win32-registry"
	else
		GCC_CONF_OPTS="--with-system-zlib"
	fi
	../configure --target=${TOOLCHAIN_TARGET} --prefix=${TOOLCHAIN_PATH} \
		--enable-interwork \
		--enable-multilib \
		--enable-languages="c,c++" \
		--with-newlib \
		--without-headers \
		--with-gnu-as \
		--with-gnu-ld \
		--with-dwarf2 \
		--enable-initfini-array \
		--enable-checking=release \
		--enable-lto \
		--disable-libffi \
		--disable-libgomp \
		--disable-libmudflap \
		--disable-libquadmath \
		--disable-libssp \
		--disable-libstdcxx-pch \
		--disable-libada \
		--disable-libvtv \
		--disable-nls \
		--disable-shared \
		--disable-threads \
		--disable-tls \
		--disable-decimal-float \
		--with-host-libstdcxx='-lstdc++' ${GCC_CONF_OPTS} \
		--disable-__cxa_atexit \
		--with-gmp=${CORTEX_TOPDIR}/static \
		--with-mpfr=${CORTEX_TOPDIR}/static \
		--with-mpc=${CORTEX_TOPDIR}/static \
		--with-isl=${CORTEX_TOPDIR}/static \
		--with-multilib-list=rmprofile \
		--with-pkgversion=lancos${BUILD_DATE} \
		2>&1 | tee configure.log

#	--enable-target-optspace
#	--with-cpu=cortex-m3 --with-mode=thumb --with-tune=cortex-m3 --with-float=soft
#	--without-included-gettext ??
#	--enable-stage1-checking=all
#	--enable-version-specific-runtime-libs
#	--with-libelf=${CORTEX_TOPDIR}/static

#Yagarto gcc configure
# --disable-threads --with-gcc \
# --with-headers=../newlib-$NEWLIB_VER/newlib/libc/include \
# --disable-libssp --disable-libstdcxx-pch --disable-libmudflap \

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
#	patch -p0 <newlib_mktime.diff
#	patch -p0 <newlib_iconv_ccs.patch
	cd newlib-${NEWLIB_VER}
	# Le patch stpcpy e fseeko sono necessarie solo in elix=1
	#if [ "${ENABLE_WCMB}" == "no" ]; then
	#	patch -p0 < ../newlib_stpcpy.patch
	#	patch -p0 < ../newlib_fseeko.patch
	#else
	#	patch -p1 < ../newlib_locale.patch
	#	patch -p1 < ../newlib_locale_lctype.patch
	#fi
#	patch -p1 < ../newlib_Fix-wrong-path-to-config-default.mh.patch
	#patch per prototipo settimeofday()
	patch -p0 < ../newlib_time_h.patch

#	if [ ${AUTOCONF_VERMIN} != ${AUTOCONF_VERSION} ]; then
#		# hack: allow autoconf version 2.6x instead of 2.64
#		sed -i "s@\(.*_GCC_AUTOCONF_VERSION.*\)${AUTOCONF_VERMIN}\(.*\)@\1${AUTOCONF_VERSION}\2@" config/override.m4
#	fi
	${AUTOCONF}
	mkdir build
	cd build

	# Aggiungere per abilitare supporto alle stringhe multi-byte (wide-char)
	if [ "${ENABLE_WCMB}" == "yes" ]; then
		NEWLIB_CONF_PARAM="--enable-newlib-elix-level=2 --enable-newlib-mb --enable-newlib-wide-orient --enable-newlib-iconv --enable-newlib-iconv-external-ccs --enable-newlib-iconv-encodings=iso_8859_1,iso8859_15,cp1252,utf8,big5 "
	else
		NEWLIB_CONF_PARAM="--enable-newlib-elix-level=2 --disable-newlib-wide-orient "
	fi
	#note: this needs arm-*-{eabi|elf}-cc to exist or link to arm-*-{eabi|elf}-gcc
	../configure --target=${TOOLCHAIN_TARGET} --prefix=${TOOLCHAIN_PATH} \
		--enable-interwork \
		--enable-multilib \
		--enable-newlib-io-float \
		--enable-newlib-global-atexit \
		--enable-newlib-reent-small \
		--enable-newlib-multithread \
		--enable-newlib-io-c99-formats \
		--enable-lite-exit \
		--disable-newlib-supplied-syscalls \
		--disable-newlib-atexit-dynamic-alloc \
		--disable-newlib-fvwrite-in-streamio \
		--disable-newlib-fseek-optimization \
		--disable-newlib-unbuf-stream-opt \
		--enable-newlib-retargetable-locking \
		--disable-shared \
		--disable-nls \
		--with-gnu-as \
		--with-gnu-ld \
		--enable-lto \
		${NEWLIB_CONF_PARAM} \
		--with-gmp=${CORTEX_TOPDIR}/static \
		--with-mpfr=${CORTEX_TOPDIR}/static \
		--with-mpc=${CORTEX_TOPDIR}/static \
		2>&1 | tee configure.log

#	--enable-target-optspace
#	--with-libelf=${CORTEX_TOPDIR}/static
#Linaro:
#    --enable-newlib-io-long-long --enable-newlib-register-fini
#Freddie Chopin:
#- newlib with different configure options (--enable-newlib-register-fini removed, --enable-newlib-io-c99-formats, --disable-newlib-atexit-dynamic-alloc, --enable-newlib-reent-small, --disable-newlib-fvwrite-in-streamio, --disable-newlib-fseek-optimization, --disable-newlib-wide-orient, --disable-newlib-unbuf-stream-opt) 
#	--enable-lite-exit --disable-newlib-atexit-dynamic-alloc 
#-D__HAVE_LOCALE_INFO__ -D__HAVE_LOCALE_INFO_EXTENDED__
	make -j${NUM_JOBS} CFLAGS_FOR_TARGET="-DREENTRANT_SYSCALLS_PROVIDED -DSMALL_MEMORY -DHAVE_ASSERT_FUNC -D__BUFSIZ__=256 -D_MB_EXTENDED_CHARSETS_ALL -ffunction-sections -fdata-sections" 2>&1 | tee make.log
	make install 2>&1 | tee install.log
	cd ${CORTEX_TOPDIR}
	touch .newlib
fi

echo "Build GCC (second half)"
cd ${CORTEX_TOPDIR}
if [ ! -f .gcc-full ]; then
	cd gcc-${GCC_VER}/build
	make -j${NUM_JOBS} all 2>&1 | tee make-full.log
	make install-strip 2>&1 | tee install-full.log
	cd ${CORTEX_TOPDIR}
	touch .gcc-full
fi

echo "Build GDB"
cd ${CORTEX_TOPDIR}
if [ ! -f .gdb ]; then
	rm -rf gdb-${GDB_VER}
	tar xfJ ${DOWNLOAD_DIR}/gdb-${GDB_VER}.tar.xz
	cd gdb-${GDB_VER}
	mkdir build
	cd build
	../configure --target=${TOOLCHAIN_TARGET} --prefix=${TOOLCHAIN_PATH} \
		--enable-werror \
		--enable-stage1-checking=all \
		--enable-lto \
		--enable-multilib \
		--with-host-libstdcxx='-lstdc++' \
		--disable-nls \
		--disable-shared \
		--with-gmp=${CORTEX_TOPDIR}/static \
		--with-mpfr=${CORTEX_TOPDIR}/static \
		--with-mpc=${CORTEX_TOPDIR}/static \
		--with-libexpat-prefix=${CORTEX_TOPDIR}/static \
		2>&1 | tee configure.log

#	--with-libelf=${CORTEX_TOPDIR}/static

	make -j${NUM_JOBS} 2>&1 | tee make.log
	make install 2>&1 | tee install.log
	cd ${CORTEX_TOPDIR}
	touch .gdb
fi

cd ${CORTEX_TOPDIR}
echo "Done. Stripping binaries..."
for f in \
	${TOOLCHAIN_PATH}/bin/* \
	${TOOLCHAIN_PATH}/${TOOLCHAIN_TARGET}/bin/* \
	${TOOLCHAIN_PATH}/libexec/gcc/${TOOLCHAIN_TARGET}/${GCC_VER}/*
do
	if [ `file -b --mime-type ${f}` == "application/x-executable" ]; then
		echo "Stripping ${f}"
		strip ${f}
	fi
done

cd ${CORTEX_TOPDIR}
if [ ! -f .tarxz ]; then
	echo "Done. Build TAR XZ package..."
	cd ${TOOLCHAIN_PATH}/..
	tar cfJ ${TOOLCHAIN_NAME}.tar.xz ${TOOLCHAIN_NAME}
	echo "TAR XZ Done"
	cd ${CORTEX_TOPDIR}
	touch .tarxz
fi
echo "${TOOLCHAIN_NAME}" > ${CORTEX_TOPDIR}/artifact_name
echo "${HOME}/${TOOLCHAIN_NAME}.tar.xz" > ${CORTEX_TOPDIR}/artifact_path
cat ${CORTEX_TOPDIR}/artifact_path
echo "Done."
