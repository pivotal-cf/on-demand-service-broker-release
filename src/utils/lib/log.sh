#!/usr/bin/env bash -u

log() {
  if [ -z "$LOG_FILE" ]; then
    echo "$LOG_FILE environment variable needs to be set for logging"
    return 1
  fi
  echo "$(date): $*" >> ${LOG_FILE}
  return 0
}

write_user_log() {
  local log_tag=$1
  LOG_FILE=$2 log "$log_tag: $(cat /dev/stdin)"
}
