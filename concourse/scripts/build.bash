#!/usr/bin/env bash

set -eoux pipefail

GPDB_PKG_DIR=gpdb_package
GPDB_VERSION=$(<"${GPDB_PKG_DIR}/version")
GPHOME=/usr/local/greenplum-db-${version}

function install_gpdb() {
    if command -v rpm; then
	    rpm --quiet -ivh "${GPDB_PKG_DIR}/greenplum-db-${version}"-rhel*-x86_64.rpm
    elif command -v apt; then
	    # apt wants a full path
	    apt install -qq "${PWD}/${GPDB_PKG_DIR}/greenplum-db-${version}-ubuntu18.04-amd64.deb"
    else
	    echo "Cannot install RPM or DEB from ${GPDB_PKG_DIR}, no rpm or apt command available in this environment. Exiting..."
	    exit 1
    fi
}

function compile_pxf_protocol_extension() {
    source "${GPHOME}/greenplum_path.sh"
    if grep 'CentOS release 6' /etc/centos-release >/dev/null; then
	    source /opt/gcc_env.sh
    fi

    USE_PGXS=1 make -C "pxf-protocol-extension_src"
}

function package_pxf_protocol_extension() {
    echo "all the way !!"
}

install_gpdb
compile_pxf_protocol_extension
package_pxf_protocol_extension