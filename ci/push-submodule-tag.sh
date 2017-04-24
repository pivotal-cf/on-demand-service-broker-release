#!/bin/bash -eu

# Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.
# This program and the accompanying materials are made available under the terms of the under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

set -o pipefail

RELEASE_DIR=$(pwd)/broker-final-tag
SUBMODULE_DIR=$RELEASE_DIR/$SUBMODULE_PATH
TAG_DIR=$(pwd)/$TAG_PATH

RELEASE_TAG="$(git -C "$RELEASE_DIR" tag --list 'v*' --contains HEAD --sort=version:refname | tail -n1)"
SUBMODULE_TAG="$(git -C "$SUBMODULE_DIR" tag --list 'v*' --contains HEAD --sort=version:refname | tail -n1)"
if [ "$SUBMODULE_TAG" != "$RELEASE_TAG" ]; then
  git -C "$SUBMODULE_DIR" tag "$RELEASE_TAG"
fi
git clone "$SUBMODULE_DIR" "$TAG_DIR"
