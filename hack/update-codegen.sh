#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_ROOT="$(dirname "${BASH_SOURCE[0]}")/.."

if ( ! ( command -v controller-gen > /dev/null )  || test "$(controller-gen --version)" != "Version: v0.4.0" ); then
  echo "controller-gen not found or out-of-date, installing sigs.k8s.io/controller-tools@v0.4.0..."
  olddir="${PWD}"
  builddir="$(mktemp -d)"
  cd "${builddir}"
  GO111MODULE=on go get -u sigs.k8s.io/controller-tools/cmd/controller-gen@v0.4.0
  cd "${olddir}"
  if [[ "${builddir}" == /tmp/* ]]; then #paranoia
      rm -rf "${builddir}"
  fi
fi

bash "${SCRIPT_ROOT}/vendor/k8s.io/code-generator/generate-groups.sh" deepcopy \
  github.com/openshift/openshift-network-operator/pkg/generated github.com/openshift/cluster-network-operator/pkg/apis \
  "network:v1" \
  --go-header-file "${SCRIPT_ROOT}/hack/custom-boilerplate.go.txt"


echo "Generating CRDs"
mkdir -p _output/crds
controller-gen crd paths=./pkg/apis/... output:crd:dir=_output/crds

# ensure our CRD is installed by setting a "release profile"
RELEASE_PROFILE="include.release.openshift.io/self-managed-high-availability=true"
ROKS_PROFILE="include.release.openshift.io/ibm-cloud-managed=true"
HEADER="# This file is automatically generated. DO NOT EDIT"

# Add a new CRD? Duplicate these lines
echo "${HEADER}" > manifests/0000_70_cluster-network-operator_01_pki_crd.yaml
oc annotate --local -o yaml \
  "${RELEASE_PROFILE}" \
  "${ROKS_PROFILE}" \
  -f _output/crds/network.operator.openshift.io_operatorpkis.yaml >> manifests/0000_70_cluster-network-operator_01_pki_crd.yaml

oc annotate --local -o yaml \
  "${RELEASE_PROFILE}" \
  "${ROKS_PROFILE}" \
  -f _output/crds/network.operator.openshift.io_egressrouters.yaml >> manifests/0000_70_cluster-network-operator_05_egr_crd.yaml
