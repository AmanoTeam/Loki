#!/bin/bash

set -eu

declare -r toolchain_directory="/tmp/loki"
declare -r share_directory="${toolchain_directory}/usr/local/share/loki"

declare -r workdir="${PWD}"

declare -r revision="$(git rev-parse --short HEAD)"

declare -r gmp_tarball='/tmp/gmp.tar.xz'
declare -r gmp_directory='/tmp/gmp-6.3.0'

declare -r mpfr_tarball='/tmp/mpfr.tar.xz'
declare -r mpfr_directory='/tmp/mpfr-4.2.1'

declare -r mpc_tarball='/tmp/mpc.tar.gz'
declare -r mpc_directory='/tmp/mpc-1.3.1'

declare -r binutils_tarball='/tmp/binutils.tar.xz'
declare -r binutils_directory='/tmp/binutils-with-gold-2.44'

declare -r gcc_tarball='/tmp/gcc.tar.gz'
declare -r gcc_directory='/tmp/gcc-master'

declare -r optflags='-w -Os'
declare -r linkflags='-Wl,-s'

declare -r max_jobs="$(($(nproc) * 10))"

declare -r asan_libraries=(
	'libasan'
	'libhwasan'
	'liblsan'
	'libtsan'
	'libubsan'
)

declare -r plugin_libraries=(
	'libcc1plugin'
	'libcp1plugin'
)

declare build_type="${1}"

if [ -z "${build_type}" ]; then
	build_type='native'
fi

declare is_native='0'

if [ "${build_type}" == 'native' ]; then
	is_native='1'
fi

declare OBGGCC_TOOLCHAIN='/tmp/obggcc-toolchain'
declare CROSS_COMPILE_TRIPLET=''

declare cross_compile_flags=''

if ! (( is_native )); then
	source "./submodules/obggcc/toolchains/${build_type}.sh"
	cross_compile_flags+="--host=${CROSS_COMPILE_TRIPLET}"
fi

if ! [ -f "${gmp_tarball}" ]; then
	wget --no-verbose 'https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz' --output-document="${gmp_tarball}"
	tar --directory="$(dirname "${gmp_directory}")" --extract --file="${gmp_tarball}"
fi

if ! [ -f "${mpfr_tarball}" ]; then
	wget --no-verbose 'https://ftp.gnu.org/gnu/mpfr/mpfr-4.2.1.tar.xz' --output-document="${mpfr_tarball}"
	tar --directory="$(dirname "${mpfr_directory}")" --extract --file="${mpfr_tarball}"
fi

if ! [ -f "${mpc_tarball}" ]; then
	wget --no-verbose 'https://ftp.gnu.org/gnu/mpc/mpc-1.3.1.tar.gz' --output-document="${mpc_tarball}"
	tar --directory="$(dirname "${mpc_directory}")" --extract --file="${mpc_tarball}"
fi

if ! [ -f "${binutils_tarball}" ]; then
	wget --no-verbose 'https://ftp.gnu.org/gnu/binutils/binutils-with-gold-2.44.tar.xz' --output-document="${binutils_tarball}"
	tar --directory="$(dirname "${binutils_directory}")" --extract --file="${binutils_tarball}"
	
	patch --directory="${binutils_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Revert-gold-Use-char16_t-char32_t-instead-of-uint16_.patch"
	patch --directory="${binutils_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Disable-annoying-linker-warnings.patch"
fi

if ! [ -f "${gcc_tarball}" ]; then
	wget --no-verbose 'https://github.com/gcc-mirror/gcc/archive/refs/heads/master.tar.gz' --output-document="${gcc_tarball}"
	tar --directory="$(dirname "${gcc_directory}")" --extract --file="${gcc_tarball}"
	
	patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/patches/0001-Fix-FreeBSD-config-for-riscv.patch"
	patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Fix-libgcc-build-on-arm.patch"
	patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Change-the-default-language-version-for-C-compilatio.patch"
	patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Turn-Wimplicit-int-back-into-an-warning.patch"
	patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Turn-Wint-conversion-back-into-an-warning.patch"
	patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/submodules/obggcc/patches/0001-Revert-GCC-change-about-turning-Wimplicit-function-d.patch"
