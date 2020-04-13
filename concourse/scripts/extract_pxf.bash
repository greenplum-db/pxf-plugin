#!/usr/bin/env bash

# this script removes the C client extension from GPDB binary
# run as gpadmin or root
# can run in centos6 or centos7 environments

set -e

: "${GPDB_PKG_DIR:?GPDB_PKG_DIR must be set}"
: "${BIN_GPDB_DIR:?BIN_GPDB_DIR must be set}"

BASE_DIR=${PWD}
EXTRACT_DIR=/tmp/extract/

mkdir -p "${EXTRACT_DIR}"
pushd "${EXTRACT_DIR}"

find "${GPDB_PKG_DIR}" -name 'greenplum*rpm' -exec rpm2cpio "{}" \; | cpio -idm
find "${GPDB_PKG_DIR}" -name 'greenplum*deb' -exec ar x "{}" \; tar xf data.tar.xz \;

popd

gpdb_home=$(find "${EXTRACT_DIR}" -type d -name 'greenplum-db-*')

list_of_pxf_files=(
	"${gpdb_home}/share/postgresql/extension/pxf.control"
	"${gpdb_home}/share/postgresql/extension/pxf--1.0.sql"
	"${gpdb_home}/pxf"
	"${gpdb_home}/lib/postgresql/pxf.so"
)

for file in "${list_of_pxf_files[@]}"; do
	if ! [[ -e "${file}" ]]; then
		echo "${file} not found in GPDB archive, skipping..."
		continue
	fi
	echo "removing ${file} from GPDB archive"
	rm -rf "${file}"
done

tar zcf "${BIN_GPDB_DIR}/bin_gpdb.tar.gz" -C "${EXTRACT_DIR}" "${gpdb_home#"${EXTRACT_DIR}"}"
echo "/${gpdb_home#"${EXTRACT_DIR}"}" >"${BIN_GPDB_DIR}/GPHOME"
