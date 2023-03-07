# frozen_string_literal: true

# Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.  This
# program and the accompanying materials are made available under the terms of
# the under the Apache License, Version 2.0 (the "License"); you may not use
# this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

require 'spec_helper'
require 'tempfile'

RSpec.describe 'broker config templating' do
  let(:brokerProperties) {
    YAML
      .load_file('spec/fixtures/valid-mandatory-broker-config.yml')
      .fetch('instance_groups')
      .first
      .fetch('jobs')
      .first
      .fetch('properties')
  }

  let(:links) { [] }
  let(:renderer) do
    Bosh::Template::Renderer.new(context: BoshEmulator.director_merge(
      YAML.load_file(manifest_file.path), 'broker', links
    ).to_json)
  end

  let(:rendered_template) { renderer.render('jobs/broker/templates/broker.yml.erb') }
  let(:manifest_file) { nil }

  after do
    manifest_file.close unless manifest_file.nil?
  end

  before(:all) do
    release_path = File.join(File.dirname(__FILE__), '..')
    release = Bosh::Template::Test::ReleaseDir.new(release_path)
    job = release.job('broker')
    @template = job.template('config/broker.yml')
  end

  describe 'successful templating' do
    context 'basic auth for BOSH' do
      let(:manifest_file) { File.open 'spec/fixtures/valid-mandatory-broker-config.yml' }

      it 'succeeds' do
        config = YAML.safe_load(rendered_template)
        expected = {
          'url' => 'some-url',
          'root_ca_cert' => nil,
          'authentication' => {
            'basic' => {
              'username' => 'some-username',
              'password' => 'some-password'
            },
            'uaa' => {
              'client_credentials' => {
                'client_id' => nil,
                'client_secret' => nil
              }
            }
          }
        }
        expect(config.fetch('bosh')).to eq(expected)
      end
    end

    context 'UAA configuration for BOSH' do
      let(:manifest_file) { File.open 'spec/fixtures/valid-bosh-uaa.yml' }

      it 'succeeds' do
        config = YAML.safe_load(rendered_template)
        expected = {
          'url' => 'some-url',
          'root_ca_cert' => nil,
          'authentication' => {
            'basic' => {
              'username' => nil,
              'password' => nil
            },
            'uaa' => {
              'client_credentials' => {
                'client_id' => 'id',
                'client_secret' => 'secret'
              }
            }
          }
        }
        expect(config.fetch('bosh')).to eq(expected)
      end
    end
  end

  describe 'TLS configuration' do
    context 'when a server cert and key are provided' do
      let(:manifest_file) { File.open 'spec/fixtures/valid_TLS_enabled.yml' }
      it 'adds the cert locations to the broker config' do
        config = YAML.safe_load(rendered_template)
        expected = {
          'cert_file' => '/var/vcap/jobs/broker/certs/broker.crt',
          'key_file' => '/var/vcap/jobs/broker/certs/broker.key'
        }
        expect(config['broker'].fetch('tls')).to eq(expected)
      end
    end

    context 'when tls is not configured' do
      let(:manifest_file) { File.open 'spec/fixtures/valid-mandatory-broker-config.yml' }
      it 'does not add any tls config to the broker config' do
        config = YAML.safe_load(rendered_template)
        expect(config['broker']).not_to include('tls')
      end
    end

    context 'when tls config has the certificate but is missing the private key' do
      let(:manifest_file) { File.open 'spec/fixtures/TLS-only-certificate-broker-config.yml' }
      it 'throws an error' do
        expect do
          rendered_template
        end.to raise_error(RuntimeError, 'Invalid TLS config - missing tls.private_key')
      end
    end

    context 'when tls config has the private key but is missing the certificate' do
      let(:manifest_file) { File.open 'spec/fixtures/TLS-only-private-key-broker-config.yml' }
      it 'throws an error' do
        expect do
          rendered_template
        end.to raise_error(RuntimeError, 'Invalid TLS config - missing tls.certificate')
      end
    end
  end

  describe 'bosh authentication configuration' do
    context 'when there is no authentication configured' do
      let(:manifest_file) { File.open 'spec/fixtures/invalid-missing-bosh-auth.yml' }

      it 'templating raises an error' do
        expect do
          rendered_template
        end.to raise_error(RuntimeError, 'Invalid bosh config - must specify authentication')
      end
    end

    context 'when both authentication types are configured' do
      let(:manifest_file) { File.open 'spec/fixtures/invalid-both-bosh-auth.yml' }

      it 'templating raises an error' do
        expect do
          rendered_template
        end.to raise_error(RuntimeError, 'Invalid bosh config - must only specify one type of authentication')
      end
    end
  end

  describe 'secure bindings' do
    context 'enabled but missing client ID' do
      let(:manifest_file) { File.open 'spec/fixtures/invalid_credhub_missing_uaa_client_id.yml' }

      it 'templating raises an error' do
        expect do
          rendered_template
        end.to raise_error(RuntimeError, 'Invalid secure_binding_credentials config - must specify client_id')
      end
    end

    context 'enabled but is missing client secret' do
      let(:manifest_file) { File.open 'spec/fixtures/invalid_credhub_missing_uaa_client_secret.yml' }

      it 'templating raises an error' do
        expect do
          rendered_template
        end.to raise_error(RuntimeError, 'Invalid secure_binding_credentials config - must specify client_secret')
      end
    end

    describe 'credhub link' do
      let(:manifest_file) { File.open 'spec/fixtures/valid_credhub.yml' }

      context 'when secure_binding_credentials is enabled but there is no credhub link' do
        it 'templating raises an error' do
          expect do
            rendered_template
          end.to raise_error(RuntimeError, 'secure_binding_credentials is enabled, but no CredHub link was provided')
        end
      end

      context 'when credhub link is provided' do
        let(:links) do
          [{
            'credhub' => {
              'instances' => [],
              'properties' => {
                'credhub' => {
                  'port' => 8844,
                  'ca_certificate' => 'credhub_ca_cert',
                  'internal_url' => 'my.credhub.internal'
                }
              }
            }
          }]
        end

        it 'includes the credhub properties' do
          expect(YAML.safe_load(rendered_template).fetch('credhub')).to eq(
            'api_url' => 'https://my.credhub.internal:8844',
            'ca_cert' => 'credhub_ca_cert',
            'client_id' => 'credhub_id',
            'client_secret' => 'credhub_password',
            'internal_uaa_ca_cert' => "--- INTERNAL UAA CA CERT ---\n"
          )
        end

        context 'but secure binding is disabled' do
          let(:manifest_file) { File.open 'spec/fixtures/valid_disabled_credhub.yml' }

          it 'does not include the credhub properties in the broker config' do
            expect(YAML.safe_load(rendered_template)).not_to have_key('credhub')
          end
        end

        context 'but the manifest does not contain secure binding properties' do
          let(:manifest_file) { File.open 'spec/fixtures/valid-mandatory-broker-config.yml' }

          it 'does not include the credhub properties in the broker config' do
            expect(YAML.safe_load(rendered_template)).not_to have_key('credhub')
          end
        end

        context 'and credhub.internal_url includes the protocol' do
          let(:links) do
            [{
              'credhub' => {
                'instances' => [],
                'properties' => {
                  'credhub' => {
                    'port' => 8844,
                    'ca_certificate' => 'credhub_ca_cert',
                    'internal_url' => 'https://my.credhub.internal'
                  }
                }
              }
            }]
          end

          it 'includes the correct credhub.api_url' do
            expect(YAML.safe_load(rendered_template).dig('credhub', 'api_url')).to eq(
              'https://my.credhub.internal:8844',
            )
          end
        end
      end

      context 'when credhub link is provided but set to empty' do
        let(:manifest_file) { File.open 'spec/fixtures/valid_credhub.yml' }
        let(:links) do
          [{
            'credhub' => {
              'instances' => [],
              'properties' => {
                'credhub' => {
                  'port' => '',
                  'ca_certificate' => '',
                  'internal_url' => ''
                }
              }
            }
          }]
        end

        it 'raises an error' do
          expect do
            rendered_template
          end.to raise_error(RuntimeError, 'Secure service binding is enabled but CredHub link is empty')
        end
      end
    end
  end

  describe 'enabling telemetry' do
    let(:rendered_template) {
      YAML.load(renderer.render(brokerProperties))
    }

    let(:renderer) {
      release_path = File.join(File.dirname(__FILE__), '..')
      release = Bosh::Template::Test::ReleaseDir.new(release_path)
      job = release.job('broker')
      job.template('config/broker.yml')
    }

    it 'defaults to false' do
      expect(rendered_template["broker"]["enable_telemetry"]).to eq(false)
    end

    context 'when it is configured to true' do
      before(:each) do
        brokerProperties["enable_telemetry"] = true
      end

      it 'passes the appropriate configuration' do
        expect(rendered_template["broker"]["enable_telemetry"]).to eq(true)
      end
    end
  end

  describe 'secure manifests' do
    context 'when the enable_secure_manifests flag is set to true' do
      let(:manifest_file) { File.open 'spec/fixtures/valid_resolve_bind_secrets.yml' }

      it 'includes the enable_secure_manifests flag as true in the config' do
        expect(rendered_template).to include 'enable_secure_manifests: true'
        yml = YAML.safe_load(rendered_template)
        expect(yml).to have_key 'bosh_credhub'
        expect(yml['bosh_credhub']).to include(
          'url' => 'https://bosh_credhub_url:8844/api/',
          'root_ca_cert' => 'CERT',
          'authentication' => {
            'uaa' => {
              'client_credentials' => {
                'client_id' => 'credhub_id',
                'client_secret' => 'credhub_password'
              }
            }
          }
        )
      end
    end

    context 'when the enable_secure_manifests flag is true, but use_stdin is false' do
      let(:manifest_file) { File.open 'spec/fixtures/invalid_secure_manifests_enabled_but_use_stdin_false.yml' }

      it 'fails with an error' do
        expect do
          rendered_template
        end.to raise_error(RuntimeError, 'enable_secure_manifests requires use_stdin to be enabled')
      end
    end

    context 'when the enable_secure_manifests flag is set to true but we do not have bosh_credhub config' do
      let(:manifest_file) { File.open 'spec/fixtures/invalid_resolve_bind_secrets.yml' }

      it 'fails with an error' do
        expect do
          rendered_template
        end.to raise_error(RuntimeError, 'enable_secure_manifests requires bosh_credhub_api to be configured, but bosh_credhub_api error: not configured')
      end
    end

    context 'bosh_credhub_api is missing keys' do
      let(:manifest_file) { File.open 'spec/fixtures/invalid_resolve_bind_secrets-missing_api_ca_cert.yml' }

      it 'fails with an error' do
        expect do
          rendered_template
        end.to raise_error(RuntimeError, 'enable_secure_manifests requires bosh_credhub_api to be configured, but bosh_credhub_api error: missing root_ca_cert')
      end
    end

    context 'bosh_credhub_api is missing authentication' do
      let(:manifest_file) { File.open 'spec/fixtures/invalid_resolve_bind_secrets_missing_authentication.yml' }

      it 'fails with an error' do
        expect do
          rendered_template
        end.to raise_error(RuntimeError, 'enable_secure_manifests requires bosh_credhub_api to be configured, but bosh_credhub_api error: missing authentication configuration')
      end
    end

    context 'bosh_credhub_api is missing deep keys' do
      let(:manifest_file) { File.open 'spec/fixtures/invalid_resolve_bind_secrets_missing_client_id.yml' }

      it 'fails with an error' do
        expect do
          rendered_template
        end.to raise_error(RuntimeError, 'enable_secure_manifests requires bosh_credhub_api to be configured, but bosh_credhub_api error: missing authentication.uaa.client_credentials.client_id')
      end
    end
  end

  describe 'service catalog' do
    context 'when the manifest contains only mandatory service catalog properties' do
      let(:manifest_file) { File.open 'spec/fixtures/valid-mandatory-broker-config.yml' }

      it 'sets the value of disable_ssl_cert_verification to false' do
        expect(rendered_template).to include 'disable_ssl_cert_verification: false'
      end
    end

    context 'when the manifest is missing mandatory service catalog property' do
      %w[id service_name service_description bindable plan_updatable].each do |missing_field|
        context "when #{missing_field} is absent" do
          let(:manifest_file) do
            generate_test_manifest do |yaml|
              yaml['instance_groups'][0]['jobs'][0]['properties']['service_catalog'].delete(missing_field)
            end
          end

          it 'templating raises an error' do
            expect do
              rendered_template
            end.to raise_error(RuntimeError, "Invalid service_catalog config - must specify #{missing_field}")
          end
        end

        context "when #{missing_field} is empty string" do
          let(:manifest_file) do
            generate_test_manifest do |yaml|
              yaml['instance_groups'][0]['jobs'][0]['properties']['service_catalog'][missing_field] = ''
            end
          end

          it 'templating raises an error' do
            expect do
              rendered_template
            end.to raise_error(RuntimeError, "Invalid service_catalog config - must specify #{missing_field}")
          end
        end
      end
    end

    context 'when the manifest contains optional service catalog properties' do
      let(:manifest_file) { File.open 'spec/fixtures/valid-optional-broker-config.yml' }

      context 'and startup banner is configured' do
        it 'templates without error' do
          rendered_template
          expect(rendered_template).to include('startup_banner: true')
        end
      end

      context 'and service_instance_limit is set' do
        it 'templates without error' do
          rendered_template
          expect(rendered_template).to include('service_instance_limit: 42')
        end
      end
    end

    context 'when the manifest specifies a value for metadata.shareable' do
      let(:manifest_file) { File.open 'spec/fixtures/valid-shareable-config.yml' }

      it 'sets the value correctly' do
        expect(rendered_template).to include 'shareable: true'
      end
    end

    context 'when the manifest has arbitrary service metadata' do
      let(:manifest_file) { File.open 'spec/fixtures/valid-service-metadata.yml' }

      it 'sets the value correctly' do
        expect(rendered_template).to include 'yolo: false'
      end
    end
  end

  describe 'service plans validation' do
    context 'when the manifest has no plans property' do
      let(:manifest_file) do
        generate_test_manifest do |yaml|
          yaml['instance_groups'][0]['jobs'][0]['properties']['service_catalog'].delete('plans')
        end
      end

      it 'templating raises an error' do
        expect do
          rendered_template
        end.to raise_error(RuntimeError, 'Invalid service_catalog config - must specify plans')
      end
    end

    context 'when the manifest has 0 plans' do
      let(:manifest_file) do
        generate_test_manifest do |yaml|
          yaml['instance_groups'][0]['jobs'][0]['properties']['service_catalog']['plans'] = []
        end
      end

      it 'templating raises an error' do
        expect do
          rendered_template
        end.to raise_error(RuntimeError, 'Invalid service_catalog config - must specify plans')
      end
    end

    context 'when the manifest only has nil plans' do
      let(:manifest_file) do
        generate_test_manifest do |yaml|
          yaml['instance_groups'][0]['jobs'][0]['properties']['service_catalog']['plans'] = [nil, nil]
        end
      end

      it 'templating raises an error' do
        expect do
          rendered_template
        end.to raise_error(RuntimeError, 'Invalid service_catalog config - must specify plans')
      end
    end

    context 'when the manifest also has nil plans' do
      let(:manifest_file) do
        generate_test_manifest do |yaml|
          plan = yaml['instance_groups'][0]['jobs'][0]['properties']['service_catalog']['plans'][0]
          yaml['instance_groups'][0]['jobs'][0]['properties']['service_catalog']['plans'] = [nil, plan, nil]
        end
      end

      it 'filters out nil plans' do
        config = YAML.safe_load(rendered_template)
        expect(config.fetch('service_catalog').fetch('plans').length).to eq(1)
        expect(config.fetch('service_catalog').fetch('plans')[0].fetch('name')).to eq('dedicated-vm')
      end
    end

    context 'when the manifest is missing mandatory plan fields' do
      %w[name plan_id description instance_groups].each do |missing_field|
        context ": #{missing_field}" do
          let(:manifest_file) do
            generate_test_manifest do |yaml|
              yaml['instance_groups'][0]['jobs'][0]['properties']['service_catalog']['plans'].first.delete(missing_field)
            end
          end

          it 'templating raises an error' do
            expect do
              rendered_template
            end.to raise_error(RuntimeError, "Invalid plan config - must specify #{missing_field}")
          end
        end
      end
    end

    context 'when the manifest has 0 instance groups for a plan' do
      let(:manifest_file) do
        generate_test_manifest do |yaml|
          yaml['instance_groups'][0]['jobs'][0]['properties']['service_catalog']['plans'].first['instance_groups'] = []
        end
      end

      it 'templating raises an error' do
        expect do
          rendered_template
        end.to raise_error(RuntimeError, 'Invalid plan config - must specify instance_groups')
      end
    end
  end

  context 'when the manifest specifies a value for disable_ssl_cert_verification' do
    let(:manifest_file) { File.open 'spec/fixtures/valid-broker-config-ignoring-ssl-certs.yml' }

    it 'sets the value of disable_ssl_cert_verification to true' do
      expect(rendered_template).to include 'disable_ssl_cert_verification: true'
    end
  end

  context 'when the manifest specifies true for disable_bosh_configs' do
    let(:manifest_file) { File.open 'spec/fixtures/valid-broker-config-ignoring-bosh-configs.yml' }

    it 'sets the value of disable_bosh_configs to true' do
      expect(rendered_template).to include 'disable_bosh_configs: true'
    end
  end

  context 'when the manifest is missing mandatory instance group fields' do
    %w[name vm_type instances networks azs].each do |missing_field|
      context ": #{missing_field}" do
        let(:manifest_file) do
          generate_test_manifest do |yaml|
            yaml['instance_groups'][0]['jobs'][0]['properties']['service_catalog']['plans'].first['instance_groups'].first.delete(missing_field)
          end
        end

        it 'templating raises an error' do
          expect do
            rendered_template
          end.to raise_error(RuntimeError, "Invalid instance group config - must specify #{missing_field}")
        end
      end
    end
  end

  describe 'networks and azs' do
    %w[networks azs].each do |missing_field|
      context "when '#{missing_field}' is an empty array" do
        let(:manifest_file) do
          generate_test_manifest do |yaml|
            yaml['instance_groups'][0]['jobs'][0]['properties']['service_catalog']['plans'].first['instance_groups'].first[missing_field] = []
            yaml
          end
        end

        it 'templating raises an error' do
          expect do
            rendered_template
          end.to raise_error(RuntimeError, "Invalid instance group config - must specify #{missing_field}")
        end
      end
    end
  end

  describe 'quotas' do
    describe 'quotas when cf is not configured - i.e. cf startup checks disabled' do
      context 'when global service instance limit quota is set' do
        let(:manifest_file) { File.open 'spec/fixtures/quotas_no_cf_global_instances.yml' }

        it 'templating raises an error when a global instance limit is set' do
          expect do
            rendered_template
          end.to raise_error(RuntimeError, 'Invalid quota configuration - global service instance limit requires CF to be configured')
        end
      end

      context 'when a plan service instance limit quota is set' do
        let(:manifest_file) { File.open 'spec/fixtures/quotas_no_cf_plan_instances.yml' }

        it 'templating raises an error when a plan instance limit is set' do
          expect do
            rendered_template
          end.to raise_error(RuntimeError, 'Invalid quota configuration - plan service instance limit requires CF to be configured')
        end
      end

      context 'when global resource limits are set' do
        let (:manifest_file) { File.open 'spec/fixtures/quotas_no_cf_global_resource_limits.yml' }

        it 'templating raises an error when a global resource limit is set' do
          expect do
            rendered_template
          end.to raise_error(RuntimeError, 'Invalid quota configuration - global resource limits require CF to be configured')
        end
      end

      context 'when global resource limits are set with the deprated format' do
        let (:manifest_file) { File.open 'spec/fixtures/quotas_no_cf_global_resource_limits_deprecated_format.yml' }

        it 'templating raises an error when a global resource limit is set' do
          expect do
            rendered_template
          end.to raise_error(RuntimeError, 'Invalid quota configuration - global resource limits require CF to be configured')
        end
      end

      context 'when plan resource limits are set' do
        let (:manifest_file) { File.open 'spec/fixtures/quotas_no_cf_plan_resource_limits.yml' }

        it 'templating raises an error when a global resource limit is set' do
          expect do
            rendered_template
          end.to raise_error(RuntimeError, 'Invalid quota configuration - plan resource limit requires CF to be configured')
        end
      end

      context 'when plan resource limits are set with the deprecated format' do
        let (:manifest_file) { File.open 'spec/fixtures/quotas_no_cf_plan_resource_limits_deprecated_format.yml' }

        it 'templating raises an error when a global resource limit is set' do
          expect do
            rendered_template
          end.to raise_error(RuntimeError, 'Invalid quota configuration - plan resource limit requires CF to be configured')
        end
      end

      context 'when global resource limit block is present but no values are present' do
        let (:manifest_file) { File.open 'spec/fixtures/quotas_no_cf_global_resource_limits_no_values.yml' }

        it 'succeeds' do
          expect do
            rendered_template
          end.not_to raise_error
        end
      end
    end

    describe 'when quotas are configured with the deprecated format' do
      let (:manifest_file) {File.open 'spec/fixtures/quotas_deprecated_format.yml'}

      it 'is adapted to the new format for global quotas' do
        expectedQuotas = {
          'ips' => {
            'limit' => 10,
          },
          'nutella_jars' => {
            'limit' => 6,
          }
        }
        actualQuotas = YAML.safe_load(rendered_template).dig('service_catalog', 'global_quotas')
        expect(actualQuotas).to_not include("resource_limits")
        expect(actualQuotas["resources"]).to eq(expectedQuotas)
      end

      it 'is adapted to the new format for plan quotas' do
        expectedQuotas = {
          'ips' => {
            'limit' => 8,
            'cost' => 4,
          },
          'nutella_jars' => {
            'limit' => 6,
            'cost' => 2,
          }
        }
        plan = YAML.safe_load(rendered_template).dig('service_catalog', 'plans')[0]
        expect(plan).to_not include("resource_costs")

        actualQuotas = plan.dig('quotas')
        expect(actualQuotas["resources"]).to eq(expectedQuotas)
        expect(actualQuotas).to_not include("resource_limits")
      end
    end
  end

  describe 'cf uaa' do
    let(:cf_config) do
      {
        'url' => 'cf-url',
        'root_ca_cert' => 'a-cert',
        'uaa' => {
          'url' => 'cf-uaa-url',
          'authentication' => {
            'client_credentials' => {
              'client_id' => 'id',
              'client_secret' => 'secret'
            }
          }
        }
      }
    end

    let(:manifest_file) do
      generate_test_manifest do |m|
        properties = m['instance_groups'][0]['jobs'][0]['properties']
        properties['cf'] = cf_config
      end
    end

    context 'when client creds are configured' do
      it 'succeeds' do
        config = YAML.safe_load(rendered_template)
        expected = {
          'url' => 'cf-url',
          'root_ca_cert' => 'a-cert',
          'uaa' => {
            'url' => 'cf-uaa-url',
            'authentication' => {
              'client_credentials' => {
                'client_id' => 'id',
                'client_secret' => 'secret'
              },
              'user_credentials' => {
                'username' => nil,
                'password' => nil
              }
            }
          }
        }
        expect(config.fetch('cf')).to eq(expected)
      end
    end

    context 'when user creds are configured' do
      before do
        cf_config['uaa']['authentication'] = {
          'user_credentials' => {
            'username' => 'foo',
            'password' => 'bar'
          }
        }
      end

      it 'succeeds' do
        config = YAML.safe_load(rendered_template)
        expected = {
          'url' => 'cf-url',
          'root_ca_cert' => 'a-cert',
          'uaa' => {
            'url' => 'cf-uaa-url',
            'authentication' => {
              'client_credentials' => { 'client_id' => nil, 'client_secret' => nil },
              'user_credentials' => { 'username' => 'foo', 'password' => 'bar' }
            }
          }
        }
        expect(config.fetch('cf')).to eq(expected)
      end
    end

    context 'when client_definition is provided' do
      let(:client_definition) {
        {
          'scopes' => 'scope1',
          'resource_ids' => 'some-resource-id',
          'authorized_grant_types' => 'some-authorization',
          'authorities' => 'some-authority,another-authority',
          'name' => 'some-name',
          'allowpublic' => true,
        }
      }

      before do
        cf_config['uaa']['client_definition'] = client_definition
      end

      it 'makes to the generated config' do
        config = YAML.safe_load(rendered_template)
        expect(config.dig('cf', 'uaa', 'client_definition')).to eq(client_definition)
      end

      context 'but invalid properties are set' do
        let(:client_definition) {
          {
            'scope' => 'scope1',
            'resource_ids' => 'some-resource-id',
            'authorized_grant_types' => 'some-authorization',
            'authorities' => 'some-authority,another-authority',
            'client_secret' => 'not supported'
          }
        }

        it 'raises an error' do
          expect do
            rendered_template
          end.to raise_error(RuntimeError, 'Invalid client_definition config - valid properties are: scopes, authorities, authorized_grant_types, resource_ids, allowpublic, name')
        end
      end

      context 'but uaa is configured with user credentials' do
        before do
          cf_config['uaa']['authentication'] = { 'user_credentials' => {
            'username' => 'foo',
            'password' => 'bar'
          }}
        end

        it 'raises an error' do
          expect do
            rendered_template
          end.to raise_error(RuntimeError, 'Invalid uaa config: client_definition is set, but uaa client_credentials is not')
        end
      end
    end

    context 'when both user and client credentials are configured' do
      before do
        cf_config['uaa']['authentication']['user_credentials'] = {
          'username' => 'foo',
          'password' => 'bar'
        }
      end

      it 'templating raises an error' do
        expect do
          rendered_template
        end.to raise_error(RuntimeError, 'Invalid CF authentication config - must specify either client or user credentials')
      end
    end

    context 'deprecated configuration' do
      context 'when both user and client credentials are provided' do
        let(:manifest_file) { File.open 'spec/fixtures/invalid_has_both_client_and_user_cf_auth.yml' }

        it 'templating raises an error' do
          expect do
            rendered_template
          end.to raise_error(RuntimeError, 'Invalid CF authentication config - must specify either client or user credentials')
        end
      end

      context 'basic auth for CF' do
        let(:manifest_file) { File.open 'spec/fixtures/valid-deprecated-cf-basic-auth.yml' }

        it 'succeeds' do
          config = YAML.safe_load(rendered_template)
          expected = {
            'url' => 'cf-url',
            'root_ca_cert' => nil,
            'uaa' => {
              'url' => 'cf-uaa-url',
              'authentication' => {
                'client_credentials' => {
                  'client_id' => nil,
                  'client_secret' => nil
                },
                'user_credentials' => {
                  'username' => 'cf-user',
                  'password' => 'cf-pass'
                }
              }
            }
          }
          expect(config.fetch('cf')).to eq(expected)
        end
      end

      context 'UAA configuration for CF' do
        let(:manifest_file) {
          File.open 'spec/fixtures/valid-deprecated-cf-uaa.yml'
        }

        it 'succeeds' do
          config = YAML.safe_load(rendered_template)
          expected = {
            'url' => 'cf-url',
            'root_ca_cert' => nil,
            'uaa' => {
              'url' => 'cf-uaa-url',
              'authentication' => {
                'client_credentials' => {
                  'client_id' => 'id',
                  'client_secret' => 'secret'
                },
                'user_credentials' => {
                  'username' => nil,
                  'password' => nil
                }
              }
            }
          }
          expect(config.fetch('cf')).to eq(expected)
        end
      end
    end
  end

  describe 'broker credentials have special characters in them' do
    let(:manifest_file) { File.open 'spec/fixtures/valid-with-special-characters.yml' }

    it 'parses successfully' do
      expect { rendered_template }.to_not raise_error
    end

    it 'escapes the username' do
      expect(rendered_template).to include "username: '%username''\"t:%!'"
    end

    it 'escapes the password' do
      expect(rendered_template).to include "password: '%password''\"t:%!'"
    end
  end

  describe 'cf_service_access' do
    context 'when an invalid value is configured' do
      let(:manifest_file) do
        generate_test_manifest do |yaml|
          yaml['instance_groups'][0]['jobs'][0]['properties']['service_catalog']['plans'][0]['cf_service_access'] = 'invalid'
          yaml
        end
      end
      it 'raises an error' do
        expect { rendered_template }.to(
          raise_error(RuntimeError, "Unsupported value 'invalid' for cf_service_access. Choose from \"enable\", \"disable\", \"manual\", \"org-restricted\"")
        )
      end
    end

    context 'when a valid value is configured' do
      %w[enable disable manual].each do |a|
        context " : #{a}" do
          let(:manifest_file) do
            generate_test_manifest do |yaml|
              yaml['instance_groups'][0]['jobs'][0]['properties']['service_catalog']['plans'][0]['cf_service_access'] = a
              yaml
            end
          end

          it 'parses successfully' do
            expect { rendered_template }.to_not raise_error
          end
        end
      end
    end
  end

  describe 'service_deployment' do
    context 'when no releases are configured' do
      let(:manifest_file) do
        generate_test_manifest do |yaml|
          yaml['instance_groups'][0]['jobs'][0]['properties']['service_deployment']['releases'] = nil
          yaml
        end
      end

      it 'raises an error' do
        expect { rendered_template }.to(
          raise_error(RuntimeError, 'Invalid service_deployment config - must specify releases')
        )
      end
    end

    context 'when releases are configured as an empty' do
      let(:manifest_file) do
        generate_test_manifest do |yaml|
          yaml['instance_groups'][0]['jobs'][0]['properties']['service_deployment']['releases'] = []
          yaml
        end
      end

      it 'raises an error' do
        expect { rendered_template }.to(
          raise_error(RuntimeError, 'Invalid service_deployment config - must specify at least one release')
        )
      end
    end

    context 'when a release is missing required fields' do
      %w[name version jobs].each do |required_field|
        context ": #{required_field}" do
          let(:manifest_file) do
            generate_test_manifest do |yaml|
              yaml['instance_groups'][0]['jobs'][0]['properties']['service_deployment']['releases'].first.delete(required_field)
              yaml
            end
          end

          it 'raises an error' do
            expect { rendered_template }.to(
              raise_error(RuntimeError, "Invalid service_deployment.releases config - must specify #{required_field}")
            )
          end
        end
      end
    end

    context 'with multiple releases' do
      let(:second_release) { { 'name' => 'second-release', 'version' => 4567, 'jobs' => ['second-job'] } }

      context 'and all relesaes are configured correctly' do
        let(:manifest_file) do
          generate_test_manifest do |yaml|
            yaml['instance_groups'][0]['jobs'][0]['properties']['service_deployment']['releases'][1] =
              second_release
            yaml
          end
        end

        it 'does not raise an error' do
          expect { rendered_template }.to_not(raise_error)
        end
      end

      context 'and the second is missing required fields' do
        %w[name version jobs].each do |required_field|
          context ": #{required_field}" do
            let(:manifest_file) do
              generate_test_manifest do |yaml|
                second_release.delete(required_field)
                yaml['instance_groups'][0]['jobs'][0]['properties']['service_deployment']['releases'][1] =
                  second_release
                yaml
              end
            end

            it 'raises an error' do
              expect { rendered_template }.to(
                raise_error(RuntimeError, "Invalid service_deployment.releases config - must specify #{required_field}")
              )
            end
          end
        end
      end
    end

    describe '"stemcells" property' do
      let(:manifest_file) { File.open 'spec/fixtures/valid-mandatory-broker-config.yml' }

      it "is included in the configuration" do
        obj = YAML.load(rendered_template)
        expect(obj['service_deployment']['stemcells']).to eq([{"os"=>"ubuntu-trusty", "version"=>1234, "alias"=>"default"}])
      end

      context 'when "stemcell" is also configured' do
        let(:manifest_file) do
          generate_test_manifest do |yaml|
            yaml['instance_groups'][0]['jobs'][0]['properties']['service_deployment']['stemcell'] = {
              'os' => 'ubuntu-trusty','version' => 1234
            }
            yaml
          end
        end

        it 'raises an error' do
          expect { rendered_template }.to(
            raise_error(RuntimeError, 'You cannot configure both "stemcell" and "stemcells" in broker.service_deployment.')
          )
        end
      end

      context 'when one of the stemcells does not configure OS' do
        let(:manifest_file) do
          generate_test_manifest do |yaml|
            yaml['instance_groups'][0]['jobs'][0]['properties']['service_deployment']['stemcells'][0]['os'] = nil
            yaml
          end
        end

        it 'raises an error' do
          expect { rendered_template }.to(
            raise_error(RuntimeError, 'Invalid service_deployment stemcell config - must specify os')
          )
        end
      end

      context 'when one of the stemcells does not configure version' do
        let(:manifest_file) do
          generate_test_manifest do |yaml|
            yaml['instance_groups'][0]['jobs'][0]['properties']['service_deployment']['stemcells'][0]['version'] = nil
            yaml
          end
        end

        it 'raises an error' do
          expect { rendered_template }.to(
            raise_error(RuntimeError, 'Invalid service_deployment stemcell config - must specify version')
          )
        end
      end
    end

    context 'when neither "stemcell" nor "stemcells" is configured' do
      let(:manifest_file) do
        generate_test_manifest do |yaml|
          yaml['instance_groups'][0]['jobs'][0]['properties']['service_deployment']['stemcells'] = nil
          yaml
        end
      end

      it 'raises an error' do
        expect { rendered_template }.to(
          raise_error(RuntimeError, 'Invalid service_deployment config - at least one stemcell must be specified')
        )
      end
    end

    describe 'deprecated "stemcell" property' do
      let(:manifest_file) do
        generate_test_manifest do |yaml|
          yaml['instance_groups'][0]['jobs'][0]['properties']['service_deployment']['stemcells'] = []
          yaml['instance_groups'][0]['jobs'][0]['properties']['service_deployment']['stemcell'] = {
            'os' => 'ubuntu-trusty', 'version' => 2311
          }
          yaml
        end
      end


      it 'generates the config with "stemcells"' do
        obj = YAML.load(rendered_template)
        expect(obj['service_deployment']['stemcells']).to eq([{"os"=>"ubuntu-trusty", "version"=>2311}])
        expect(obj['service_deployment']['stemcell']).to be_nil
      end

      context 'when no stemcell os is configured' do
        let(:manifest_file) do
          generate_test_manifest do |yaml|
            yaml['instance_groups'][0]['jobs'][0]['properties']['service_deployment']['stemcells'] = []
            yaml['instance_groups'][0]['jobs'][0]['properties']['service_deployment']['stemcell'] = {
              'os' => nil, 'version' => 2311
            }
            yaml
          end
        end

        it 'raises an error' do
          expect { rendered_template }.to(
            raise_error(RuntimeError, 'Invalid service_deployment stemcell config - must specify os')
          )
        end
      end

      context 'when no stemcell version is configured' do
        let(:manifest_file) do
          generate_test_manifest do |yaml|
            yaml['instance_groups'][0]['jobs'][0]['properties']['service_deployment']['stemcells'] = []
            yaml['instance_groups'][0]['jobs'][0]['properties']['service_deployment']['stemcell'] = {
              'os' => 'ubuntu-xenial', 'version' => nil
            }
            yaml
          end
        end

        it 'raises an error' do
          expect { rendered_template }.to(
            raise_error(RuntimeError, 'Invalid service_deployment stemcell config - must specify version')
          )
        end
      end
    end

    context 'when a release version is latest' do
      let(:manifest_file) do
        generate_test_manifest do |yaml|
          yaml['instance_groups'][0]['jobs'][0]['properties']['service_deployment']['releases'][0]['version'] = 'latest'
          yaml
        end
      end

      it 'raises an error' do
        expect { rendered_template }.to(
          raise_error(RuntimeError, 'You must configure the exact release and stemcell versions in broker.service_deployment.' \
                      " ODB requires exact versions to detect pending changes as part of the 'cf update-service' workflow. For example, latest and 3112.latest are not supported.")
        )
      end
    end

    context 'when a release version is n.latest' do
      let(:manifest_file) do
        generate_test_manifest do |yaml|
          yaml['instance_groups'][0]['jobs'][0]['properties']['service_deployment']['releases'][0]['version'] = '22.latest'
          yaml
        end
      end

      it 'raises an error' do
        expect { rendered_template }.to(
          raise_error(RuntimeError, 'You must configure the exact release and stemcell versions in broker.service_deployment. ' \
                      "ODB requires exact versions to detect pending changes as part of the 'cf update-service' workflow. For example, latest and 3112.latest are not supported.")
        )
      end
    end

    context 'when a stemcell version is latest' do
      let(:manifest_file) do
        generate_test_manifest do |yaml|
          yaml['instance_groups'][0]['jobs'][0]['properties']['service_deployment']['stemcells'] = [{'version' => 'latest', 'os' => 'ubuntu-trusty'}]
          yaml
        end
      end

      it 'raises an error' do
        expect { rendered_template }.to(
          raise_error(RuntimeError, 'You must configure the exact release and stemcell versions in broker.service_deployment. ' \
                      "ODB requires exact versions to detect pending changes as part of the 'cf update-service' workflow. For example, latest and 3112.latest are not supported.")
        )
      end
    end

    context 'when a stemcell version is n.latest' do
      let(:manifest_file) do
        generate_test_manifest do |yaml|
          yaml['instance_groups'][0]['jobs'][0]['properties']['service_deployment']['stemcells'][0]['version'] = '22.latest'
          yaml
        end
      end

      it 'raises an error' do
        expect { rendered_template }.to(
          raise_error(RuntimeError, 'You must configure the exact release and stemcell versions in broker.service_deployment. ' \
                      "ODB requires exact versions to detect pending changes as part of the 'cf update-service' workflow. For example, latest and 3112.latest are not supported.")
        )
      end
    end

    context 'when use_stdin is set' do
      let(:manifest_file) do
        generate_test_manifest do |yaml|
          yaml['instance_groups'][0]['jobs'][0]['properties']['use_stdin'] = true
          yaml
        end
      end

      it 'is included in the configuration' do
        expect(rendered_template).to include 'use_stdin: true'
      end
    end

    context 'when use_stdin is not set' do
      let(:manifest_file) do
        generate_test_manifest do |yaml|
          yaml['instance_groups'][0]['jobs'][0]['properties'].delete('use_stdin')
          yaml
        end
      end

      it 'defaults to true' do
        expect(rendered_template).to include 'use_stdin: true'
      end
    end

    context 'when enable_plan_schemas is set' do
      let(:manifest_file) do
        generate_test_manifest do |yaml|
          yaml['instance_groups'][0]['jobs'][0]['properties']['enable_plan_schemas'] = true
          yaml
        end
      end

      it 'is included in the configuration' do
        expect(rendered_template).to include 'enable_plan_schemas: true'
      end
    end

    context 'when enable_plan_schemas is not set' do
      let(:manifest_file) do
        generate_test_manifest do |yaml|
          yaml['instance_groups'][0]['jobs'][0]['properties'].delete('enable_plan_schemas')
          yaml
        end
      end

      it 'defaults to false' do
        expect(rendered_template).to include 'enable_plan_schemas: false'
      end
    end

    context 'when pre-delete errand is specified' do
      let(:manifest_file) do
        generate_test_manifest do |yaml|
          yaml['instance_groups'][0]['jobs'][0]['properties']['service_catalog']['plans'][0]['lifecycle_errands'] = { 'pre_delete' => [{ 'name' => 'cleanup' }] }
        end
      end

      it 'is included in the configuration' do
        expect(rendered_template).to include '- name: cleanup'
      end

      context 'and disabled is set to true' do
        let(:manifest_file) do
          generate_test_manifest do |yaml|
            yaml['instance_groups'][0]['jobs'][0]['properties']['service_catalog']['plans'][0]['lifecycle_errands'] = {'pre_delete' => [{'name' => 'cleanup', 'disabled' => true}]}
          end
        end

        it 'is not included in the configuration' do
          expect(rendered_template).not_to include "- name: cleanup"
        end
      end

      context 'and disabled is set to false' do
        let(:manifest_file) do
          generate_test_manifest do |yaml|
            yaml['instance_groups'][0]['jobs'][0]['properties']['service_catalog']['plans'][0]['lifecycle_errands'] = {'pre_delete' => [{'name' => 'cleanup', 'disabled' => false}]}
          end
        end

        it 'is still included in the configuration' do
          expect(rendered_template).to include "- name: cleanup"
        end
      end

      context 'and disabled is set to non boolean' do
        let(:manifest_file) do
          generate_test_manifest do |yaml|
            yaml['instance_groups'][0]['jobs'][0]['properties']['service_catalog']['plans'][0]['lifecycle_errands'] = {'pre_delete' => [{'name' => 'cleanup', 'disabled' => 'foo'}]}
          end
        end

        it 'is still included in the configuration' do
          expect{rendered_template}.to raise_exception "Plan property lifecycle_errands.pre_delete.disabled must be boolean value."
        end
      end
    end

    context 'when pre-delete errand is in the wrong format' do
      let(:manifest_file) do
        generate_test_manifest do |yaml|
          yaml['instance_groups'][0]['jobs'][0]['properties']['service_catalog']['plans'][0]['lifecycle_errands'] = { 'pre_delete' => { 'name' => 'cleanup' } }
        end
      end

      it 'raises an error' do
        expect { rendered_template }.to(
          raise_error(RuntimeError, 'Plan property lifecycle_errands.pre_delete must be an array.')
        )
      end
    end

    context 'when post-deploy errand is specified' do
      let(:manifest_file) do
        generate_test_manifest do |yaml|
          yaml['instance_groups'][0]['jobs'][0]['properties']['service_catalog']['plans'][0]['lifecycle_errands'] = { 'post_deploy' => [{ 'name' => 'health-check' }] }
        end
      end

      it 'is included in the configuration' do
        expect(rendered_template).to include '- name: health-check'
      end

      context 'and disabled is set to true' do
        let(:manifest_file) do
          generate_test_manifest do |yaml|
            yaml['instance_groups'][0]['jobs'][0]['properties']['service_catalog']['plans'][0]['lifecycle_errands'] = {'post_deploy' => [{'name' => 'cleanup', 'disabled' => true}]}
          end
        end

        it 'is not included in the configuration' do
          expect(rendered_template).not_to include "- name: cleanup"
        end
      end

      context 'and disabled is set to false' do
        let(:manifest_file) do
          generate_test_manifest do |yaml|
            yaml['instance_groups'][0]['jobs'][0]['properties']['service_catalog']['plans'][0]['lifecycle_errands'] = {'post_deploy' => [{'name' => 'cleanup', 'disabled' => false}]}
          end
        end

        it 'is still included in the configuration' do
          expect(rendered_template).to include "- name: cleanup"
        end
      end

      context 'and disabled is set to non boolean' do
        let(:manifest_file) do
          generate_test_manifest do |yaml|
            yaml['instance_groups'][0]['jobs'][0]['properties']['service_catalog']['plans'][0]['lifecycle_errands'] = {'post_deploy' => [{'name' => 'cleanup', 'disabled' => 'foo'}]}
          end
        end

        it 'is still included in the configuration' do
          expect{rendered_template}.to raise_exception "Plan property lifecycle_errands.post_deploy.disabled must be boolean value."
        end
      end
    end

    context 'when post-deploy errand is in the wrong format' do
      let(:manifest_file) do
        generate_test_manifest do |yaml|
          yaml['instance_groups'][0]['jobs'][0]['properties']['service_catalog']['plans'][0]['lifecycle_errands'] = { 'post_deploy' => { 'name' => 'health-check' } }
        end
      end

      it 'raises an error' do
        expect { rendered_template }.to(
          raise_error(RuntimeError, 'Plan property lifecycle_errands.post_deploy must be an array.')
        )
      end
    end
  end

  describe 'binding with BOSH dns' do
    let(:manifest_file) { File.open 'spec/fixtures/valid_credhub.yml' }

    context 'with a list of valid BOSH dns link definitions' do
      it 'adds them to the config' do
        valid_dns_config = {
          'binding_with_dns' => [
            {
              'name' => 'my-link-name',
              'link_provider' => 'provider-name',
              'instance_group' => 'ig-1'
            },
            {
              'name' => 'another-link-name',
              'link_provider' => 'another-provider-name',
              'instance_group' => 'ig-2',
              'properties' => {
                'azs' => [ 'europe-west1-a' ],
                'status' => 'healthy'
              }
            }
          ]
        }
        catalog = brokerProperties.dig('service_catalog')
        catalog['plans'][0] = catalog['plans'][0].merge(valid_dns_config)
        @properties = brokerProperties.merge(
          'service_catalog' => catalog
        )
        broker_config = @template.render(@properties)
        plans = YAML.safe_load(broker_config).dig('service_catalog', 'plans')
        binding_config = plans[0].fetch('binding_with_dns', {})
        expect(binding_config).to eq(valid_dns_config['binding_with_dns'])
      end

      it 'fails when mandatory keys are not specified' do
        item = {
          'name' => 'my-link-name',
          'link_provider' => 'provider-name',
          'instance_group' => 'ig-1'
        }
        %w[name link_provider instance_group].each do |key|
          item_clone = item.clone
          item_clone.delete(key)
          config = { 'binding_with_dns' => [item_clone] }
          catalog = brokerProperties.dig('service_catalog')
          catalog['plans'][0] = catalog['plans'][0].merge(config)
          @properties = brokerProperties.merge(
            'service_catalog' => catalog
          )
          expect { @template.render(@properties) }.to raise_error(
            RuntimeError,
            "Invalid binding with dns config - must specify #{key}"
          )
        end
      end

      it 'fails when an invalid property is passed' do
        item = {
          'name' => 'another-link-name',
          'link_provider' => 'another-provider-name',
          'instance_group' => 'ig-2',
          'properties' => {
            'not-a-valid-property' => 'irrelevant'
          }
        }
        config = { 'binding_with_dns' => [item] }
        catalog = brokerProperties.dig('service_catalog')
        catalog['plans'][0] = catalog['plans'][0].merge(config)
        @properties = brokerProperties.merge(
          'service_catalog' => catalog
        )
        expect { @template.render(@properties) }.to raise_error(
          RuntimeError,
          "Invalid binding with dns config - not-a-valid-property is not a valid property"
        )
      end

      it 'fails when azs is not a list' do
        item = {
          'name' => 'another-link-name',
          'link_provider' => 'another-provider-name',
          'instance_group' => 'ig-2',
          'properties' => {
            'azs' => 'europe-west1-a'
          }
        }
        config = { 'binding_with_dns' => [item] }
        catalog = brokerProperties.dig('service_catalog')
        catalog['plans'][0] = catalog['plans'][0].merge(config)
        @properties = brokerProperties.merge(
          'service_catalog' => catalog
        )
        expect { @template.render(@properties) }.to raise_error(
          RuntimeError,
          "Invalid binding with dns config - azs must be a list"
        )
      end

      it 'fails when status is not a valid option' do
        item = {
          'name' => 'another-link-name',
          'link_provider' => 'another-provider-name',
          'instance_group' => 'ig-2',
          'properties' => {
            'azs' => ['europe-west1-a'],
            'status' => 'not-valid'
          }
        }
        config = { 'binding_with_dns' => [item] }
        catalog = brokerProperties.dig('service_catalog')
        catalog['plans'][0] = catalog['plans'][0].merge(config)
        @properties = brokerProperties.merge(
          'service_catalog' => catalog
        )
        expect { @template.render(@properties) }.to raise_error(
          RuntimeError,
          "Invalid binding with dns config - status must be one of the following: default, healthy, unhealthy, all"
        )
      end

      it 'fails when use_stdin is disabled' do
        item = {
          'name' => 'my-link-name',
          'link_provider' => 'provider-name',
          'instance_group' => 'ig-1'
        }
        config = { 'binding_with_dns' => [item] }
        catalog = brokerProperties.dig('service_catalog')
        catalog['plans'][0] = catalog['plans'][0].merge(config)
        @properties = brokerProperties.merge(
          'use_stdin' => false,
          'service_catalog' => catalog
        )
        expect { @template.render(@properties) }.to raise_error(
          RuntimeError,
          "Plan #{catalog['plans'][0]['name']} configures binding_with_dns, but use_stdin is disabled"
        )
      end
    end
  end

  describe 'services_instances_api' do
    context "when it's not configured" do
      let(:manifest_file) { File.open 'spec/fixtures/valid-mandatory-broker-config.yml' }

      it "doesn't include the services_instances_api block" do
        expect(rendered_template).to_not include('service_instances_api')
      end
    end

    context "when it's configured" do
      let(:manifest_file) { File.open 'spec/fixtures/valid-optional-broker-config.yml' }

      it 'includes the service_instances_api block' do
        expect(rendered_template).to include('service_instances_api')

        config = YAML.load rendered_template
        expect(config['service_instances_api']['root_ca_cert']).to eq("some-root-ca")
        expect(config['service_instances_api']['disable_ssl_cert_verification']).to eq(true)
      end
    end
  end

  describe 'service_catalog.maintenance_info and service_catalog.plan.maintenance_info' do
    context "when it's not configured" do
      let(:manifest_file) { File.open 'spec/fixtures/valid-mandatory-broker-config.yml' }

      it "doesn't include the maintenance_info block" do
        expect(rendered_template).to_not include('maintenance_info')
      end
    end

    context "when it's configured" do
      let(:manifest_file) { File.open 'spec/fixtures/valid_config_with_maintenance_info.yml' }

      it "includes the maintenance_info block" do
        config = YAML.load rendered_template
        expect(config['service_catalog']['maintenance_info']['public']).to eq("global_key" => "global_value")
        expect(config['service_catalog']['plans'].first['maintenance_info']['public']).to eq("plan_key" => "plan_value")
        expect(config['service_catalog']['maintenance_info']['private']).to eq("global_private_key" => "global_private_value")
        expect(config['service_catalog']['plans'].first['maintenance_info']['private']).to eq("plan_private_key" => "plan_private_value")

        expect(config['service_catalog']['maintenance_info']['version']).to eq("1.0.0-beta+exp.sha.5114f85")
        expect(config['service_catalog']['plans'].first['maintenance_info']['version']).to eq("1.2.5+bar.555")

        expect(config['service_catalog']['maintenance_info']['description']).to eq("global description")
        expect(config['service_catalog']['plans'].first['maintenance_info']['description']).to eq("plan description")
      end
    end

    context "when it's misconfigured" do

      describe 'public and private' do
        let(:invalid_values) {
          [ {"key" => "value"}, ["1","2"] ]
        }
        let(:top_level_keys) { %w{public private} }

        it 'raises an error when the global maintenance_info has invalid types' do
          top_level_keys.each do |top_level_key|
            invalid_values.each do |v|
              catalog = brokerProperties.dig('service_catalog')
              catalog['maintenance_info'] = {top_level_key => {"nested" => v}}
              properties = brokerProperties.merge('service_catalog' => catalog)
              expect { @template.render(properties) }.to raise_error(
                RuntimeError,
                "the values for maintenance_info.#{top_level_key} cannot be nested"
              ), "no error raised for type #{v.class} at #{top_level_key}"
            end
          end
        end

        it 'raises an error when a plan maintenance_info has invalid types' do
          top_level_keys.each do |top_level_key|
            invalid_values.each do |v|
              catalog = brokerProperties.dig('service_catalog')
              catalog['plans'].first['maintenance_info'] = {top_level_key => {"nested" => v}}
              properties = brokerProperties.merge('service_catalog' => catalog)
              expect { @template.render(properties) }.to raise_error(
                RuntimeError,
                "the values for maintenance_info.#{top_level_key} cannot be nested"
              ), "no error raised for type #{v.class} at #{top_level_key}"
            end
          end
        end
      end

      describe 'version' do
        it 'raises an error when global maintenance_info version is not semver' do
          catalog = brokerProperties.dig('service_catalog')
          catalog['maintenance_info'] = {'version' => 'abacate'}

          properties = brokerProperties.merge('service_catalog' => catalog)
          expect { @template.render(properties) }.to raise_error(
            RuntimeError,
            "maintenance_info.version must respect semver"
          ), "no error raised for non-semver version"
        end

        it 'raises an error when plan maintenance_info version is not semver' do
          catalog = brokerProperties.dig('service_catalog')
          catalog['plans'].first['maintenance_info'] = {'version' => 'felisia'}

          properties = brokerProperties.merge('service_catalog' => catalog)
          expect { @template.render(properties) }.to raise_error(
            RuntimeError,
            "maintenance_info.version must respect semver"
          ), "no error raised for non-semver version"
        end
      end
    end
  end

  describe 'backup agent URL binding support' do
    context 'when not set' do
      let(:manifest_file) do
        generate_test_manifest do |yaml|
          yaml['instance_groups'][0]['jobs'][0]['properties'].delete('support_backup_agent_binding')
        end
      end

      it 'defaults to false' do
        expect(rendered_template).to include 'support_backup_agent_binding: false'
      end
    end

    context 'when disabled' do
      let(:manifest_file) do
        generate_test_manifest do |yaml|
          yaml['instance_groups'][0]['jobs'][0]['properties']['support_backup_agent_binding'] = false
        end
      end

      it 'is set to false' do
        config = YAML.safe_load(rendered_template)
        expect(config.dig('broker', 'support_backup_agent_binding')).to eq(false)
      end
    end

    context 'when enabled' do
      let(:manifest_file) do
        generate_test_manifest do |yaml|
          yaml['instance_groups'][0]['jobs'][0]['properties']['support_backup_agent_binding'] = true
        end
      end

      it 'is set to trie' do
        config = YAML.safe_load(rendered_template)
        expect(config.dig('broker', 'support_backup_agent_binding')).to eq(true)
      end
    end
  end
end

def generate_test_manifest
  valid_yaml = YAML.load_file('spec/fixtures/valid-mandatory-broker-config.yml')
  yield(valid_yaml)
  file = Tempfile.new('template')
  begin
    file.write(valid_yaml.to_yaml)
  ensure
    file.close
  end
  file
end
