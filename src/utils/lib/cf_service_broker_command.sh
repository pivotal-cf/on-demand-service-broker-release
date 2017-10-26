#! /bin/bash -eu

cf_service_broker_command() {
  broker_name=${1?"No service name provided, usage: cf_service_broker_command <service-name>"}

  if cf service-brokers | cut -f1 -d" " | grep -F -x ${broker_name} >/dev/null; then
    echo update-service-broker
  else
    echo create-service-broker
  fi
}
