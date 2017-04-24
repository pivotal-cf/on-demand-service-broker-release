# Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.
# This program and the accompanying materials are made available under the terms of the under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

require 'spec_helper'

RSpec.describe 'upgrade-all-service-instances errand' do
  let(:renderer) do
    merged_context = BoshEmulator.director_merge(
      YAML.load_file(manifest_file.path),
      'upgrade-all-service-instances'
    )
    merged_context['links'] = {
      'broker' => {
        'instances' => [
          {
            'address' => "123.456.789.101"
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

  let(:rendered_template) { renderer.render('jobs/upgrade-all-service-instances/templates/errand.sh.erb') }

  context 'when the broker credentials contain special characters' do
    let(:manifest_file) { File.open 'spec/fixtures/upgrade_all_without_polling_interval.yml' }

    it 'escapes the broker username' do
      expect(rendered_template).to include "'%username'\\''\"t:%!'"
    end

    it 'escapes the broker password' do
      expect(rendered_template).to include "'%password'\\''\"t:%!'"
    end
  end

  context 'when the polling interval is not configured' do
    let(:manifest_file) { File.open 'spec/fixtures/upgrade_all_without_polling_interval.yml' }

    it 'sets the default polling interval' do
      expect(rendered_template).to include ("60 \\")
    end
  end

  context 'when the polling interval is configured' do
    let(:manifest_file) { File.open 'spec/fixtures/upgrade_all_with_polling_interval.yml' }

    it 'sets the default polling interval' do
      expect(rendered_template).to include ("101 \\")
    end
  end
end
