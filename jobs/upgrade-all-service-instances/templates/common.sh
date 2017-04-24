# Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.
# This program and the accompanying materials are made available under the terms of the under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

#! /bin/bash -eu

ensure_dir() {
  local dir=$1
  local owner=$2
  mkdir -p "${dir}"
  find -L "${dir}" | grep -v "packages" | xargs chown $2
  chmod 750 "${dir}"
}

write_user_log() {
  local log_tag=$1
  local log_file=$2
  local log_priority=$3
  logger -p $log_priority -t $log_tag -s 2>> $log_file
}

upgrade_all_instances() {
  local upgrader_path=$1
  local broker_username=$2
  local broker_password=$3
  local broker_url=$4
  local polling_interval=$5
  local log_file_path=$6
  local syslog_priority=$7

  $upgrader_path \
    -brokerUsername $broker_username \
    -brokerPassword $broker_password \
    -brokerUrl $broker_url \
    -pollingInterval $polling_interval \
    2>&1 | tee -a >(write_user_log upgrader $log_file_path $syslog_priority)
}
