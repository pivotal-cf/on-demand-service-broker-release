#!/usr/bin/env bats

# Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.
# This program and the accompanying materials are made available under the terms of the under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

source $BATS_TEST_DIRNAME/../lib/upgrade_all_instances_tools.sh

setup() {
  LOGFILE_PATH=${BATS_TMPDIR}/logs
  touch $LOGFILE_PATH
}

teardown() {
  rm -f ${LOGFILE_PATH}
}

stubUpgrader() {
  local output=$1

  cat >"${BATS_TMPDIR}/upgrader" <<EOL
    #!/usr/bin/env bash
    echo "\$@"
    echo $output
EOL

  chmod 0755 "${BATS_TMPDIR}/upgrader"

  echo ${BATS_TMPDIR}/upgrader
}

random_string() {
  cat /dev/urandom | env LC_CTYPE=C tr -dc a-zA-Z0-9 | head -c 16; echo
}

@test "upgrade_all_instances passes the correct arguments" {
  local broker_username=$(random_string)
  local broker_password=$(random_string)
  local broker_url=$(random_string)
  local polling_interval=101

  run upgrade_all_instances \
        $(stubUpgrader) \
        ${broker_username} \
        ${broker_password} \
        ${broker_url} \
        ${polling_interval} \
        ${LOGFILE_PATH} \
        user.notice

  [ "$status" -eq 0 ]

  [[ "$output" =~ "-brokerUsername ${broker_username}" ]]
  [[ "$output" =~ "-brokerPassword ${broker_password}" ]]
  [[ "$output" =~ "-brokerUrl ${broker_url}" ]]
  [[ "$output" =~ "-pollingInterval ${polling_interval}" ]]
}

@test "upgrade_all_instances logs to stdout" {
  local expected_output=$(random_string)

  run upgrade_all_instances \
        $(stubUpgrader ${expected_output}) \
        broker_username \
        broker_password \
        broker_url \
        polling_interval \
        ${LOGFILE_PATH} \
        user.notice

  [ "$status" -eq 0 ]
  [[ "$output" =~ "${expected_output}" ]]
}

@test "upgrade_all_instances logs to the specified file" {
  local expected_output=$(random_string)

  run upgrade_all_instances \
        $(stubUpgrader ${expected_output}) \
        broker_username \
        broker_password \
        broker_url \
        polling_interval \
        ${LOGFILE_PATH} \
        user.notice

  [ "$status" -eq 0 ]
  [[ "$(cat ${LOGFILE_PATH})" =~ "$expected_output" ]]
}
