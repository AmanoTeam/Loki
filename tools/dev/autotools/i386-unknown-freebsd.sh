#/bin/bash

kopt="${-}"

set +u
set -e

if [ -z "${LOKI_HOME}" ]; then
	LOKI_HOME="$(realpath "$(( [ -n "${BASH_SOURCE}" ] && dirname "$(realpath "${BASH_SOURCE[0]}")" ) || dirname "$(realpath "${0}")")""/../../../../..")"
fi

set -u

CROSS_COMPILE_TRIPLET='i386-unknown-freebsd'
CROSS_COMPILE_SYSTEM='freebsd'
CROSS_COMPILE_ARCHITECTURE='i386'
CROSS_COMPILE_SYSROOT="${LOKI_HOME}/${CROSS_COMPILE_TRIPLET}"

CC="${LOKI_HOME}/bin/${CROSS_COMPILE_TRIPLET}14.3-gcc"
CXX="${LOKI_HOME}/bin/${CROSS_COMPILE_TRIPLET}14.3-g++"
AR="${LOKI_HOME}/bin/${CROSS_COMPILE_TRIPLET}14.3-ar"
AS="${LOKI_HOME}/bin/${CROSS_COMPILE_TRIPLET}14.3-as"
LD="${LOKI_HOME}/bin/${CROSS_COMPILE_TRIPLET}14.3-ld"
NM="${LOKI_HOME}/bin/${CROSS_COMPILE_TRIPLET}14.3-nm"
RANLIB="${LOKI_HOME}/bin/${CROSS_COMPILE_TRIPLET}14.3-ranlib"
STRIP="${LOKI_HOME}/bin/${CROSS_COMPILE_TRIPLET}14.3-strip"
OBJCOPY="${LOKI_HOME}/bin/${CROSS_COMPILE_TRIPLET}14.3-objcopy"
READELF="${LOKI_HOME}/bin/${CROSS_COMPILE_TRIPLET}14.3-readelf"

export \
	CROSS_COMPILE_TRIPLET \
	CROSS_COMPILE_SYSTEM \
	CROSS_COMPILE_ARCHITECTURE \
	CROSS_COMPILE_SYSROOT \
	CC \
	CXX \
	AR \
	AS \
	LD \
	NM \
	RANLIB \
	STRIP \
	OBJCOPY \
	READELF

[[ "${kopt}" = *e*  ]] || set +e
[[ "${kopt}" = *u*  ]] || set +u
