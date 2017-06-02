#!/bin/bash -e

# Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.
# This program and the accompanying materials are made available under the terms of the under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.


if [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$AWS_ACCESS_KEY_ID" ]; then
  echo "must set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY" >&2
  exit 1
fi

if [ -z "$1" ]; then
  echo "Usage: trigger-final-release.sh sha-to-release" >&2
  exit 1
fi

sha_to_release=$1
shift

sha_file=$PWD/service-backup-release.sha
function cleanup() {
  rm $sha_file
}
trap cleanup EXIT

echo $sha_to_release > $sha_file

aws s3 cp $sha_file s3://services-enablement-ci-triggers/
