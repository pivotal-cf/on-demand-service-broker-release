#!/usr/bin/env bats

# Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.
# This program and the accompanying materials are made available under the terms of the under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.


setup() {
  TMPDIR=$(mktemp -dt "errand_test.XXXXXXXXXX")
  ERRAND_SCRIPT=${TMPDIR}/errand.sh
  ERRAND_TEMPLATE=${BATS_TEST_DIRNAME}/../../../../jobs/upgrade-all-service-instances/templates/errand.sh.erb

  RENDER_CONTEXT='{
    "properties": {
      "polling_interval": 101
    },
    "links": {
      "broker": {
        "instances": [
          {
            "address": "address"
          }
        ],
        "properties": {
          "username": "username",
          "password": "password",
          "port": "port"
        }
      }
    }
  }'

  ruby -rbosh/template/renderer \
       -e 'puts Bosh::Template::Renderer.new(context: ARGV[0]).render(ARGV[1])' \
       "${RENDER_CONTEXT}" \
       $ERRAND_TEMPLATE > $ERRAND_SCRIPT
}

teardown() {
  rm -rf ${TMPDIR}
}

upgrade_all_instances() {
  echo upgrade_args: $@
}

ensure_dir() {
  echo ensure_dir_args: $@
}

@test "errand script calls ensure_dir with the correct arguments" {
  run source $ERRAND_SCRIPT

  echo $status
  echo $output

  [ "$status" -eq 0 ]
  [[ "$output" =~ "ensure_dir_args: /var/vcap/sys/log/upgrade-all-service-instances vcap:vcap" ]]
}

@test "errand script calls upgrade_all_instances with the correct arguments" {
  run source $ERRAND_SCRIPT

  echo $status
  echo $output

  [ "$status" -eq 0 ]
  [[ "$output" =~ "upgrade_args: /var/vcap/packages/upgrade-all-service-instances/bin/upgrade-all-service-instances username password http://address:port 101 /var/vcap/sys/log/upgrade-all-service-instances/upgrade-all-instances.log user.info" ]]
}
