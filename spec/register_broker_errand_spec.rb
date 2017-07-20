# Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.
# This program and the accompanying materials are made available under the terms of the under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

require 'spec_helper'

RSpec.describe 'register-broker errand' do
  let(:access_value) {'enable'}
  let(:plans ) {
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
  }
  let(:renderer)  do
    merged_context = BoshEmulator.director_merge(YAML.load_file(manifest_file), 'register-broker')
    merged_context['links'] = {
      'broker' => {
        'instances' => [
          {
            'address' => "123.456.789.101",
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
    }

    Bosh::Template::Renderer.new(context: merged_context.to_json)
  end

  let(:rendered_template) { renderer.render('jobs/register-broker/templates/errand.sh.erb') }
  let(:manifest_file) { 'spec/fixtures/register_broker_with_special_characters.yml' }

  context 'when the cf credentials contain special characters' do
    it 'escapes the cf username and password' do
      expect(rendered_template).to include "cf auth '%cf_username'\\''\"t:%!' '%cf_password'\\''\"t:%!'"
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
      let(:access_value) {'disable'}

      it 'disables the access' do
        expect(rendered_template).to_not include 'cf enable-service-access'
        expect(rendered_template).to include 'cf disable-service-access'
      end
    end

    context 'and it has cf_service_access manual' do
      let(:access_value) {'manual'}

      it "doesn't change the access" do
        expect(rendered_template).to_not include 'cf enable-service-access'
        expect(rendered_template).to_not include 'cf disable-service-access'
      end
    end

    context 'and it does not specify cf_service_access' do
      let(:plans ) {
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
      }

      it 'enables service access by default' do
        expect(rendered_template).to include 'cf enable-service-access'
      end
    end

    context 'and it specifies an invalid value for cf_service_access' do
      let(:access_value) {'foo-bar'}
      it 'fails to template the errand' do
        expect {
          rendered_template
        }.to raise_error(RuntimeError, "Unsupported value foo-bar for cf_service_access. Choose from \"enable\", \"disable\", \"manual\"")
      end
    end
  end

  context "when there nil plans configured" do
    let(:plans ) {
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
    }

    it 'filters out nil plans' do
      expect(rendered_template.scan(/enable-service-access/).size).to eq(1), rendered_template
      expect(rendered_template).to include 'dedicated-vm-99'
      expect(rendered_template).to_not include 'disable-service-access'
    end
  end

  context "when there only nil plans configured" do
    let(:plans ) { [nil, nil] }

    it 'does not alter service access' do
      expect(rendered_template).to_not include 'service-access'
    end
  end

  context "when there no plans configured" do
    let(:plans ) { [] }

    it 'does not alter service access' do
      expect(rendered_template).to_not include 'service-access'
    end
  end

  context 'when there are multiple plans configured' do
    let(:plans) {
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
        },

      ]
    }

    it 'configures the service access accordingly' do
      expect(rendered_template).to include 'cf enable-service-access myservicename -p enable-plan'
      expect(rendered_template).to include 'cf enable-service-access myservicename -p unconfigured-plan'
      expect(rendered_template).to include 'cf disable-service-access myservicename -p disable-plan'
      expect(rendered_template).to_not include 'manual-plan'
    end
  end
end
