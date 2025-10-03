#!/bin/bash
set -euo pipefail

CACHEDIR="$1"
shift

SCRIPT='
    to_entries | .[] |
    select(.value.enabled == "1" and .value.baseurl == "oci://*")
'
d="$(echo "$@" | tr " " "\n" | tr "," "\n" | yq -p props -o json -I 0 "${SCRIPT}")"

oci_repos=()
output=()

# Now, for each repo, download the repodata
while IFS= read -r line; do
    # Example line:
    # {"key":"oci-repo-test","value":{"baseurl":"oci://quay.io/lucarval/yum-repo:latest","enabled":"1"}}
    REPO_NAME="$(<<< "${d}" yq --exit-status '.key')"
    BASEURL="$(<<< "${d}" yq --exit-status '.value.baseurl')"

    # Compute repo cache name
    REPO_CACHE="${CACHEDIR}/${REPO_NAME}-$(printf '%s' "${BASEURL}" | sha256sum | head -c 16)"

    # TODO: Take cache expiration config into consideration.
    rm -rf "${REPO_CACHE}"
    mkdir -p "${REPO_CACHE}/oci"

    MANIFEST_PATH="${REPO_CACHE}/oci/manifest.json"
    REF="${BASEURL#oci://}"
    oras manifest fetch --no-tty "${REF}" --output "${MANIFEST_PATH}"
    # Get digest of the repodata blob
    REPODATA_DIGEST="$(
        < "${MANIFEST_PATH}" yq --exit-status \
        '.layers[] | select(.annotations["org.opencontainers.image.title"] == "repodata") | .digest'
    )"

    OCI_REPO="$(printf "${REF/@*}" | sed 's_/\(.*\):\(.*\)_/\1_g')"

    oras blob fetch --no-tty "${OCI_REPO}@${REPODATA_DIGEST}" --output - | tar -xz -C "${REPO_CACHE}"

    printf "${OCI_REPO}" > "${REPO_CACHE}/oci/repo"

    output+=("conf.${REPO_NAME}.baseurl=${REPO_CACHE}")
    oci_repos+=("${REPO_NAME}=${REPO_CACHE}")

done <<< "${d}"

echo "${output[@]}"
echo "tmp.oci_repos=$(printf "${oci_repos[*]}" | tr ' ' ',')"

