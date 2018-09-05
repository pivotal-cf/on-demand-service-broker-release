#!/usr/bin/env bats

source ${BATS_TEST_DIRNAME}/../lib/cf_commands.sh
load '/usr/local/lib/bats-support/load.bash'
load '/usr/local/lib/bats-assert/load.bash'

setup() {
  old_path=${PATH}
  PATH=${BATS_TEST_DIRNAME}/retry-mocks:${PATH}
  ARGUMENTS_FILE_PATH=${BATS_TMPDIR}/arguments_for_cf_retry
  TEST_COUNT_FILE_PATH=${BATS_TMPDIR}/counter_for_cf_retry
  echo 0 > $TEST_COUNT_FILE_PATH
}

teardown() {
  PATH=${old_path}
  rm -f "$ARGUMENTS_FILE_PATH"
  rm -f "$TEST_COUNT_FILE_PATH"
}

@test "cf_retry pass all given args to cf" {
  ARGUMENTS_FILE=${ARGUMENTS_FILE_PATH} run cf_retry foo bar 1 2

  while read line; do
    [[ ${line} = "foo bar 1 2" ]]
  done <${ARGUMENTS_FILE_PATH}
}

@test "cf_retry echoes stdout from cf cmd and returns 0 when cf cmd passes first time" {
  run cf_retry pass_on_1

  assert_output "normal output"
  assert_success
}

@test "cf_retry tries N times when cf cmd fails and returns a failure code" {
  RETRY_DELAY_SECS=0 RETRY_COUNT=4 run cf_retry always_fails

  assert_output "Retried failed CF command: cf always_fails
Retried failed CF command: cf always_fails
Retried failed CF command: cf always_fails
Retried failed CF command: cf always_fails"
  assert_failure
}

@test "cf_retry happily lets cf fail a couple of times then it works eventually" {
  TEST_COUNT_FILE=$TEST_COUNT_FILE_PATH RETRY_DELAY_SECS=0 run cf_retry fail_twice

  assert_output "Retried failed CF command: cf fail_twice
Retried failed CF command: cf fail_twice
succeeded!!"
  assert_success
}
