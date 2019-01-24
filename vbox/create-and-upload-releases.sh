#!/usr/bin/env bash

set -eu

release_path=${1:-"."}

BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$BASE_DIR/config.sh"

echo ""
echo "-------------------------------------------------------"
echo "creating dev release..."
echo "-------------------------------------------------------"
echo ""

postfix="-local"
if [[ ! -z ${GFD_NO_DEV_ENV-} ]]; then
  postfix=
fi
echo BOSH target: "$BOSH_ENV_ALIAS"

# get the release name from the final.yml
final_config="$release_path/config/final.yml"

if [ ! -f $final_config ]; then
  echo "Cannot find $release_path/config/final.yml. Ensure you are in the release directory."
  exit 1
fi

release_name=$(grep name: $final_config | cut -d' ' -f2)${postfix}

bosh -e "$BOSH_ENV_ALIAS" create-release --force --name $release_name --dir $release_path

# set the release folder to the current dev environment's release folder
releases_dir="$release_path/dev_releases/$release_name"

# get the .yml file for the most recently created release
newest_release_file=$(ls -t $releases_dir/ | grep $release_name | head -1)

newest_release_location="$releases_dir/$newest_release_file"

# get the version from the release .yml file
newest_release_version=$(grep ^version: $newest_release_location | cut -d' ' -f2)

echo ""
echo "-------------------------------------------------------"
echo "uploading release $release_name, version $newest_release_version..."
echo "-------------------------------------------------------"
echo ""

bosh -e $BOSH_ENV_ALIAS upload-release $newest_release_location --version=$newest_release_version --dir $release_path
