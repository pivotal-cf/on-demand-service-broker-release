# Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.
# This program and the accompanying materials are made available under the terms of the under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

require 'spec_helper'

RSpec.describe 'delete-all-service-instances-and-deregister-broker errand' do
  let(:renderer) { Bosh::Template::Renderer.new(context: BoshEmulator.director_merge(YAML.load_file(manifest_file), 'delete-all-service-instances-and-deregister-broker').to_json) }

  let(:rendered_template) { renderer.render('jobs/delete-all-service-instances-and-deregister-broker/templates/errand.sh.erb') }

  context 'broker name is set' do
    let(:manifest_file) { 'spec/fixtures/delete_all_and_deregister_broker_name_is_set.yml' }

    it 'errand calls delete-all-service-instances-and-deregister-broker binary with config and broker name' do
      broker_name = 'test-broker'
      binary_call = "/var/vcap/packages/delete-all-service-instances-and-deregister-broker/bin/purge-instances-and-deregister \\\n" +
      "  -configFilePath /var/vcap/jobs/delete-all-service-instances-and-deregister-broker/config/config.yml -brokerName #{broker_name}"

      expect(rendered_template).to include binary_call
    end
  end
end