fi

[ -d "${gmp_directory}/build" ] || mkdir "${gmp_directory}/build"

cd "${gmp_directory}/build"

../configure \
	--prefix="${toolchain_directory}" \
	--enable-shared \
	--enable-static \
	${cross_compile_flags} \
	CFLAGS="${optflags}" \
	CXXFLAGS="${optflags}" \
	LDFLAGS="${linkflags}"

make all --jobs
make install

[ -d "${mpfr_directory}/build" ] || mkdir "${mpfr_directory}/build"

cd "${mpfr_directory}/build"

../configure \
	--prefix="${toolchain_directory}" \
	--with-gmp="${toolchain_directory}" \
	--enable-shared \
	--enable-static \
	${cross_compile_flags} \
	CFLAGS="${optflags}" \
	CXXFLAGS="${optflags}" \
	LDFLAGS="${linkflags}"

make all --jobs
make install

[ -d "${mpc_directory}/build" ] || mkdir "${mpc_directory}/build"

cd "${mpc_directory}/build"

../configure \
	--prefix="${toolchain_directory}" \
	--with-gmp="${toolchain_directory}" \
	--enable-shared \
	--enable-static \
	${cross_compile_flags} \
	CFLAGS="${optflags}" \
	CXXFLAGS="${optflags}" \
	LDFLAGS="${linkflags}"

make all --jobs
make install

[ -d "${binutils_directory}/build" ] || mkdir "${binutils_directory}/build"

declare -r targets=(
	'sparc64-unknown-freebsd12.3'
	'aarch64-unknown-freebsd12.3'
	'x86_64-unknown-freebsd12.3'
	'i386-unknown-freebsd12.3'
	'powerpc-unknown-freebsd12.3'
	'powerpc64-unknown-freebsd12.3'
	'powerpc64-unknown-freebsd13.0'
	'riscv64-unknown-freebsd14.2'
)

