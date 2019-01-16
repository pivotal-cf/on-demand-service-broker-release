#!/usr/bin/env bash

set -eu

BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$BASE_DIR/config.sh"


echo ""
echo "-------------------------------------------------------"
echo "Deleting $BOSH_ENV_ALIAS"
echo "-------------------------------------------------------"
echo ""

bosh -e "$BOSH_ENV_ALIAS" delete-env "$BOSH_LITE_DIR/bosh.yml" \
--state "$DIRECTOR_DIR/state.json" \
--vars-store "$BOSH_VARS_STORE" \
-o "$BOSH_LITE_DIR/virtualbox/cpi.yml" \
-o "$BOSH_LITE_DIR/virtualbox/outbound-network.yml" \
-o "$BOSH_LITE_DIR/bosh-lite.yml" \
-o "$BOSH_LITE_DIR/bosh-lite-runc.yml" \
-o "$BOSH_LITE_DIR/jumpbox-user.yml" \
-o "$BOSH_LITE_DIR/uaa.yml" \
-o "$BOSH_LITE_DIR/credhub.yml" \
-v director_name="$BOSH_DIRECTOR_NAME" \
-v internal_ip="$BOSH_DIRECTOR_IP_ADDRESS" \
-v internal_gw="$BOSH_DIRECTOR_GATEWAY" \
-v internal_cidr="$BOSH_DIRECTOR_CIDR" \
-v outbound_network_name="$NETWORK_NAME"


