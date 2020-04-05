#!/usr/bin/env bash

set -e

: "${GPDB_PKG:?GPDB_PKG must be set}"
: "${BIN_GPDB_DIR:?BIN_GPDB_DIR must be set}"

BASE_DIR=${PWD}
EXTRACT_DIR=/tmp/extract/

mkdir -p "${EXTRACT_DIR}"
pushd "${EXTRACT_DIR}"
if [[ ${GPDB_PKG} =~ .*\.rpm$ ]]; then
	# https://stackoverflow.com/a/18787544
	rpm2cpio "${BASE_DIR}/${GPDB_PKG}" | cpio -idmv
elif [[ ${GPDB_PKG} =~ .*\.deb$ ]]; then
	ar x "${BASE_DIR}/${GPDB_PKG}"
	tar xvf data.tar.xz
else
	echo "${BASE_DIR}/${GPDB_PKG} is not an RPM or DEB file"
	exit 1
fi
popd

gpdb_home=$(find "${EXTRACT_DIR}" -type d -name 'greenplum-db-*')

list_of_pxf_files=(
	"${gpdb_home}/share/postgresql/extension/pxf.control"
	"${gpdb_home}/share/postgresql/extension/pxf--1.0.sql"
	"${gpdb_home}/pxf"
	"${gpdb_home}/lib/postgresql/pxf.so"
)

for file in "${list_of_pxf_files[@]}"; do
	[[ -e "${file}" ]] || { echo "${file} not found in GPDB archive, skipping..."; continue; }
	echo "removing ${file} from GPDB archive"
	rm -rf "${file}"
done

tar zcvf "${BIN_GPDB_DIR}/bin_gpdb.tar.gz" -C "${EXTRACT_DIR}" "${gpdb_home#"${EXTRACT_DIR}"}"
