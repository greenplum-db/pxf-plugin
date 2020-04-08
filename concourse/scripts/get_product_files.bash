#!/usr/bin/env bash

set -e
: "${PIVNET_API_TOKEN:?PIVNET_API_TOKEN is required}"
: "${GPDB_PKG_DIR:?GPDB_PKG_DIR is required}"
: "${PRODUCT_SLUG:?PRODUCT_SLUG is required}"

pivnet_cli_repo=pivotal-cf/pivnet-cli
path_to_pivnet_cli=${GPDB_PKG_DIR}/${pivnet_cli_repo}
mkdir -p "${path_to_pivnet_cli}"
PATH=${path_to_pivnet_cli}:${PATH}

latest_pivnet_cli_tag=$(curl --silent "https://api.github.com/repos/${pivnet_cli_repo}/releases/latest" | jq -r .tag_name)
if [[ -e ${path_to_pivnet_cli}/pivnet && $(pivnet --version) =~ ${latest_pivnet_cli_tag} ]]; then
	echo "Already have the latest version of pivnet-cli, skipping download..."
else
	wget "https://github.com/${pivnet_cli_repo}/releases/download/${latest_pivnet_cli_tag}/pivnet-linux-amd64-${latest_pivnet_cli_tag#v}" -O "${path_to_pivnet_cli}/pivnet"
	chmod +x "${path_to_pivnet_cli}/pivnet"
fi

# log in to pivnet
pivnet login "--api-token=${PIVNET_API_TOKEN}"

# get version numbers in sorted order
# https://stackoverflow.com/questions/57071166/jq-find-the-max-in-quoted-values/57071319#57071319
version=$(pivnet --format=json releases "--product-slug=${PRODUCT_SLUG}" | jq -r 'sort_by(.version | split(".") | map(tonumber))[-1].version')
echo "Latest version found is ${version}"

product_files=(
	"product_files/Pivotal-Greenplum/greenplum-db-${version}-rhel6-x86_64.rpm"
	"product_files/Pivotal-Greenplum/greenplum-db-${version}-rhel7-x86_64.rpm"
	"product_files/Pivotal-Greenplum/greenplum-db-${version}-ubuntu18.04-amd64.deb"
)

product_files_json=$(pivnet --format=json product-files "--product-slug=${PRODUCT_SLUG}" --release-version "${version}")
for file in "${product_files[@]}"; do
	sha256=$(jq <<< "${product_files_json}" -r --arg object_key "${file}" '.[] | select(.aws_object_key == $object_key).sha256')
	if [[ -e ${GPDB_PKG_DIR}/${version}/${file} ]]; then
		echo "Found file ${GPDB_PKG_DIR}/${version}/${file}, checking sha256sum..."
		sum=$(sha256sum "${GPDB_PKG_DIR}/${version}/${file}" | cut -d' ' -f1)
		if [[ ${sum} == ${sha256} ]]; then
			echo "Sum is equivalent, skipping download of ${file}..."
			continue
		fi
	fi
	id=$(jq <<< "${product_files_json}" -r --arg object_key "${file}" '.[] | select(.aws_object_key == $object_key).id')
	echo "Downloading ${file} with id ${id}..."
	mkdir -p "${GPDB_PKG_DIR}/${version}"
	pivnet download-product-files \
		"--download-dir=${GPDB_PKG_DIR}/${version}" \
		"--product-slug=${PRODUCT_SLUG}" \
		"--release-version=${version}" \
		"--product-file-id=${id}" >/dev/null 2>&1 &
	pids+=( $! )
done

wait "${pids[@]}"
