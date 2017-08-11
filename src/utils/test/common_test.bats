#!/usr/bin/env bats

# Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.
# This program and the accompanying materials are made available under the terms of the under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

source $BATS_TEST_DIRNAME/../lib/common.sh

setup() {
  old_path=${PATH}
  DIR_TO_ENSURE=${BATS_TMPDIR}/dir_to_ensure
  ARGUMENTS_FILE_PATH=${BATS_TMPDIR}/arguments_for_chown
}

teardown() {
  PATH=${old_path}
  rm -rf ${DIR_TO_ENSURE}
  rm -f ${ARGUMENTS_FILE_PATH}
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
  user="$(id -u -n)"
  group="$(id -g -n)"

  [ ! -d "${DIR_TO_ENSURE}" ]

  run ensure_dir "${DIR_TO_ENSURE}" "${user}:${group}"

  [ "$status" -eq 0 ]
  [ -d "${DIR_TO_ENSURE}" ]
}

@test "ensure_dir sets the right permissions on a directory it created" {
  user="$(id -u -n)"
  group="$(id -g -n)"

  run ensure_dir "${DIR_TO_ENSURE}" "${user}:${group}"

  [ "$status" -eq 0 ]
  [ "$(permissions ${DIR_TO_ENSURE})" == "750" ]
}

@test "ensure_dir sets the right permissions on an existing directory" {
  user="$(id -u -n)"
  group="$(id -g -n)"

  mkdir -p "${DIR_TO_ENSURE}"
  chmod -R 700 "${DIR_TO_ENSURE}"

  run ensure_dir "${DIR_TO_ENSURE}" "${user}:${group}"

  [ "$status" -eq 0 ]
  [ "$(permissions ${DIR_TO_ENSURE})" == "750" ]
}

@test "ensure_dir does not set permissions on existing files and subdirs" {
  subdir="${DIR_TO_ENSURE}/sub"
  file="${DIR_TO_ENSURE}/file"
  user="$(id -u -n)"
  group="$(id -g -n)"

  mkdir -p "${subdir}"
  touch "${file}"
  chmod -R 700 "${DIR_TO_ENSURE}"

  echo $(find -L "${DIR_TO_ENSURE}" | grep -v "packages" | xargs echo)

  run ensure_dir "${DIR_TO_ENSURE}" "${user}:${group}"

  [ "$status" -eq 0 ]
  [ "$(permissions ${DIR_TO_ENSURE})" == "750" ]
  [ "$(permissions ${subdir})" == "700" ]
  [ "$(permissions ${file})" == "700" ]
}

@test "ensure_dir sets the user and group" {
  PATH=${BATS_TEST_DIRNAME}/mocks:${PATH}
  user="$(id -u -n)"
  group="$(id -g -n)"
  ARGUMENTS_FILE=${ARGUMENTS_FILE_PATH} run ensure_dir "${DIR_TO_ENSURE}" ${user}:${group}

  [ "$status" -eq 0 ]

  while read line; do
    [[ ${line} =~ "${user}:${group}" ]]
  done <${ARGUMENTS_FILE_PATH}
}


@test "ensure_dir without args sets the user and group to be vcap:vcap by default" {
  PATH=${BATS_TEST_DIRNAME}/mocks:${PATH}

  ARGUMENTS_FILE=${ARGUMENTS_FILE_PATH} run ensure_dir "${DIR_TO_ENSURE}"

  [ "$status" -eq 0 ]

  while read line; do
    [[ ${line} =~ "vcap:vcap" ]]
  done <${ARGUMENTS_FILE_PATH}
}
