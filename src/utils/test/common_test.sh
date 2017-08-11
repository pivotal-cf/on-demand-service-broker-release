#!/usr/bin/env bats

# Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.
# This program and the accompanying materials are made available under the terms of the under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

source $BATS_TEST_DIRNAME/../lib/common.sh

teardown() {
  rm -rf "${BATS_TMPDIR}/*"
}

random_string() {
  cat /dev/urandom | env LC_CTYPE=C tr -dc a-zA-Z0-9 | head -c 16; echo
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
  dir="${BATS_TMPDIR}/$(random_string)"
  user="$(id -u -n)"
  group="$(id -g -n)"

  [ ! -d "${dir}" ]

  run ensure_dir "${dir}" "${user}:${group}"

  [ "$status" -eq 0 ]
  [ -d "${dir}" ]
}

@test "ensure_dir sets the right permissions on a directory it created" {
  dir="${BATS_TMPDIR}/$(random_string)"
  user="$(id -u -n)"
  group="$(id -g -n)"

  run ensure_dir "${dir}" "${user}:${group}"

  [ "$status" -eq 0 ]
  [ "$(permissions ${dir})" == "750" ]
}

@test "ensure_dir sets the right permissions on an existing directory" {
  dir="${BATS_TMPDIR}/$(random_string)"
  user="$(id -u -n)"
  group="$(id -g -n)"

  mkdir -p "${dir}"
  chmod -R 700 "${dir}"

  run ensure_dir "${dir}" "${user}:${group}"

  [ "$status" -eq 0 ]
  [ "$(permissions ${dir})" == "750" ]
}

@test "ensure_dir does not set permissions on existing files and subdirs" {
  dir="${BATS_TMPDIR}/$(random_string)"
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
