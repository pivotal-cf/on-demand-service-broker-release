#!/bin/bash

# Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.
# This program and the accompanying materials are made available under the terms of the under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.


set -e

service ssh start

mkdir -p ~/.ssh

MY_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# This script expects to live two directories below the base directory.
BASE_DIR="$( cd "${MY_DIR}/../.." && pwd )"

AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:?}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:?}"
AWS_ACCESS_KEY_ID_RESTRICTED="${AWS_ACCESS_KEY_ID_RESTRICTED:?}"
AWS_SECRET_ACCESS_KEY_RESTRICTED="${AWS_SECRET_ACCESS_KEY_RESTRICTED:?}"
AZURE_STORAGE_ACCOUNT="${AZURE_STORAGE_ACCOUNT:?}"
AZURE_STORAGE_ACCESS_KEY="${AZURE_STORAGE_ACCESS_KEY:?}"

SERVICE_BACKUP_TESTS_GCP_SERVICE_ACCOUNT_JSON=${SERVICE_BACKUP_TESTS_GCP_SERVICE_ACCOUNT_JSON:?}

export SERVICE_BACKUP_TESTS_GCP_SERVICE_ACCOUNT_FILE=/tmp/gcp-service-account.json
echo "$SERVICE_BACKUP_TESTS_GCP_SERVICE_ACCOUNT_JSON" > $SERVICE_BACKUP_TESTS_GCP_SERVICE_ACCOUNT_FILE

export GOPATH=${BASE_DIR}
export PATH=${GOPATH}/bin:${PATH}

pushd "${BASE_DIR}"
  bundle install
  bundle exec rspec

  go install github.com/onsi/ginkgo/ginkgo
  ./src/github.com/pivotal-cf/service-backup/scripts/test_integration

  bats --tap $(find . -name *.bats)
popd
