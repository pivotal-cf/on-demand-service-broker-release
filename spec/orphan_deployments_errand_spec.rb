# frozen_string_literal: true

# Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.
# This program and the accompanying materials are made available under the terms of the under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

require 'spec_helper'

RSpec.describe 'orphan-deployments config' do
  let(:broker_links) do
    [{
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
    }]
  end

  let(:renderer) do
    merged_context = BoshEmulator.director_merge(
      YAML.load_file(manifest_file),
      'orphan-deployments',
      broker_links
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

  context 'when the manifest properties are provided' do
    let(:manifest_file) { 'spec/fixtures/orphan_deployments.yml' }

    it 'uses the properties in the config' do
      expect(config.fetch('broker_api').fetch('tls').fetch('ca_cert')).to eq('some cert')
      expect(config.fetch('broker_api').fetch('tls').fetch('disable_ssl_cert_verification')).to eq(true)
      expect(config.fetch('broker_api').fetch('url')).to eq('https://example-broker.com')
    end
  end

  context 'when broker uri is not provided' do
    context 'when broker uses TLS' do
      let(:broker_links) do
        [{
        'broker' => {
          'instances' => [
            {
              'address' => '123.456.789.101'
            }
          ],
          'properties' => {
            'username' => "user",
            'password' => "password",
            'port' => 8080,
            'tls' => {
              'certificate': 'some certificate'
            }
          }
        }
      }]
      end

      it 'uses https protocol to broker address' do
        expect(config.fetch('broker_api').fetch('url')).to eq('https://123.456.789.101:8080')
      end
    end

    context 'when broker does not use TLS' do
      it 'uses http protocol for broker address' do
        expect(config.fetch('broker_api').fetch('url')).to eq('http://123.456.789.101:7070')
      end
    end
  end

  context 'when disable_ssl_cert_verification is not set' do
    it 'defaults to false' do
      expect(config.fetch('broker_api').fetch('tls').fetch('disable_ssl_cert_verification')).to eq(false)
    end
  end
end
