#!/usr/bin/env bash

# this script installs the pxf protocol extension and rebundles GPDB into a
# tarball
# run it as root
# should run on correct OS for Greenplum installation, e.g. ubuntu18,
# centos{6,7}
set -e

: "${BIN_GPDB_DIR:?BIN_GPDB_DIR must be set}"
: "${PXF_PROTOCOL_EXTENSION_SRC:?PXF_PROTOCOL_EXTENSION_SRC must be set}"

tar zxf "${BIN_GPDB_DIR}/bin_gpdb.tar.gz" -C /

GPHOME=$(< "${BIN_GPDB_DIR}/GPHOME")
sed -ie "s|^GPHOME=.*$|GPHOME=${GPHOME}|" "${GPHOME}/greenplum_path.sh"
source "${GPHOME}/greenplum_path.sh"

USE_PGXS=1 make -C "${PXF_PROTOCOL_EXTENSION_SRC}" install

tar zcf "${BIN_GPDB_DIR}/bin_gpdb.tar.gz" -C / "${GPHOME}"
