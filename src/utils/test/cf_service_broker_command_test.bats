#!/usr/bin/env bats

source ${BATS_TEST_DIRNAME}/../lib/cf_service_broker_command.sh

setup() {
  old_path=${PATH}
  PATH=${BATS_TEST_DIRNAME}/mocks:${PATH}
}

teardown() {
  PATH=${old_path}
}

@test "when service broker doesn't exist returns create-service-broker" {
  SERVICE_NAME="example" run cf_service_broker_command "new-service"
  [ "$status" -eq 0 ]
  [ "$output" == "create-service-broker" ]
}

@test "when service broker does exist returns update-service-broker" {
  SERVICE_NAME="existing-service" run cf_service_broker_command "existing-service"
  [ "$status" -eq 0 ]
  [ "$output" == "update-service-broker" ]
}

@test "when service broker with a longer name which matches as a substring exists returns create-service-broker" {
  SERVICE_NAME="existing-service-dev1" run cf_service_broker_command "existing-service"
  [ "$status" -eq 0 ]
  [ "$output" == "create-service-broker" ]
}

@test "when service broker with the same name but with a - instead of a . exists returns create-service-broker" {
  SERVICE_NAME="existing-service" run cf_service_broker_command "existing.service"
  [ "$status" -eq 0 ]
  [ "$output" == "create-service-broker" ]
}

@test "when called without an argument returns non-zero status and a message" {
  run cf_service_broker_command
  [ "$status" -ne 0 ]
  [[ "$output" =~ "No service name provided, usage: cf_service_broker_command <service-name>" ]]
}