for triplet in "${targets[@]}"; do
	declare extra_configure_flags=''
	
	# Required due to https://reviews.freebsd.org/D20383
	if [ "${triplet}" == 'powerpc64-unknown-freebsd13.0' ]; then
		extra_configure_flags+='--with-abi=elfv2'
	fi
	
	if [ "${triplet}" == 'sparc64-unknown-freebsd12.3' ]; then
		extra_configure_flags+=' --disable-libsanitizer'
	fi
	
	cd "${binutils_directory}/build"
	rm --force --recursive ./*
	
	../configure \
		--target="${triplet}" \
		--prefix="${toolchain_directory}" \
		--enable-gold \
		--enable-ld \
		--enable-lto \
		--disable-gprofng \
		--with-static-standard-libraries \
		--with-sysroot="${toolchain_directory}/${triplet}" \
		${cross_compile_flags} \
		CFLAGS="${optflags}" \
		CXXFLAGS="${optflags}" \
		LDFLAGS="${linkflags}"
	
	make all --jobs="${max_jobs}"
	make install
	
	cd "$(mktemp --directory)"
	
	declare sysroot_url="https://github.com/AmanoTeam/freebsd-sysroot/releases/latest/download/${triplet}.tar.xz"
	declare sysroot_file="${PWD}/${triplet}.tar.xz"
	declare sysroot_directory="${PWD}/${triplet}"
	
	wget \
		--no-verbose \
		--output-document="${sysroot_file}" \
		"${sysroot_url}"
	
	tar \
		--extract \
		--file="${sysroot_file}"
	
	cp --recursive "${sysroot_directory}" "${toolchain_directory}"
	
	rm --force --recursive ./*
	
	# Required due to https://gcc.gnu.org/bugzilla/show_bug.cgi?id=78251
	if [ "${triplet}" == 'riscv64-unknown-freebsd14.2' ]; then
		mv "${toolchain_directory}/${triplet}/include/unwind.h" "${toolchain_directory}/${triplet}/include/unwind.h.bak"
	fi
	
	[ -d "${gcc_directory}/build" ] || mkdir "${gcc_directory}/build"
	
	cd "${gcc_directory}/build"
	
	rm --force --recursive ./*
	
	../configure \
		--target="${triplet}" \
		--prefix="${toolchain_directory}" \
		--with-linker-hash-style='gnu' \
		--with-gmp="${toolchain_directory}" \
		--with-mpc="${toolchain_directory}" \
		--with-mpfr="${toolchain_directory}" \
		--with-bugurl='https://github.com/AmanoTeam/Loki/issues' \
		--with-gcc-major-version-only \
		--with-pkgversion="Loki v0.7-${revision}" \
		--with-sysroot="${toolchain_directory}/${triplet}" \
		--with-native-system-header-dir='/include' \
		--includedir="${toolchain_directory}/${triplet}/include" \
		--enable-__cxa_atexit \
		--enable-cet='auto' \
		--enable-checking='release' \
		--enable-default-ssp \
		--enable-gnu-indirect-function \
		--enable-languages='c,c++' \
		--enable-libstdcxx-backtrace \
		--enable-link-serialization='1' \
		--enable-linker-build-id \
		--enable-lto \
		--enable-plugin \
		--enable-libsanitizer \
		--enable-shared \
		--enable-threads='posix' \
		--enable-libssp \
		--enable-ld \
		--enable-gold \
		--disable-fixincludes \
		--disable-libstdcxx-pch \
		--disable-werror \
		--disable-libgomp \
		--disable-bootstrap \
		--disable-multilib \
		--disable-gnu-unique-object \
		--without-headers \
		${extra_configure_flags} \
		${cross_compile_flags} \
		CFLAGS="${optflags}" \
		CXXFLAGS="${optflags}"
	
	LD_LIBRARY_PATH="${toolchain_directory}/lib" PATH="${PATH}:${toolchain_directory}/bin" make \
		CFLAGS_FOR_TARGET="${optflags} ${linkflags}" \
		CXXFLAGS_FOR_TARGET="${optflags} ${linkflags}" \
		all --jobs="${max_jobs}"
	make install
	
	if [ "${triplet}" == 'riscv64-unknown-freebsd14.2' ]; then
		mv "${toolchain_directory}/${triplet}/include/unwind.h.bak" "${toolchain_directory}/${triplet}/include/unwind.h"
	fi
	
	patchelf --add-rpath '$ORIGIN/../../../../lib' "${toolchain_directory}/libexec/gcc/${triplet}/"*"/cc1"
	patchelf --add-rpath '$ORIGIN/../../../../lib' "${toolchain_directory}/libexec/gcc/${triplet}/"*"/cc1plus"
	patchelf --add-rpath '$ORIGIN/../../../../lib' "${toolchain_directory}/libexec/gcc/${triplet}/"*"/lto1"
	
	for library in "${asan_libraries[@]}"; do
		patchelf --set-rpath '$ORIGIN' "${toolchain_directory}/lib"*"/${library}.so" || true
		patchelf --set-rpath '$ORIGIN' "${toolchain_directory}/${triplet}/lib"*"/${library}.so" || true
	done
	
	for library in "${plugin_libraries[@]}"; do
		patchelf --set-rpath "\$ORIGIN/../../../../../${triplet}/lib64:\$ORIGIN/../../../../../${triplet}/lib:\$ORIGIN/../../../../../lib64:\$ORIGIN/../../../../../lib" "${toolchain_directory}/lib/gcc/${triplet}/"*"/plugin/${library}.so"
	done
done

mkdir --parent "${share_directory}"

cp --recursive "${workdir}/tools/dev/"* "${share_directory}"
