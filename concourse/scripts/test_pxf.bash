#!/usr/bin/env bash

: "${BIN_GPDB_DIR:?BIN_GPDB_DIR must be set}"
: "${PGPORT:?PGPORT must be set}"
: "${GROUP:?GROUP must be set}"
export GPHOME=/usr/local/greenplum-db-devel
source "${GPHOME}/greenplum_path.sh"
PXF_HOME=${GPHOME}/pxf
PXF_CONF_DIR=~gpadmin/pxf

if grep Ubuntu /etc/os-release >/dev/null; then
	apt update
	apt-get install uuid-runtime
fi

function run_pg_regress() {
	# run desired groups (below we replace commas with spaces in $GROUPS)
	local GPHD_ROOT=/singlecluster
	cat > ~gpadmin/run_pxf_automation_test.sh <<-EOF
		#!/usr/bin/env bash
		set -euxo pipefail

		source ${GPHOME}/greenplum_path.sh

		export GPHD_ROOT=${GPHD_ROOT}
		export PXF_HOME=${PXF_HOME} PXF_CONF=${PXF_CONF_DIR}
		export PGPORT=${PGPORT}
		export HCFS_CMD=${GPHD_ROOT}/bin/hdfs
		export HCFS_PROTOCOL=${PROTOCOL}

		time make -C ${PWD}/pxf_src/regression ${GROUP//,/ }
	EOF

	# we need to be able to write files under regression
	# and may also need to create files like ~gpamdin/pxf/servers/s3/s3-site.xml
	chown -R gpadmin "${PWD}/pxf_src/regression"
	chmod a+x ~gpadmin/run_pxf_automation_test.sh

	su gpadmin -c ~gpadmin/run_pxf_automation_test.sh
}

function install_pxf_server() {
	tar -xzf pxf_tarball/pxf.tar.gz -C ${GPHOME}
	chown -R gpadmin:gpadmin "${PXF_HOME}"
}

function start_pxf_server() {
	# Check if some other process is listening on 5888
	netstat -tlpna | grep 5888 || true

	echo 'Starting PXF service'
	su gpadmin -c "${PXF_HOME}/bin/pxf start"
	# grep with regex to avoid catching grep process itself
	ps -aef | grep '[t]omcat'
}

function init_and_configure_pxf_server() {
	local JAVA_HOME
	JAVA_HOME=$(find /usr/lib/jvm -name 'java-1.8.0-openjdk*' | head -1)
	echo 'Ensure pxf version can be run before pxf init'
	su gpadmin -c "${PXF_HOME}/bin/pxf version | grep -E '^PXF version [0-9]+.[0-9]+.[0-9]+$'" || exit 1

	echo 'Initializing PXF service'
	su gpadmin -c "JAVA_HOME=${JAVA_HOME} PXF_CONF=${PXF_CONF_DIR} ${PXF_HOME}/bin/pxf init"
}


function configure_pxf_default_server() {
	# copy hadoop config files to PXF_CONF_DIR/servers/default
	if [[ -d /etc/hadoop/conf/ ]]; then
		cp /etc/hadoop/conf/*-site.xml "${PXF_CONF_DIR}/servers/default"
	fi
	if [[ -d /etc/hive/conf/ ]]; then
		cp /etc/hive/conf/*-site.xml "${PXF_CONF_DIR}/servers/default"
	fi
	if [[ -d /etc/hbase/conf/ ]]; then
		cp /etc/hbase/conf/*-site.xml "${PXF_CONF_DIR}/servers/default"
	fi
}

function _main() {
	install_pxf_server

	init_and_configure_pxf_server

	configure_pxf_default_server

	start_pxf_server

	time run_pg_regress
}

_main
