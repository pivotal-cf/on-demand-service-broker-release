#!/usr/bin/env bash

BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

DIRECTOR_DIR="$BASE_DIR/artifacts"
BOSH_VARS_STORE="$DIRECTOR_DIR/bosh-vars.yml"
CF_VARS_STORE="$DIRECTOR_DIR/cf-vars.yml"
workspace="${WORKSPACE:-$HOME/workspace}"
BOSH_LITE_DIR="$workspace/bosh-deployment"
CF_DIR="$workspace/cf-deployment"

BOSH_DIRECTOR_NAME=bosh-lite-director
BOSH_DIRECTOR_IP_ADDRESS=192.168.50.6
BOSH_DIRECTOR_GATEWAY=192.168.50.1
BOSH_DIRECTOR_CIDR=192.168.50.0/24
BOSH_CREDHUB_URL="https://$BOSH_DIRECTOR_IP_ADDRESS:8844"
SYSTEM_DOMAIN=bosh-lite.com #This is a valid domain, no need to change!
NETWORK_NAME=NatNetwork

BOSH_CLIENT=admin
BOSH_CLIENT_SECRET=admin

CF_ORG=system
CF_SPACE=test
CF_ADMIN_USERNAME=admin
CF_ADMIN_PASSWORD=admin

BOSH_ENV_ALIAS=vbox
