# frozen_string_literal: true

# Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.
# This program and the accompanying materials are made available under the terms of the under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

require 'spec_helper'

RSpec.describe 'orphan-deployments config' do
  let(:broker_link) do
    {
      'broker' => {
        'instances' => [
          {
            'address' => '123.456.789.101'
          }
        ],
        'properties' => {
          'username' => "%username'\"t:%!",
          'password' => "%password'\"t:%!",
          'port' => 7070
        }
      }
    }
  end

  let(:renderer) do
    merged_context = BoshEmulator.director_merge(
      YAML.load_file(manifest_file),
      'orphan-deployments',
      [broker_link]
    )
    Bosh::Template::Renderer.new(context: merged_context.to_json)
  end

  let(:rendered_template) { renderer.render('jobs/orphan-deployments/templates/config.yml.erb') }
  let(:config) { YAML.safe_load(rendered_template) }
  let(:manifest_file) { 'spec/fixtures/orphan_deployments_basic.yml' }

  context 'when the broker credentials contain special characters' do
    it 'escapes the broker credentials' do
      expect(config.fetch('broker_api').fetch('url')).to eq('http://123.456.789.101:7070')

      basic_auth_block = config.fetch('broker_api').fetch('authentication').fetch('basic')
      expect(basic_auth_block.fetch('username')).to eq("%username'\"t:%!")
      expect(basic_auth_block.fetch('password')).to eq("%password'\"t:%!")
    end
  end

  context 'with no service instances api specified' do
    it 'sets the service_instances_api url flag to be the management endpoint' do
      expect(config.fetch('service_instances_api').fetch('url')).to eq('http://123.456.789.101:7070/mgmt/service_instances')
    end

    it 'sets service instances api authentication to be the broker authentication' do
      basic_auth_block = config.fetch('service_instances_api').fetch('authentication').fetch('basic')
      expect(basic_auth_block.fetch('username')).to eq("%username'\"t:%!")
      expect(basic_auth_block.fetch('password')).to eq("%password'\"t:%!")
    end
  end

  context 'with service instances API specified' do
    let(:siapi_root_ca_cert) {false}
    let(:broker_link) do
      bl = {
        'broker' => {
          'instances' => [
            {
              'address' => '123.456.789.101'
            }
          ],
          'properties' => {
            'username' => "%username'\"t:%!",
            'password' => "%password'\"t:%!",
            'port' => 8080,
            'service_instances_api' => {
              'authentication' => {
                'basic' => {
                  'username' => "myname",
                  'password' => "supersecret"
                }
              },
              'url' => 'http://example.org/give-me/some-services',
            }
          }
        }
      }
      if siapi_root_ca_cert
        bl['broker']['properties']['service_instances_api']['root_ca_cert'] = siapi_root_ca_cert
      end
      bl
    end

    it 'sets the service_instances_api url flag to be the configured URL' do
      expect(config.fetch('service_instances_api').fetch('url')).to eq('http://example.org/give-me/some-services')
    end

    it 'sets correct service instances api authentication' do
      basic_auth_block = config.fetch('service_instances_api').fetch('authentication').fetch('basic')
      expect(basic_auth_block.fetch('username')).to eq('myname')
      expect(basic_auth_block.fetch('password')).to eq('supersecret')
    end

    it "doesn't set root_ca_cert" do
      expect(config.fetch('service_instances_api').key?('root_ca_cert')).to be_falsey
    end

    context 'and root_ca_cert provided' do
      let(:siapi_root_ca_cert) do
        '-----BEGIN CERTIFICATE-----
          MostCERTainlyACert
          -----END CERTIFICATE-----
        '
      end

      it 'sets correct root_ca_cert' do
        expect(config.fetch('service_instances_api').fetch('root_ca_cert')).to eq('-----BEGIN CERTIFICATE-----
          MostCERTainlyACert
          -----END CERTIFICATE-----
        ')
      end
    end
  end
end
