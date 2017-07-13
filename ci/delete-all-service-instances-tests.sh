#!/bin/bash -eu

# Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.
# This program and the accompanying materials are made available under the terms of the under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.


set -o pipefail

must_have() { if [[ -z "${!1:-}" ]]; then echo "must have environment variable $1"; return 1; fi; }

for v in CF_URL CF_DOMAIN CF_USERNAME CF_PASSWORD CF_ORG CF_SPACE BROKER_USERNAME BROKER_PASSWORD BOSH_URL BOSH_USERNAME BOSH_PASSWORD
do
  must_have $v
done


uuid=$(cat uuid/uuid)
export BROKER_NAME="odb-${uuid}"
export SERVICE_NAME=${SERVICE_NAME_PREFIX:-}${uuid}
export SERVICE_GUID=${SERVICE_GUID_PREFIX:-}${uuid}
export BROKER_DEPLOYMENT_NAME="odb-${uuid}"
export BROKER_URL=https://${BROKER_DEPLOYMENT_NAME}.${CF_DOMAIN}

if [ ! -z "${BOSH_CA_CERT-}" ]; then
  export BOSH_CA_CERT_FILE=$PWD/cert
  echo "$BOSH_CA_CERT" > $BOSH_CA_CERT_FILE
  chmod 400 $BOSH_CA_CERT_FILE
fi

export EXAMPLE_APP_PATH=$(cd $(dirname $0)/../../example-app && pwd)
if [ ! -d $EXAMPLE_APP_PATH ]; then
  echo "$EXAMPLE_APP_PATH must exist as a directory" >&2
  exit 1
fi

pushd $(dirname $0)/..
  export GOPATH=$PWD
  export PATH=$GOPATH/bin:$PATH

  go install github.com/onsi/ginkgo/ginkgo

  cf api $CF_URL --skip-ssl-validation
  cf auth $CF_USERNAME $CF_PASSWORD
  cf target -o $CF_ORG -s $CF_SPACE # must already exist

  pushd src/github.com/pivotal-cf/on-demand-service-broker
    ginkgo -randomizeSuites=true -randomizeAllSpecs=true -keepGoing=true -race -failOnPending system_tests/delete_all_service_instances_tests
  popd
popd
