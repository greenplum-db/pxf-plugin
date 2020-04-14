#!/usr/bin/env bash

: "${PGPORT:?PGPORT must be set}"
: "${GROUP:?GROUP must be set}"
export GPHOME=/usr/local/greenplum-db
source "${GPHOME}/greenplum_path.sh"
PXF_HOME=${GPHOME}/pxf
PXF_CONF_DIR=~gpadmin/pxf
GPHD_ROOT=/singlecluster
JAVA_HOME=$(find /usr/lib/jvm -name 'java-1.8.0-openjdk*' | head -1)

function run_pg_regress() {
	# run desired groups (below we replace commas with spaces in $GROUPS)
	cat >~gpadmin/run_pxf_automation_test.sh <<-EOF
		#!/usr/bin/env bash
		set -euxo pipefail
		source ${GPHOME}/greenplum_path.sh
		export GPHD_ROOT=${GPHD_ROOT}
		export PXF_HOME=${PXF_HOME} PXF_CONF=${PXF_CONF_DIR}
		export PGPORT=5432
		export HCFS_CMD=${GPHD_ROOT}/bin/hdfs
		export HCFS_PROTOCOL=${PROTOCOL}
		export JAVA_HOME=${JAVA_HOME}
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
	pgrep -f tomcat
}

function init_and_configure_pxf_server() {
	echo 'Ensure pxf version can be run before pxf init'
	su gpadmin -c "${PXF_HOME}/bin/pxf version | grep -E '^PXF version [0-9]+.[0-9]+.[0-9]+$'" || exit 1

	echo 'Initializing PXF service'
	su gpadmin -c "JAVA_HOME=${JAVA_HOME} PXF_CONF=${PXF_CONF_DIR} ${PXF_HOME}/bin/pxf init"
	# copy hadoop config files to PXF_CONF_DIR/servers/default
	[[ -d /etc/hadoop/conf/ ]] && cp /etc/hadoop/conf/*-site.xml "${PXF_CONF_DIR}/servers/default"
}

function init_hdfs() {
	local PROXY_USER=gpadmin

	# set up impersonation
	echo "Impersonation is enabled, adding support for proxy user ${PROXY_USER}"
	cat >proxy-config.xml <<-EOF
		<property>
		  <name>hadoop.proxyuser.${PROXY_USER}.hosts</name>
		  <value>*</value>
		</property>
		<property>
		  <name>hadoop.proxyuser.${PROXY_USER}.groups</name>
		  <value>*</value>
		</property>
		<property>
		  <name>hadoop.security.authorization</name>
		  <value>true</value>
		</property>
		<property>
		  <name>hbase.security.authorization</name>
		  <value>true</value>
		</property>
		<property>
		  <name>hbase.rpc.protection</name>
		  <value>authentication</value>
		</property>
		<property>
		  <name>hbase.coprocessor.master.classes</name>
		  <value>org.apache.hadoop.hbase.security.access.AccessController</value>
		</property>
		<property>
		  <name>hbase.coprocessor.region.classes</name>
		  <value>org.apache.hadoop.hbase.security.access.AccessController,org.apache.hadoop.hbase.security.access.SecureBulkLoadEndpoint</value>
		</property>
		<property>
		  <name>hbase.coprocessor.regionserver.classes</name>
		  <value>org.apache.hadoop.hbase.security.access.AccessController</value>
		</property>
	EOF
	sed -ie '/<configuration>/r proxy-config.xml' "${GPHD_ROOT}/hadoop/etc/hadoop/core-site.xml"
	rm proxy-config.xml
	"${GPHD_ROOT}/bin/init-gphd.sh"
	"${GPHD_ROOT}/bin/start-hdfs.sh"
}

install_pxf_server

init_and_configure_pxf_server

start_pxf_server

JAVA_HOME="${JAVA_HOME}" init_hdfs

run_pg_regress
