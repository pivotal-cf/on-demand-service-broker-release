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
        'instances' => [{
          'address' => '111.22.233.123'
        }],
        'properties' => {
          'username' => "foo",
          'password' => "bar",
          'port' => '3333',
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
          },
          'service_catalog' => {
            'id' => 'service-catalog-id',
            'plans' => [
              nil, {
                'name' => 'enabled-plan',
                'cf_service_access' => 'enable'
              }, {
                'name' => 'disabled-plan',
                'cf_service_access' => 'disable'
              }, {
                'name' => 'org-restricted-plan',
                'cf_service_access' => 'org-restricted',
                'service_access_org' => 'some-org'
              }, {
                'name' => 'manual-plan',
                'cf_service_access' => 'manual'
              }, {
                'name' => 'other-plan'
              }]
          }
        }
      }
    }
  end

  let(:config) {YAML.safe_load(rendered_template)}

  let(:manifest_file) {File.open 'spec/fixtures/register_broker_with_broker_uri.yml'}

  it 'includes CF configuration' do
    expect(config.dig('cf', 'url')).to eq('https://api.cf-app.com')
    expect(config.dig('cf', 'root_ca_cert')).to eq('cert')
    expect(config.dig('cf', 'uaa', 'url')).to eq('https://uaa.cf-app.com')
    expect(config.dig('cf', 'uaa', 'authentication', 'client_credentials', 'client_id')).to eq('some_client_id')
    expect(config.dig('cf', 'uaa', 'authentication', 'client_credentials', 'client_secret')).to eq('some_secret')
    expect(config.dig('cf', 'uaa', 'authentication', 'user_credentials', 'username')).to eq('some-username')
    expect(config.dig('cf', 'uaa', 'authentication', 'user_credentials', 'password')).to eq('some-password')
    expect(config.dig('cf', 'disable_ssl_cert_verification')).to be_truthy
  end

  it 'includes broker configuration' do
    expect(config.dig('broker_name')).to eq('broker-name')
    expect(config.dig('broker_username')).to eq('foo')
    expect(config.dig('broker_password')).to eq('bar')
    expect(config.dig('broker_url')).to eq('http://some-uri.something')
  end

  it 'includes plan details and service name' do
    expect(config.dig('service_offering_id')).to eq('service-catalog-id')
    expect(config.dig('plans')).to include({'name' => 'enabled-plan', 'cf_service_access' => 'enable', 'service_access_org' => nil})
    expect(config.dig('plans')).to include({'name' => 'disabled-plan', 'cf_service_access' => 'disable', 'service_access_org' => nil})
    expect(config.dig('plans')).to include({'name' => 'org-restricted-plan', 'cf_service_access' => 'org-restricted', 'service_access_org' => 'some-org'})
  end

  it 'does not include plans with service_access set to manual' do
    manual_plan = config.dig('plans').filter {|p| p['name'] == 'manual-plan'}
    expect(manual_plan).to be_empty
  end

  it 'sets "cf_service_access" for a plan to "enable" if the plan is not configured with "cf_service_access"' do
    expect(config.dig('plans')).to include({'name' => 'other-plan', 'cf_service_access' => 'enable', 'service_access_org' => nil})
  end

  it 'does not include "nil" plans' do
    expect(config.dig('plans').size).to eq(4)
  end

  it 'fails when "service_access_org" is set but "cf_service_access" is not "org-restricted"' do
    broker_link['broker']['properties']['service_catalog']['plans'] = [{
      'name' => 'a-plan',
      'cf_service_access' => 'enable',
      'service_access_org' => 'cabana'
    }]

    expect {config}.to raise_error('Unexpected "service_access_org" for plan "a-plan". "service_access_org" is only valid for org-restricted plans.')
  end

  it 'fails when "cf_service_access" is set to "org-restricted" and a "service_access_org" is not set' do
    broker_link['broker']['properties']['service_catalog']['plans'] = [{
      'name' => 'a-plan',
      'cf_service_access' => 'org-restricted',
    }]

    expect {config}.to raise_error('Unexpected "service_access_org" for plan "a-plan". "service_access_org" must be set for org-restricted plans.')
  end

  it 'fails when "cf_service_access" is not valid' do
    broker_link['broker']['properties']['service_catalog']['plans'] = [{
      'name' => 'a-plan',
      'cf_service_access' => 'invalid',
    }]

    expect {config}.to raise_error('Unexpected "cf_service_access: invalid" for plan "a-plan". "cf_service_access" must be one of: enable, disable, org-restricted, manual.')
  end

  context '"broker_uri is not configured"' do
    let(:manifest_file) {File.open 'spec/fixtures/register_broker_minimal.yml'}

    it 'uses the broker ip if "broker_uri" is not configured' do
      expect(config.dig('broker_url')).to eq('http://111.22.233.123:3333')
    end

    it 'uses "https" when the broker certificate is present' do
      broker_link['broker']['properties']['tls'] = {'certificate' => "some-cert"}

      expect(config.dig('broker_url')).to eq('https://111.22.233.123:3333')
    end
  end
end
