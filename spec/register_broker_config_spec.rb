# Copyright (C) 2019-Present Pivotal Software, Inc. All rights reserved.
# This program and the accompanying materials are made available under the terms of the under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

require 'spec_helper'
require 'tempfile'

RSpec.describe 'register-broker config' do
    let(:renderer) do
      merged_context = BoshEmulator.director_merge(
        YAML.load_file(manifest_file.path),
        'register-broker',
        [broker_link]
      )

      Bosh::Template::Renderer.new(context: merged_context.to_json)
    end

    let(:rendered_template) do
      renderer.render('jobs/register-broker/templates/config.yml.erb')
    end

    let(:broker_link) do
      {
        'broker' => {
          'instances' => [{}],
          'properties' => {
            'username' => "foo",
            'password' => "bar",
            'disable_ssl_cert_verification' => true,
            'cf' => {
              'url' => 'https://api.cf-app.com',
              'root_ca_cert' => 'cert',
              'authentication' => {
                'url' => 'https://uaa.cf-app.com',
                'client_credentials' => {
                  'client_id' => 'some_client_id',
                  'secret' => 'some_secret'
                },
                'user_credentials' => {
                  'username' => 'some-username',
                  'password' => 'some-password'
                }
              }
            }
          }
        }
      }
    end

    let(:config) { YAML.safe_load(rendered_template) }

    let(:manifest_file) { File.open 'spec/fixtures/register_broker_minimal.yml' }

    it 'includes CF configuration' do
      expect(config.dig('cf', 'url')).to eq('https://api.cf-app.com')
      expect(config.dig('cf', 'root_ca_cert')).to eq('cert')
      expect(config.dig('cf', 'authentication', 'uaa', 'url')).to eq('https://uaa.cf-app.com')
      expect(config.dig('cf', 'authentication', 'uaa', 'client_credentials', 'client_id')).to eq('some_client_id')
      expect(config.dig('cf', 'authentication', 'uaa', 'client_credentials', 'client_secret')).to eq('some_secret')
      expect(config.dig('cf', 'authentication', 'uaa', 'user_credentials', 'username')).to eq('some-username')
      expect(config.dig('cf', 'authentication', 'uaa', 'user_credentials', 'password')).to eq('some-password')
      expect(config.dig('disable_ssl_cert_verification')).to be_truthy
    end

    it 'includes broker configuration' do
      expect(config.dig('broker_name')).to eq('broker-name')
      expect(config.dig('broker_username')).to eq('foo')
      expect(config.dig('broker_password')).to eq('bar')
      expect(config.dig('broker_url')).to eq('some-uri')
    end
end
