#!/usr/bin/env bats

# Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.
# This program and the accompanying materials are made available under the terms of the under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.


setup() {
  source $BATS_TEST_DIRNAME/../../../../jobs/upgrade-all-service-instances/templates/common.sh

  TMPDIR=$(mktemp -dt "common_test.XXXXXXXXXX")
  LOGFILE_PATH=${TMPDIR}/logs
  touch $LOGFILE_PATH
}

teardown() {
  rm -rf ${TMPDIR}
}

stubUpgrader() {
  local output=$1

  cat >"${TMPDIR}/upgrader" <<EOL
    #!/usr/bin/env bash
    echo "\$@"
    echo $output
EOL

  chmod 0755 "${TMPDIR}/upgrader"

  echo ${TMPDIR}/upgrader
}

random_string() {
  cat /dev/urandom | env LC_CTYPE=C tr -dc a-zA-Z0-9 | head -c 16; echo
}

syslog_contents() {
  if [ "$(uname)" == "Darwin" ]; then
    cat "/var/log/system.log"
  else
    cat "/var/log/syslog"
  fi

}

permissions() {
  local path=$1
  if [ "$(uname)" == "Darwin" ]; then
    stat -f '%A' ${path}
  else
    stat -c '%a' ${path}
  fi
}

@test "ensure_dir creates a missing directory" {
  dir="${TMPDIR}/$(random_string)"
  user="$(id -u -n)"
  group="$(id -g -n)"

  [ ! -d "${dir}" ]

  run ensure_dir "${dir}" "${user}:${group}"

  [ "$status" -eq 0 ]
  [ -d "${dir}" ]
}

@test "ensure_dir sets the right permissions on a directory it created" {
  dir="${TMPDIR}/$(random_string)"
  user="$(id -u -n)"
  group="$(id -g -n)"

  run ensure_dir "${dir}" "${user}:${group}"

  [ "$status" -eq 0 ]
  [ "$(permissions ${dir})" == "750" ]
}

@test "ensure_dir sets the right permissions on an existing directory" {
  dir="${TMPDIR}/$(random_string)"
  user="$(id -u -n)"
  group="$(id -g -n)"

  mkdir -p "${dir}"
  chmod -R 700 "${dir}"

  run ensure_dir "${dir}" "${user}:${group}"

  [ "$status" -eq 0 ]
  [ "$(permissions ${dir})" == "750" ]
}

@test "ensure_dir does not set permissions on existing files and subdirs" {
  dir="${TMPDIR}/$(random_string)"
  subdir="${dir}/sub"
  file="${dir}/file"
  user="$(id -u -n)"
  group="$(id -g -n)"

  mkdir -p "${subdir}"
  touch "${file}"
  chmod -R 700 "${dir}"

  echo $(find -L "${dir}" | grep -v "packages" | xargs echo)

  run ensure_dir "${dir}" "${user}:${group}"

  [ "$(permissions ${dir})" == "750" ]
  [ "$(permissions ${subdir})" == "700" ]
  [ "$(permissions ${file})" == "700" ]
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

  echo $status
  echo $output

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

  echo $status
  echo $output

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

  echo $status
  echo $output

  [ "$status" -eq 0 ]
  [[ "$(cat ${LOGFILE_PATH})" =~ "$expected_output" ]]
}

@test "upgrade_all_instances logs to syslog" {
  local expected_output=$(random_string)

  run upgrade_all_instances \
        $(stubUpgrader ${expected_output}) \
        broker_username \
        broker_password \
        broker_url \
        polling_interval \
        ${LOGFILE_PATH} \
        user.notice

  echo $status
  echo $output

  [ "$status" -eq 0 ]
  [[ "$(syslog_contents)" =~ "$expected_output" ]]
}
