#!/bin/bash

set -e
set -u

declare -r toolchain_tarball="$(pwd)/freebsd-cross.tar.xz"

declare -r gmp_tarball='/tmp/gmp.tar.xz'
declare -r gmp_directory='/tmp/gmp-6.2.1'

declare -r mpfr_tarball='/tmp/mpfr.tar.xz'
declare -r mpfr_directory='/tmp/mpfr-4.2.0'

declare -r mpc_tarball='/tmp/mpc.tar.gz'
declare -r mpc_directory='/tmp/mpc-1.3.1'

declare -r binutils_tarball='/tmp/binutils.tar.xz'
declare -r binutils_directory='/tmp/binutils-2.40'

declare -r gcc_tarball='/tmp/gcc.tar.xz'
declare -r gcc_directory='/tmp/gcc-12.2.0'

declare -r cflags='-Wno-unused-command-line-argument -Os -s -DNDEBUG'

if ! [ -f "${gmp_tarball}" ]; then
	wget --no-verbose 'https://ftp.gnu.org/gnu/gmp/gmp-6.2.1.tar.xz' --output-document="${gmp_tarball}"
	tar --directory="$(dirname "${gmp_directory}")" --extract --file="${gmp_tarball}"
fi

if ! [ -f "${mpfr_tarball}" ]; then
	wget --no-verbose 'https://ftp.gnu.org/gnu/mpfr/mpfr-4.2.0.tar.xz' --output-document="${mpfr_tarball}"
	tar --directory="$(dirname "${mpfr_directory}")" --extract --file="${mpfr_tarball}"
fi

if ! [ -f "${mpc_tarball}" ]; then
	wget --no-verbose 'https://ftp.gnu.org/gnu/mpc/mpc-1.3.1.tar.gz' --output-document="${mpc_tarball}"
	tar --directory="$(dirname "${mpc_directory}")" --extract --file="${mpc_tarball}"
fi

if ! [ -f "${binutils_tarball}" ]; then
	wget --no-verbose 'https://ftp.gnu.org/gnu/binutils/binutils-2.40.tar.xz' --output-document="${binutils_tarball}"
	tar --directory="$(dirname "${binutils_directory}")" --extract --file="${binutils_tarball}"
fi

if ! [ -f "${gcc_tarball}" ]; then
	wget --no-verbose 'https://ftp.gnu.org/gnu/gcc/gcc-12.2.0/gcc-12.2.0.tar.xz' --output-document="${gcc_tarball}"
	tar --directory="$(dirname "${gcc_directory}")" --extract --file="${gcc_tarball}"
fi

patch --directory="${gcc_directory}" --strip=1 < './0001-Fix-for-https-gcc.gnu.org-bugzilla-show_bug.cgi-id-9.patch' || true

while read file; do
	sed -i "s/-O2/${cflags}/g" "${file}"
done <<< "$(find '/tmp' -type 'f' -regex '.*configure')"

[ -d "${gcc_directory}/build" ] || mkdir "${gcc_directory}/build"

declare -r toolchain_directory="/tmp/unknown-unknown-freebsd"

[ -d "${gmp_directory}/build" ] || mkdir "${gmp_directory}/build"

cd "${gmp_directory}/build"

../configure \
	--prefix="${toolchain_directory}" \
	--enable-shared \
	--enable-static

make all --jobs
make install

[ -d "${mpfr_directory}/build" ] || mkdir "${mpfr_directory}/build"

cd "${mpfr_directory}/build"

../configure \
	--prefix="${toolchain_directory}" \
	--with-gmp="${toolchain_directory}" \
	--enable-shared \
	--enable-static

make all --jobs
make install

[ -d "${mpc_directory}/build" ] || mkdir "${mpc_directory}/build"

cd "${mpc_directory}/build"

../configure \
	--prefix="${toolchain_directory}" \
	--with-gmp="${toolchain_directory}" \
	--enable-shared \
	--enable-static

make all --jobs
make install

sed -i 's/#include <stdint.h>/#include <stdint.h>\n#include <stdio.h>/g' "${toolchain_directory}/include/mpc.h"

[ -d "${binutils_directory}/build" ] || mkdir "${binutils_directory}/build"

declare -r targets=(
	'amd64'
	'arm64'
	'i386'
	'powerpc/powerpc'
	'powerpc/powerpc64'
	'riscv/riscv64'
	'sparc64/sparc64'
)

