#!/bin/bash -e

# Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.
# This program and the accompanying materials are made available under the terms of the under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.


set -o pipefail

must_have() { if [[ -z "${!1:-}" ]]; then echo "must have environment variable $1"; return 1; fi; }
release_version() { echo "0.1+dev.$(git rev-list --count HEAD)"; }

export CI_ROOT_PATH=$PWD

if [ -n "$BOSH_CA_CERT" ]; then
  export BOSH_CA_CERT_FILE=$PWD/cert
  echo "$BOSH_CA_CERT" > $BOSH_CA_CERT_FILE
  chmod 400 $BOSH_CA_CERT_FILE
fi

if [ -n "$BOSH_SSH_KEY" ]; then
  export BOSH_SSH_KEY_FILE=$PWD/ssh_key
  echo "$BOSH_SSH_KEY" > $BOSH_SSH_KEY_FILE
  chmod 400 $BOSH_SSH_KEY_FILE
fi

for v in CF_URL CF_DOMAIN CF_USERNAME CF_PASSWORD CF_ORG CF_SPACE BROKER_USERNAME BROKER_PASSWORD BOSH_URL BOSH_USERNAME BOSH_PASSWORD TEST_FOLDER_NAME
do
  must_have $v
done

export BROKER_NAME=$(cat uuid/uuid)
export SERVICE_NAME=$BROKER_NAME
export SERVICE_GUID=${SERVICE_GUID_PREFIX}${SERVICE_NAME}
export BROKER_DEPLOYMENT_NAME=odb-$BROKER_NAME
export BROKER_URL=https://${BROKER_DEPLOYMENT_NAME}.${CF_DOMAIN}
export BOSH_SSH_KEY_FILE=$BOSH_SSH_KEY

pushd $(dirname $0)/..
  export GOPATH=$PWD
  export PATH=$GOPATH/bin:$PATH
  export ODB_VERSION=$(release_version broker-release)

  go install github.com/onsi/ginkgo/ginkgo

  cf api $CF_URL --skip-ssl-validation
  cf auth $CF_USERNAME $CF_PASSWORD
  cf target -o $CF_ORG -s $CF_SPACE # must already exist

  pushd src/github.com/pivotal-cf/on-demand-service-broker
    ginkgo_cmd="ginkgo -randomizeSuites=true -randomizeAllSpecs=true -keepGoing=true -race -failOnPending"
    if [[ $RUN_IN_PARALLEL = "true" ]]; then
      ginkgo_cmd="${ginkgo_cmd} -p"
    fi

    ${ginkgo_cmd} system_tests/${TEST_FOLDER_NAME}
  popd
popd
