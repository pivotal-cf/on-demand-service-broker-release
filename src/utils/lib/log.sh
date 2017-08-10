#!/usr/bin/env bash -u

log() {
  if [ -z "$LOG_FILE" ]; then
    echo "$LOG_FILE environment variable needs to be set for logging"
    return 1
  fi
  echo "$(date): $*" >> ${LOG_FILE}
  return 0
}