for target in "${targets[@]}"; do
	declare version='14.0-CURRENT'
	
	if [ "${target}" == 'sparc64/sparc64' ]; then
		version='12.4-STABLE'
	fi
	
	declare url="https://download.freebsd.org/snapshots/${target}/${version}/base.txz"
	declare output="/tmp/freebsd-${target//\//_}-base.tar.xz"
	
	case "${target}" in
		amd64)
			declare triple='x86_64-unknown-freebsd14.0';;
		arm64)
			declare triple='aarch64-unknown-freebsd14.0';;
		i386)
			declare triple='i386-unknown-freebsd14.0';;
		powerpc/powerpc)
			declare triple='powerpc-unknown-freebsd14.0';;
		powerpc/powerpc64)
			declare triple='powerpc64-unknown-freebsd14.0';;
		riscv/riscv64)
			declare triple='riscv64-unknown-freebsd14.0';;
		sparc64/sparc64)
			declare triple='sparc64-unknown-freebsd12.4';;
	esac
	
	wget --no-verbose "${url}" --output-document="${output}"
	
	cd "${binutils_directory}/build"
	rm --force --recursive ./*
	
	../configure \
		--target="${triple}" \
		--prefix="${toolchain_directory}" \
		--enable-gold \
		--enable-ld
	
	make all --jobs="$(nproc)"
	make install
	
	tar --directory="${toolchain_directory}/${triple}" --strip=2 --extract --file="${output}" './usr/lib' './usr/include'
	tar --directory="${toolchain_directory}/${triple}" --extract --file="${output}"  './lib'
	
	pushd "${toolchain_directory}/${triple}/lib"
	
	if [ "${target}" != 'sparc64/sparc64' ]; then
		chmod 777 './libc++.so'
		echo 'GROUP ( ./libc++.so.1 ./libcxxrt.so )' > './libc++.so'
		chmod 444 './libc++.so'
	fi
	
	chmod 777 './libc.so'
	
	if [ "${target}" == 'sparc64/sparc64' ]; then
		echo 'GROUP ( ./libc.so.7 ./libc_nonshared.a ./libssp_nonshared.a )' > './libc.so'
	else
		echo 'GROUP ( ./libc.so.7 ./libc_nonshared.a )' > './libc.so'
	fi
	
	chmod 444 './libc.so'
	
	find . -xtype l | xargs ls -l | grep '/lib/' | awk '{print "unlink "$9" && ln -s $(basename "$11") $(basename "$9")"}' | bash 
	
	pushd
	
	cd "${gcc_directory}/build"
	
	rm --force --recursive ./*
	
	declare extra_configure_flags=''
	
	# https://reviews.freebsd.org/D20383
	if [[ "${target}" == 'powerpc/powerpc64' ]]; then
		extra_configure_flags+='--with-abi=elfv2'
	fi
	
	../configure \
		--target="${triple}" \
		--prefix="${toolchain_directory}" \
		--with-linker-hash-style='gnu' \
		--with-gmp="${toolchain_directory}" \
		--with-mpc="${toolchain_directory}" \
		--with-mpfr="${toolchain_directory}" \
		--with-system-zlib \
		--with-bugurl='https://github.com/AmanoTeam/FreeBSD-Cross/issues' \
		--enable-__cxa_atexit \
		--enable-cet='auto' \
		--enable-checking='release' \
		--enable-default-ssp \
		--enable-gnu-indirect-function \
		--disable-gnu-unique-object \
		--enable-libstdcxx-backtrace \
		--enable-link-serialization='1' \
		--enable-linker-build-id \
		--enable-lto \
		--disable-multilib \
		--enable-plugin \
		--enable-shared \
		--enable-threads='posix' \
		--enable-libssp \
		--disable-libstdcxx-pch \
		--disable-werror \
		--enable-languages='c,c++' \
		--disable-libgomp \
		--disable-bootstrap \
		--without-headers \
		--enable-ld \
		--enable-gold \
		--with-sysroot="${toolchain_directory}/${triple}" \
		--with-native-system-header-dir='/include' \
		${extra_configure_flags}
	
	LD_LIBRARY_PATH="${toolchain_directory}/lib" PATH="${PATH}:${toolchain_directory}/bin" make CFLAGS_FOR_TARGET="${cflags} -fno-stack-protector" CXXFLAGS_FOR_TARGET="${cflags} -fno-stack-protector" all --jobs="$(nproc)"
	make install
	
	rm --recursive "${toolchain_directory}/lib/gcc/${triple}/12.2.0/include-fixed"
done

tar --directory="$(dirname "${toolchain_directory}")" --create --file=- "$(basename "${toolchain_directory}")" |  xz --threads=0 --compress -9 > "${toolchain_tarball}"
