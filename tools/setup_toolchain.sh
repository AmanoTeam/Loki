#!/bin/bash

set -eu

declare -r LOKI_HOME='/tmp/freebsd-gcc-cross-toolchain'

if [ -d "${LOKI_HOME}" ]; then
	PATH+=":${LOKI_HOME}/bin"
	export LOKI_HOME \
		PATH
	return 0
fi

declare -r LOKI_CROSS_TAG="$(jq --raw-output '.tag_name' <<< "$(curl --retry 10 --retry-delay 3 --silent --url 'https://api.github.com/repos/AmanoTeam/freebsd-gcc-cross/releases/latest')")"
declare -r LOKI_CROSS_TARBALL='/tmp/freebsd-gcc-cross.tar.xz'
declare -r LOKI_CROSS_URL="https://github.com/AmanoTeam/freebsd-gcc-cross/releases/download/${LOKI_CROSS_TAG}/x86_64-unknown-linux-gnu.tar.xz"

curl --retry 10 --retry-delay 3 --silent --location --url "${LOKI_CROSS_URL}" --output "${LOKI_CROSS_TARBALL}"
tar --directory="$(dirname "${LOKI_CROSS_TARBALL}")" --extract --file="${LOKI_CROSS_TARBALL}"

rm "${LOKI_CROSS_TARBALL}"

mv '/tmp/freebsd-gcc-cross' "${LOKI_HOME}"

PATH+=":${LOKI_HOME}/bin"

export LOKI_HOME \
	PATH
