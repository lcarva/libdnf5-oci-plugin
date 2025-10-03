#!/bin/bash
set -euo pipefail

OCI_REPOS="$1"
REPO_ID="$2"
RPM_NAME="$3"

# TODO: This is probably not gonna work for repo names with dots in them. Is that allowed?
REPO_CACHE="$(
    echo "${OCI_REPOS}" | tr "," "\n" |
    REPO_ID="${REPO_ID}" yq -p props -I 0 --exit-status '.[env(REPO_ID)]' \
)"

MANIFEST_PATH="${REPO_CACHE}/oci/manifest.json"
OCI_REPO="$(< "${REPO_CACHE}/oci/repo")"

# Get digest for the rpm
RPM_DIGEST="$(
    < "${MANIFEST_PATH}" \
    RPM_NAME="${RPM_NAME}" \
    yq --exit-status \
    '.layers[] | select(.annotations["org.opencontainers.image.title"] == env(RPM_NAME)) | .digest'
)"

oras blob fetch --no-tty "${OCI_REPO}@${RPM_DIGEST}" --output "${REPO_CACHE}/${RPM_NAME}"

