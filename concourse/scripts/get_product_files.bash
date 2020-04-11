#!/usr/bin/env bash

set -e

: "${PIVNET_API_TOKEN:?PIVNET_API_TOKEN is required}"
: "${PIVNET_CLI_DIR:?PIVNET_CLI_DIR is required}"
: "${RHEL6_RPM_DIR:?RHEL6_RPM_DIR is required}"
: "${RHEL7_RPM_DIR:?RHEL7_RPM_DIR is required}"
: "${UBUNTU18_DEB_DIR:?UBUNTU18_DEB_DIR is required}"
: "${PRODUCT_SLUG:?PRODUCT_SLUG is required}"

pivnet_cli_repo=pivotal-cf/pivnet-cli
PATH=${PIVNET_CLI_DIR}:${PATH}

chmod_pivnet() {
	chmod +x "${PIVNET_CLI_DIR}/pivnet"
}

latest_pivnet_cli_tag=$(curl --silent "https://api.github.com/repos/${pivnet_cli_repo}/releases/latest" | jq -r .tag_name)
if chmod_pivnet && [[ ${latest_pivnet_cli_tag#v} == $(pivnet --version) ]]; then
	echo "Already have version ${latest_pivnet_cli_tag} of pivnet-cli, skipping download..."
else
	echo "Downloading version ${latest_pivnet_cli_tag} of pivnet-cli..."
	wget -q "https://github.com/${pivnet_cli_repo}/releases/download/${latest_pivnet_cli_tag}/pivnet-linux-amd64-${latest_pivnet_cli_tag#v}" -O "${PIVNET_CLI_DIR}/pivnet"
	chmod_pivnet
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
product_dirs=("${RHEL6_RPM_DIR}" "${RHEL7_RPM_DIR}" "${UBUNTU18_DEB_DIR}")

product_files_json=$(pivnet --format=json product-files "--product-slug=${PRODUCT_SLUG}" --release-version "${version}")
for ((i = 0; i < ${#product_files[@]}; i++)); do
	file=${product_files[$i]}
	download_path=${product_dirs[$i]}/${file##*/}
	if [[ -e ${download_path} ]]; then
		echo "Found file ${download_path}, checking sha256sum..."
		sha256=$(jq <<<"${product_files_json}" -r --arg object_key "${file}" '.[] | select(.aws_object_key == $object_key).sha256')
		sum=$(sha256sum "${download_path}" | cut -d' ' -f1)
		if [[ ${sum} == "${sha256}" ]]; then
			echo "Sum is equivalent, skipping download of ${file}..."
			continue
		fi
	fi
	id=$(jq <<<"${product_files_json}" -r --arg object_key "${file}" '.[] | select(.aws_object_key == $object_key).id')
	echo "Downloading ${file} with id ${id} to ${product_dirs[$i]}..."
	pivnet download-product-files \
		"--download-dir=${product_dirs[$i]}" \
		"--product-slug=${PRODUCT_SLUG}" \
		"--release-version=${version}" \
		"--product-file-id=${id}" >/dev/null 2>&1 &
	pids+=($!)
done

wait "${pids[@]}"
