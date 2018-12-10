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


  context 'when the broker credentials contain special characters' do
    it 'escapes the broker credentials' do
      expect(rendered_template).to include "cf $broker_cmd $broker_name '%broker_username'\\''\"t:%!' '%broker_password'\\''\"t:%!'"
    end
  end

  context 'when there is one plan configured' do
    context 'and it has cf_service_access enabled' do
      it 'enables the access' do
        expect(rendered_template).to include 'cf enable-service-access'
      end
    end

    context 'and it has cf_service_access disabled' do
      let(:access_value) { 'disable' }

      it 'disables the access' do
        expect(rendered_template).to_not include 'cf enable-service-access'
        expect(rendered_template).to include 'cf disable-service-access'
      end
    end

    context 'and it has cf_service_access manual' do
      let(:access_value) { 'manual' }

      it "doesn't change the access" do
        expect(rendered_template).to_not include 'cf enable-service-access'
        expect(rendered_template).to_not include 'cf disable-service-access'
      end
    end

    context 'and it has cf_service_access org-restricted' do
      let(:access_value) { 'org-restricted' }

      it "change the access for default access org" do
        expect(rendered_template).to include 'cf enable-service-access myservicename -o \'cf_org\''
        expect(rendered_template).to_not include 'cf disable-service-access'
      end
    end


    context 'and it does not specify cf_service_access' do
      let(:plans) do
        [
          {
            'name' => 'dedicated-vm',
            'plan_id' => 'some-plan-id',
            'description' => 'a lovely plan',
            'instance_groups' => [
              'name' => 'my-service-server',
              'vm_type' => 'small',
              'instances' => 1,
              'networks' => []
            ]
          }
        ]
      end

      it 'enables service access by default' do
        expect(rendered_template).to include 'cf enable-service-access'
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

  context 'when there nil plans configured' do
    let(:plans) do
      [
        nil,
        {
          'name' => 'dedicated-vm-99',
          'plan_id' => 'some-plan-id',
          'description' => 'a lovely plan',
          'instance_groups' => [
            'name' => 'my-service-server',
            'vm_type' => 'small',
            'instances' => 1,
            'networks' => []
          ]
        },
        nil
      ]
    end

    it 'filters out nil plans' do
      expect(rendered_template.scan(/enable-service-access/).size).to eq(1), rendered_template
      expect(rendered_template).to include 'dedicated-vm-99'
      expect(rendered_template).to_not include 'disable-service-access'
    end
  end

  context 'when there only nil plans configured' do
    let(:plans) { [nil, nil] }

    it 'does not alter service access' do
      expect(rendered_template).to_not include 'service-access'
    end
  end

  context 'when there no plans configured' do
    let(:plans) { [] }

    it 'does not alter service access' do
      expect(rendered_template).to_not include 'service-access'
    end
  end

  context 'when there are multiple plans configured' do
    let(:plans) do
      [
        {
          'name' => 'enable-plan',
          'plan_id' => 'some-plan-id',
          'description' => 'a lovely plan',
          'cf_service_access' => 'enable',
          'instance_groups' => [
            'name' => 'my-service-server',
            'vm_type' => 'small',
            'instances' => 1,
            'networks' => []
          ]
        },
        {
          'name' => 'unconfigured-plan',
          'plan_id' => 'some-plan-id',
          'description' => 'a lovely plan',
          'instance_groups' => [
            'name' => 'my-service-server',
            'vm_type' => 'small',
            'instances' => 1,
            'networks' => []
          ]
        },
        {
          'name' => 'disable-plan',
          'plan_id' => 'disable-access-id',
          'description' => 'a disabled access plan',
          'cf_service_access' => 'disable',
          'instance_groups' => [
            'name' => 'my-service-server',
            'vm_type' => 'small',
            'instances' => 1,
            'networks' => []
          ]
        },
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
      expect(rendered_template).to include 'cf enable-service-access myservicename -p enable-plan'
      expect(rendered_template).to include 'cf enable-service-access myservicename -p unconfigured-plan'
      expect(rendered_template).to include 'cf disable-service-access myservicename -p disable-plan'
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
          expect(rendered_template).to include 'cf_retry api a-cf-url'
        end
      end
    end
  end
end
