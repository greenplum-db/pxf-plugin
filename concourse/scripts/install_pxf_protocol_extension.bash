#!/usr/bin/env bash

# run as root
# should run on correct OS for Greenplum installation
# ubuntu18, centos{6,7}
set -e

: "${BIN_GPDB_DIR:?BIN_GPDB_DIR must be set}"
: "${PXF_PROTOCOL_EXTENSION_SRC:?PXF_PROTOCOL_EXTENSION_SRC must be set}"

tar zxvf "${BIN_GPDB_DIR}/bin_gpdb.tar.gz" -C /

source "$(< "${BIN_GPDB_DIR}/GPHOME")/greenplum_path.sh"

USE_PGXS=1 make -C "${PXF_PROTOCOL_EXTENSION_SRC}" install

tar zcvf "${BIN_GPDB_DIR}/bin_gpdb.tar.gz" -C / "${GPHOME}"
