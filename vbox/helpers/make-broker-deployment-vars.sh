#!/usr/bin/env bash

set -euo pipefail

BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$BASE_DIR/../config.sh"

indent_by() {
  if [ $# != 2 ]; then
    echo "Usage: indent_by <num_spaces> <multiline_value>"
    exit 1
  fi

  local multiline_value
  local str=$(printf "%0.s " $(seq 1 "$1"))
  multiline_value="$(echo -e "$2" | xargs -IN echo "$str"N)"
  echo "$multiline_value"
}

bosh_url="https://$BOSH_DIRECTOR_IP_ADDRESS:25555"
bosh_root_ca="$(bosh int "$BOSH_VARS_STORE" --path /director_ssl/ca)"
bosh_uaa_client_id="$BOSH_CLIENT"
bosh_uaa_client_secret="$BOSH_CLIENT_SECRET"
bosh_credhub_url="$BOSH_CREDHUB_URL"
bosh_credhub_ca="$(bosh int --path /credhub_ca/ca "$BOSH_VARS_STORE")"
bosh_credhub_client_id=director_to_credhub
bosh_credhub_client_secret="$(bosh int --path /uaa_clients_director_to_credhub "$BOSH_VARS_STORE")"

bosh_cmd() {
  BOSH_ENVIRONMENT="$bosh_url" BOSH_CA_CERT="$bosh_root_ca" BOSH_CLIENT="$bosh_uaa_client_id" BOSH_CLIENT_SECRET="$bosh_uaa_client_secret" bosh "$@"
}

set +o pipefail
stemcell_name=ubuntu-xenial
stemcell_version=$(bosh_cmd --json stemcells | jq -r ".Tables[0].Rows[] | select(.os == \"$stemcell_name\") | .version " | head -n1)
stemcell_version=${stemcell_version%\*}
set -o pipefail

cf_uaa_url="https://uaa.$SYSTEM_DOMAIN"
cf_uaa_ca_cert="$(bosh int --path /uaa_ca/certificate "$CF_VARS_STORE")"
cf_api_url="https://api.$SYSTEM_DOMAIN"
cf_admin_username=admin
cf_admin_password="$CF_ADMIN_PASSWORD"
cf_router_ca="$(bosh int --path /router_ca/certificate "$CF_VARS_STORE")"

cf_credhub_client_id=credhub_admin_client
cf_credhub_client_secret="$(bosh int --path /credhub_admin_client_secret "$CF_VARS_STORE")"

loggregator_ca_cert="$(bosh int --path /loggregator_ca/certificate "$CF_VARS_STORE")"
loggregator_metron_cert="$(bosh int --path /loggregator_tls_agent/certificate "$CF_VARS_STORE")"
loggregator_metron_key="$(bosh int --path /loggregator_tls_agent/private_key "$CF_VARS_STORE")"

echo "bosh:
  url: $bosh_url
  root_ca_cert: |
$(indent_by 4 "$bosh_root_ca")
  authentication:
    username: "$bosh_uaa_client_id"
    password: "$bosh_uaa_client_secret"
meta:
  services_subnet: default
  vm_type: t2.small
  az: z1
  stemcell:
    os: $stemcell_name
    version: "$stemcell_version"
bosh_credhub_api:
  url: $bosh_credhub_url
  root_ca_cert: |
$(indent_by 4 "$bosh_credhub_ca")
  authentication:
    uaa:
      client_credentials:
        client_id: $bosh_credhub_client_id
        client_secret: "$bosh_credhub_client_secret"
cf:
  system_domain: $SYSTEM_DOMAIN
  org: $CF_ORG
  space: $CF_SPACE
  deployment_name: cf
  uaa:
    url: $cf_uaa_url
    ca_cert: |
$(indent_by 6 "$cf_uaa_ca_cert")
  api_url: $cf_api_url
  user_credentials:
    username: $cf_admin_username
    password: $cf_admin_password
  router:
    ca_cert: |
$(indent_by 6 "$cf_router_ca")
credhub:
  client_id: "$cf_credhub_client_id"
  client_secret: "$cf_credhub_client_secret"
loggregator:
  etcd:
    ca_cert:
  tls:
    ca_cert: |
$(indent_by 6 "$loggregator_ca_cert")
    metron:
      cert: |
$(indent_by 8 "$loggregator_metron_cert")
      key: |
$(indent_by 8 "$loggregator_metron_key")
metron_endpoint:
  shared_secret:
metron_agent:
  etcd:
    client_cert:
    client_key:
  tls:
    metron:
      cert: |
$(indent_by 8 "$loggregator_metron_cert")
      key: |
$(indent_by 8 "$loggregator_metron_key")
" > $DIRECTOR_DIR/broker-deployment-vars.yml
