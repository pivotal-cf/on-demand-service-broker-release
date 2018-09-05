#! /bin/bash -eu

cf_service_broker_command() {
  broker_name=${1?"No service name provided, usage: cf_service_broker_command <service-name>"}

  if cf service-brokers | cut -f1 -d" " | grep -F -x ${broker_name} >/dev/null; then
    echo update-service-broker
  else
    echo create-service-broker
  fi
}

RETRY_DELAY_SECS=${RETRY_DELAY_SECS:-5}
RETRY_COUNT=${RETRY_COUNT:-3}

cf_retry() {
  set +e
  cf_cmd="cf "$@
  for i in $(seq 1 $RETRY_COUNT); do
    if output=$($cf_cmd); then
      echo "${output}"
      set -e
      return 0
    fi
    echo "Retried failed CF command: cf $1"
    sleep "$RETRY_DELAY_SECS"
  done
  echo $output
  set -e
  return 1
}
