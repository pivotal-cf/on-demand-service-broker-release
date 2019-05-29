# frozen_string_literal: true

# Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.
# This program and the accompanying materials are made available under the terms of the under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

require 'spec_helper'
require 'tempfile'

RSpec.describe 'upgrade-all-service-instances config' do
  let(:manifest_file) { File.open 'spec/fixtures/upgrade_all_minimal.yml' }

  let(:renderer) do
    merged_context = BoshEmulator.director_merge(
      YAML.load_file(manifest_file.path),
      'upgrade-all-service-instances',
      [broker_link]
    )
    Bosh::Template::Renderer.new(context: merged_context.to_json)
  end

  let(:rendered_template) do
    renderer.render('jobs/upgrade-all-service-instances/templates/config.yml.erb')
  end

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
          'port' => 8080,
        }
      }
    }
  end

  let(:config) { YAML.safe_load(rendered_template) }

  context 'without any properties configured' do
    it 'configures the errand with default values' do
      expect(config.fetch('polling_interval')).to eq(60)
      expect(config.fetch('attempt_interval')).to eq(60)
      expect(config.fetch('attempt_limit')).to eq(5)
      expect(config.fetch('request_timeout')).to eq(120)
      expect(config.fetch('max_in_flight')).to eq(1)
      expect(config.fetch('canaries')).to eq(0)
    end

    it 'configures the broker api correctly' do
      expect(config.dig('broker_api', 'url')).to eq('http://123.456.789.101:8080')

      basic_auth_block = config.dig('broker_api', 'authentication', 'basic')
      expect(basic_auth_block.fetch('username')).to eq("%username'\"t:%!")
      expect(basic_auth_block.fetch('password')).to eq("%password'\"t:%!")

      expect(config.dig('broker_api', 'tls', 'ca_cert')).to eq ''
      expect(config.dig('broker_api', 'tls', 'disable_ssl_cert_verification')).to eq false
    end
  end

  context 'with every property configured' do
    let(:manifest_file) { File.open 'spec/fixtures/upgrade_all_fully_configured.yml' }

    it 'configures the errand accordingly' do
      expect(config.fetch('attempt_interval')).to eq(36)
      expect(config.fetch('polling_interval')).to eq(101)
      expect(config.fetch('attempt_limit')).to eq(42)
      expect(config.fetch('max_in_flight')).to eq(13)
      expect(config.fetch('request_timeout')).to eq(300)

      expect(config.fetch('canaries')).to eq(3)
      expect(config.fetch('canary_selection_params')).to eq(
        'test' => true,
        'size' => 'small'
      )
    end

    it 'configures the broker api correctly' do
      expect(config.dig('broker_api', 'url')).to eq('https://example.com')

      basic_auth_block = config.dig('broker_api', 'authentication', 'basic')
      expect(basic_auth_block.fetch('username')).to eq("%username'\"t:%!")
      expect(basic_auth_block.fetch('password')).to eq("%password'\"t:%!")

      expect(config.dig('broker_api', 'tls', 'ca_cert')).to eq 'a valid certificate'
      expect(config.dig('broker_api', 'tls', 'disable_ssl_cert_verification')).to eq true
    end

    describe 'attempt limit property' do
      let(:manifest_file) { File.open 'spec/fixtures/upgrade_all_invalid_attempt_limit.yml' }

      it 'fails when it is less or equal zero' do
        expect { rendered_template }.to raise_error(
          RuntimeError,
          'Invalid upgrade_all_service_instances.attempt_limit - must be greater or equal 1'
        )
      end
    end

    describe 'max_in_flight property' do
      let(:manifest_file) { File.open 'spec/fixtures/upgrade_all_invalid_max_in_flight.yml' }

      it 'fails when is less than 1' do
        expect do
          rendered_template
        end.to raise_error(RuntimeError, 'Invalid upgrade_all_service_instances.max_in_flight - must be greater or equal 1')
      end
    end

    describe 'canaries property' do
      let(:manifest_file) { File.open 'spec/fixtures/upgrade_all_invalid_canaries.yml' }

      it 'fails if its less than zero' do
        expect do
          rendered_template
        end.to raise_error(RuntimeError, 'Invalid upgrade_all_service_instances.canaries - must be greater or equal 0')
      end
    end
  end

  context 'broker tls is configured' do
    before(:each) do
      broker_link['broker']['properties']['tls']  = {
        'certificate': 'some certificate'
      }
    end

    it 'uses https for the fallback uri protocol' do
      expect(config.dig('broker_api', 'url')).to eq('https://123.456.789.101:8080')
    end
  end
end
