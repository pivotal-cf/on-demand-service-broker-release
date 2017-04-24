# Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.
# This program and the accompanying materials are made available under the terms of the under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

require 'spec_helper'

RSpec.describe 'orphan-deployments errand' do
  let(:renderer) do
    merged_context = BoshEmulator.director_merge(YAML.load_file(manifest_file), 'orphan-deployments')
    merged_context['links'] = {
      'broker' => {
        'instances' => [
          {
            'address' => "123.456.789.101",
          }
        ],
        'properties' => {
          'username' => "%username'\"t:%!",
          'password' => "%password'\"t:%!",
          'port' => 8080
        }
      }
    }

    Bosh::Template::Renderer.new(context: merged_context.to_json)
  end

  let(:rendered_template) { renderer.render('jobs/orphan-deployments/templates/errand.sh.erb') }

  context 'when the broker credentials contain special characters' do
    let(:manifest_file) { 'spec/fixtures/orphan_deployments_with_special_characters.yml' }

    it 'escapes the broker credentials' do
      expect(rendered_template).to include "--user '%username'\\''\"t:%!':'%password'\\''\"t:%!'"
    end

    it 'sets a timeout for the request' do
      expect(rendered_template).to include "--max-time 30"
    end
  end
end
