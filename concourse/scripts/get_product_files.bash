#!/usr/bin/env bash

set -e
: "${PIVNET_API_TOKEN:?PIVNET_API_TOKEN is required}"
: "${GPDB_PKG_DIR:?GPDB_PKG_DIR is required}"
: "${PRODUCT_SLUG:?PRODUCT_SLUG is required}"

pivnet_cli_repo=pivotal-cf/pivnet-cli
path_to_pivnet_cli=/tmp/${pivnet_cli_repo}
mkdir -p "${path_to_pivnet_cli}"
PATH=${path_to_pivnet_cli}:${PATH}

latest_pivnet_cli_tag=$(curl --silent "https://api.github.com/repos/${pivnet_cli_repo}/releases/latest" | jq -r .tag_name)
wget "https://github.com/${pivnet_cli_repo}/releases/download/${latest_pivnet_cli_tag}/pivnet-linux-amd64-${latest_pivnet_cli_tag#v}" -O "${path_to_pivnet_cli}/pivnet"
chmod +x "${path_to_pivnet_cli}/pivnet"

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
	id=$(jq <<< "${product_files_json}" -r --arg object_key "${file}" '.[] | select(.aws_object_key == $object_key).id')
	echo "Downloading ${file} with id ${id}..."
	pivnet download-product-files \
		"--download-dir=${GPDB_PKG_DIR}" \
		"--product-slug=${PRODUCT_SLUG}" \
		"--release-version=${version}" \
		"--product-file-id=${id}" >/dev/null 2>&1 &
	pids+=( $! )
done

wait "${pids[@]}"
