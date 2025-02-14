#/bin/bash

set -e

if [ -z "${LOKI_HOME}" ]; then
	LOKI_HOME="$(realpath "$(dirname "${0}")")/../../../../.."
fi

set -u

CROSS_COMPILE_TRIPLET='x86_64-unknown-freebsd12.3'
CROSS_COMPILE_SYSTEM='freebsd'
CROSS_COMPILE_ARCHITECTURE='x86_64'
CROSS_COMPILE_SYSROOT="${LOKI_HOME}/${CROSS_COMPILE_TRIPLET}"

CC="${LOKI_HOME}/bin/${CROSS_COMPILE_TRIPLET}-gcc"
CXX="${LOKI_HOME}/bin/${CROSS_COMPILE_TRIPLET}-g++"
AR="${LOKI_HOME}/bin/${CROSS_COMPILE_TRIPLET}-ar"
AS="${LOKI_HOME}/bin/${CROSS_COMPILE_TRIPLET}-as"
LD="${LOKI_HOME}/bin/${CROSS_COMPILE_TRIPLET}-ld"
NM="${LOKI_HOME}/bin/${CROSS_COMPILE_TRIPLET}-nm"
RANLIB="${LOKI_HOME}/bin/${CROSS_COMPILE_TRIPLET}-ranlib"
STRIP="${LOKI_HOME}/bin/${CROSS_COMPILE_TRIPLET}-strip"
OBJCOPY="${LOKI_HOME}/bin/${CROSS_COMPILE_TRIPLET}-objcopy"
READELF="${LOKI_HOME}/bin/${CROSS_COMPILE_TRIPLET}-readelf"

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

set +eu
