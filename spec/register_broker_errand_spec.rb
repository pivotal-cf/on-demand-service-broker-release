# frozen_string_literal: true

# Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.
# This program and the accompanying materials are made available under the terms of the under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

require 'spec_helper'

RSpec.describe 'register-broker errand' do
  let(:access_value) { 'enable' }
  let(:plans) do
    [
      {
        'name' => 'dedicated-vm',
        'plan_id' => 'some-plan-id',
        'description' => 'a lovely plan',
        'cf_service_access' => access_value,
        'instance_groups' => [
          'name' => 'my-service-server',
          'vm_type' => 'small',
          'instances' => 1,
          'networks' => []
        ]
      }
    ]
  end

  let(:cf_authentication) do {
    'user_credentials' => {
      'username' => 'my_username',
      'password' => 'some password'
      }
    }
  end

  let(:links) do
    [{
      'broker' => {
        'instances' => [
          {
            'address' => '123.456.789.101'
          }
        ],
        'properties' => {
          'username' => "%broker_username'\"t:%!",
          'password' => "%broker_password'\"t:%!",
          'port' => 8080,
          'cf' => {
            'root_ca_cert' => 'thats a certificate',
            'authentication' => cf_authentication,
            'url' => 'https://api.sys.cloud.foundry.org'
          },
          'service_catalog' => {
            'plans' => plans,
            'service_name' => 'myservicename'
          }
        }
      }
    }]
  end

  let(:renderer) do
    merged_context = BoshEmulator.director_merge(YAML.load_file(manifest_file), 'register-broker', links)
    Bosh::Template::Renderer.new(context: merged_context.to_json)
  end

  let(:rendered_template) { renderer.render('jobs/register-broker/templates/errand.sh.erb') }
  let(:manifest_file) { 'spec/fixtures/register_broker_with_special_characters.yml' }

  describe 'broker URI' do

    context 'when it is specified' do
      let(:manifest_file) { 'spec/fixtures/register_broker_with_broker_uri.yml' }

      it 'includes the given broker_uri in the register-broker call' do
        expect(rendered_template).to include "broker_uri=https://my.external.broker.address/"
      end
    end

    context 'when it is not specified' do

      context 'and broker uses plain HTTP' do
        it 'includes the IP address' do
          expect(rendered_template).to include "broker_uri=http://123.456.789.101:8080"
        end
      end

      context 'and broker uses TLS' do
        let(:links) do
          [{
            'broker' => {
              'instances' => [
                {
                  'address' => '123.456.789.101'
                }
              ],
              'properties' => {
                'username' => "%broker_username'\"t:%!",
                'password' => "%broker_password'\"t:%!",
                'port' => 8080,
                'cf' => {
                  'root_ca_cert' => 'thats a certificate',
                  'authentication' => cf_authentication,
                  'url' => 'https://api.sys.cloud.foundry.org'
                },
                'service_catalog' => {
                  'plans' => plans,
                  'service_name' => 'myservicename'
                },
                'tls' => {
                  'certificate': 'another fine certificate'
                }
              }
            }
          }]
        end

        it 'includes the IP address with an https protocol' do
          expect(rendered_template).to include "broker_uri=https://123.456.789.101:8080"
        end

      end
    end
  end

  describe 'when the cf block is missing' do
    let(:links) do
      [{
        'broker' => {
          'instances' => [
            {
              'address' => '123.456.789.101'
            }
          ],
          'properties' => {
            'username' => "%broker_username'\"t:%!",
            'password' => "%broker_password'\"t:%!",
            'port' => 8080,
            'service_catalog' => {
              'plans' => plans,
              'service_name' => 'myservicename'
            }
          }
        }
      }]
    end
    it 'fails with an error' do
      expect do
        rendered_template
      end.to raise_error(RuntimeError, 'register-broker expected the broker link to contain property "cf"')
    end
  end

  describe 'cf authentication' do
    context 'when the authentication block is missing' do
      let(:links) do
        [{
          'broker' => {
            'instances' => [
              {
                'address' => '123.456.789.101'
              }
            ],
            'properties' => {
              'username' => "%broker_username'\"t:%!",
              'password' => "%broker_password'\"t:%!",
              'port' => 8080,
              'cf' => {},
              'service_catalog' => {
                'plans' => plans,
                'service_name' => 'myservicename'
              }
            }
          }
        }]
      end
      it 'fails with an error' do
        expect do
          rendered_template
        end.to raise_error(RuntimeError, 'register-broker expected the broker link to contain property "cf.authentication"')
      end
    end

    context 'when only client credentials are provided' do
      let(:cf_authentication) do {
        'client_credentials' => {
          'client_id' => 'some_client',
          'secret' => 'some_password'
          }
        }
      end

      it 'uses client_credentials to authenticate' do
        expect(rendered_template).to include "cf_retry auth 'some_client' 'some_password' --client-credentials"
      end
    end

    context 'when only user credentials are provided' do
      let(:cf_authentication) do {
          'client_credentials' => {
            'client_id' => '',
            'secret' => ''
          },
          'user_credentials' => {
            'username' => 'my_username',
            'password' => 'some password'
          }
        }
      end
      it 'uses user_credentials to authenticate' do
        expect(rendered_template).to include "cf_retry auth 'my_username' 'some password'"
      end
    end

    context 'when both client and user credentials are provided' do
      let(:cf_authentication) do {
        'user_credentials' => {
          'username' => 'my_username',
          'password' => 'some password'
        },
        'client_credentials' => {
          'client_id' => 'some_client',
          'secret' => 'some_password'
          }
        }
      end

      it 'uses client_credentials to authenticate' do
        expect(rendered_template).to include "cf_retry auth 'some_client' 'some_password' --client-credentials"
        expect(rendered_template).not_to include "cf_retry auth 'my_username' 'some password'"
      end
    end

    context 'when the cf credentials contain special characters' do
      let(:cf_authentication) do {
        'user_credentials' => {
          'username' => "%cf_username'\"t:%!",
          'password' => "%cf_password'\"t:%!"
          }
        }
      end

      it 'escapes the cf username and password' do
        expect(rendered_template).to include "cf_retry auth '%cf_username'\\''\"t:%!' '%cf_password'\\''\"t:%!'"
      end
    end

    context 'when all credentials are blank' do
      let(:cf_authentication) do {
          'client_credentials' => {
            'client_id' => '',
            'secret' => ''
          },
          'user_credentials' => {
            'username' => '',
            'password' => ''
          }
        }
      end

      it 'fails with an error' do
        expect do
          rendered_template
        end.to raise_error(RuntimeError, 'register-broker expected either cf.client_credentials or cf.user_credentials to not be blank')
      end
    end

    context 'when all credentials are nil' do
      let(:cf_authentication) do {
          'client_credentials' => {
            'client_id' => nil,
            'secret' => nil
          },
          'user_credentials' => {
            'username' => nil,
            'password' => nil
          }
        }
      end

      it 'fails with an error' do
        expect do
          rendered_template
        end.to raise_error(RuntimeError, 'register-broker expected either cf.client_credentials or cf.user_credentials to not be blank')
      end
    end
  end

  describe 'using cf api url from the broker link' do

    context 'when cf.url is not set in broker link' do
      let(:links) do
        [{
          'broker' => {
            'instances' => [ { 'address' => '123.456.789.101' } ],
            'properties' => {
              'username' => "%broker_username'\"t:%!",
              'password' => "%broker_password'\"t:%!",
              'port' => 8080,
              'cf' => { 'authentication' => { 'client_credentials' => { 'client_id' => 'some_client', 'secret' => 'some_password' } } },
              'service_catalog' => { 'plans' => plans, 'service_name' => 'myservicename' }
            }
          }
        }]
      end

      it 'fails with an error' do
        expect do
          rendered_template
        end.to raise_error(RuntimeError, 'register-broker expected the broker link to contain property "cf.url"')
      end
    end

    context 'when cf.url is set in broker link' do
      it 'is used in the generated config' do
        expect(rendered_template).to include 'cf_retry api --skip-ssl-validation https://api.sys.cloud.foundry.org'
      end
    end

  end


  context 'when there is one plan configured' do
    context 'and it has cf_service_access manual' do
      let(:access_value) { 'manual' }

      it "doesn't change the access" do
        expect(rendered_template).to_not include 'cf enable-service-access'
        expect(rendered_template).to_not include 'cf disable-service-access'
      end
    end

    context 'and it specifies an invalid value for cf_service_access' do
      let(:access_value) { 'foo-bar' }
      it 'fails to template the errand' do
        expect do
          rendered_template
        end.to raise_error(RuntimeError, 'Unsupported value foo-bar for cf_service_access. Choose from "enable", "disable", "manual", "org-restricted"')
      end
    end
  end

  context 'when there are multiple plans configured' do
    let(:plans) do
      [
        {
          'name' => 'manual-plan',
          'plan_id' => 'manual-plan-id',
          'description' => 'a regular old plan',
          'cf_service_access' => 'manual',
          'instance_groups' => [
            'name' => 'my-service-server',
            'vm_type' => 'small',
            'instances' => 1,
            'networks' => []
          ]
        }
      ]
    end

    it 'configures the service access accordingly' do
      expect(rendered_template).to_not include 'manual-plan'
    end
  end

  describe 'ssl verification' do
    context 'when it is disabled' do
      it 'adds the skip-ssl-validation flag' do
        expect(rendered_template).to include 'cf_retry api --skip-ssl-validation'
      end
    end

    context 'when it is enabled' do
      context 'when cf link is present' do
        let(:manifest_file) { 'spec/fixtures/register_broker_with_ssl_enabled.yml' }
        it 'does not add the skip-ssl-validation flag' do
          expect(rendered_template).to_not include 'cf api --skip-ssl-validation'
        end

        it 'exports the ssl_cert_file env variable from the cf link' do
          expect(rendered_template).to include 'echo -e "thats a certificate" > "$cert_file"'
          expect(rendered_template).to include 'export SSL_CERT_FILE="$cert_file"'
          expect(rendered_template).to include 'cf_retry api https://api.sys.cloud.foundry.org'
        end
      end
    end
  end
end
