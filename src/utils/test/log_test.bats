#!/usr/bin/env bats

source ${BATS_TEST_DIRNAME}/../lib/log.sh

setup() {
  log_file=$(mktemp)
  old_path=${PATH}
  PATH=${BATS_TEST_DIRNAME}/mocks:${PATH}
}

teardown() {
  PATH=${old_path}
  rm -f $log_file
}

@test "logs a message to the log file" {
  message="I'm a log"

  LOG_FILE="${log_file}" run log "${message}"

  [ "$status" -eq "0" ]
  grep -q "${message}" $log_file
}

@test "prepends the output of date to the log message" {
  message="This is logging"
  LOG_FILE="${log_file}" run log "${message}"
  [ "$status" -eq "0" ]
  grep -q "Thu Aug 10 10:36:28 BST 2017: ${message}" $log_file
}

@test "logs a second message to the log file, leaving the first there" {
  message="I'm a log"
  LOG_FILE="${log_file}" run log "${message}"
  [ "$status" -eq "0" ]
  grep -q "${message}" $log_file

  second_message="Something went wrong!"
  LOG_FILE="${log_file}" run log "${second_message}"
  [ "$status" -eq "0" ]
  grep -q "${second_message}" $log_file
  grep -q "${message}" $log_file
}

@test "when LOG_FILE variable is not set fails with error message" {
  message="I'm a log"
  run log "${message}"
  [ "$status" -eq "1" ]
  [ "$output" = "$LOG_FILE environment variable needs to be set for logging" ]
}

@test "logs multiple distinct arguments" {
  LOG_FILE="${log_file}" run log warning "Error occured"
  [ "$status" -eq "0" ]
  grep -q "warning Error occured" $log_file
}
