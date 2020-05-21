# frozen_string_literal: true

# Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.
# This program and the accompanying materials are made available under the terms of the under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

require 'spec_helper'
require 'tempfile'

RSpec.describe 'delete-all-service-instances-and-deregister-broker config' do
  let(:renderer) do
    merged_context = BoshEmulator.director_merge(
      YAML.load_file(manifest_file.path),
      'delete-all-service-instances-and-deregister-broker',
      [broker_link]
    )

    Bosh::Template::Renderer.new(context: merged_context.to_json)
  end

  let(:rendered_template) do
    renderer.render('jobs/delete-all-service-instances-and-deregister-broker/templates/config.yml.erb')
  end

  context 'with the broker link' do
    let(:manifest_file) { File.open 'spec/fixtures/delete_all_without_polling_configured.yml' }

    let(:broker_link) do
      {
        'broker' => {
          'instances' => [],
          'properties' => {
            'service_catalog' => {
              'id' => 'some-service-id'
            },
            'disable_ssl_cert_verification' => true,
            'cf' => {
              'url' => 'https://api.cf-app.com',
              'root_ca_cert' => 'cert',
              'uaa' => {
                'url' => 'https://uaa.cf-app.com',
                'authentication' => {
                  'client_credentials' => {
                    'client_id' => 'some_client_id',
                    'client_secret' => 'some_secret'
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
      }
    end

    let(:config) { YAML.safe_load(rendered_template) }

    it 'is not empty' do
      expect(config).not_to be_empty
    end

    it 'sets disable_ssl_cert_verification' do
      expect(config.fetch('disable_ssl_cert_verification')).to eq(true)
    end

    it 'sets service_id' do
      expect(config.fetch('service_catalog').fetch('id')).to(eq('some-service-id'))
    end

    it 'sets the cf url' do
      expect(config.fetch('cf').fetch('url')).to eq('https://api.cf-app.com')
    end

    it 'sets the cf root_ca_cert' do
      expect(config.fetch('cf').fetch('root_ca_cert')).to eq('cert')
    end

    it 'sets the cf authentication url' do
      expect(config.dig('cf', 'uaa', 'url')).to eq('https://uaa.cf-app.com')
    end

    it 'sets the cf authentication client_credentials' do
      expect(config.dig('cf', 'uaa', 'authentication', 'client_credentials', 'client_id')).to eq('some_client_id')
      expect(config.dig('cf', 'uaa', 'authentication', 'client_credentials', 'client_secret')).to eq('some_secret')
    end

    it 'sets the cf authentication user_credentials' do
      expect(config.dig('cf', 'uaa', 'authentication', 'user_credentials', 'username')).to eq('some-username')
      expect(config.dig('cf', 'uaa', 'authentication', 'user_credentials', 'password')).to eq('some-password')
    end

    context 'when the polling is not configured' do
      it 'sets the default polling interval' do
        expect(config.fetch('polling_interval')).to eq(60)
      end

      it 'sets the default polling offset' do
        expect(config.fetch('polling_initial_offset')).to eq(5)
      end
    end

    context 'when the polling is configured' do
      let(:manifest_file) { File.open 'spec/fixtures/delete_all_and_deregister_broker_with_polling_configured.yml' }

      it 'sets the configured polling interval' do
        expect(config.fetch('polling_interval')).to eq(101)
      end

      it 'sets the configured polling offset' do
        expect(config.fetch('polling_initial_offset')).to eq(10)
      end
    end
  end
end
