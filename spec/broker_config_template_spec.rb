# Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.
# This program and the accompanying materials are made available under the terms of the under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

require 'spec_helper'
require 'tempfile'

RSpec.describe 'broker config templating' do
  let(:links) { [] }
  let(:renderer) do
    Bosh::Template::Renderer.new(context: BoshEmulator.director_merge(
      YAML.load_file(manifest_file.path), 'broker', links
    ).to_json)
  end

  let(:rendered_template) { renderer.render('jobs/broker/templates/broker.yml.erb') }

  after do
    manifest_file.close
  end

  describe 'successful templating' do
    context 'basic auth for BOSH' do
      let(:manifest_file) { File.open 'spec/fixtures/valid-mandatory-broker-config.yml' }

      it 'succeeds' do
        config = YAML.load(rendered_template)
        expected = {
          "url"=>"some-url",
          "root_ca_cert"=>nil,
          "authentication"=>{
            "basic"=>{
              "username"=>"some-username",
              "password"=>"some-password",
            },
            "uaa"=>{
              "client_credentials"=> {
                "client_id"=>nil,
                "client_secret"=>nil,
              }
            }
          }
        }
        expect(config.fetch("bosh")).to eq(expected)
      end
    end

    context 'UAA configuration for BOSH' do
      let(:manifest_file) { File.open 'spec/fixtures/valid-bosh-uaa.yml' }

      it 'succeeds' do
        config = YAML.load(rendered_template)
        expected = {
          "url"=>"some-url",
          "root_ca_cert"=>nil,
          "authentication"=>{
            "basic"=>{
              "username"=>nil,
              "password"=>nil,
            },
            "uaa"=>{
              "client_credentials"=> {
                "client_id"=>"id",
                "client_secret"=>"secret",
              }
            }
          }
        }
        expect(config.fetch("bosh")).to eq(expected)
      end
    end
  end

  describe 'bosh authentication configuration' do
    context 'when there is no authentication configured' do
      let(:manifest_file) { File.open 'spec/fixtures/invalid-missing-bosh-auth.yml' }

      it 'templating raises an error' do
        expect {
          rendered_template
        }.to raise_error(RuntimeError, "Invalid bosh config - must specify authentication")
      end
    end

    context 'when both authentication types are configured' do
      let(:manifest_file) { File.open 'spec/fixtures/invalid-both-bosh-auth.yml' }

      it 'templating raises an error' do
        expect {
          rendered_template
        }.to raise_error(RuntimeError, "Invalid bosh config - must only specify one type of authentication")
      end
    end
  end

  context 'when the manifest enables secure binding properties but is missing client ID' do
    let(:manifest_file) { File.open 'spec/fixtures/invalid_credhub_missing_uaa_client_id.yml' }

    it 'templating raises an error' do
      expect {
        rendered_template
      }.to raise_error(RuntimeError, "Invalid secure_binding_credentials config - must specify client_id")
    end
  end

  context 'when the manifest enables secure binding properties but is missing client secret' do
    let(:manifest_file) { File.open 'spec/fixtures/invalid_credhub_missing_uaa_client_secret.yml' }

    it 'templating raises an error' do
      expect {
        rendered_template
      }.to raise_error(RuntimeError, "Invalid secure_binding_credentials config - must specify client_secret")
    end
  end

  describe 'credhub link' do
    let(:manifest_file) { File.open 'spec/fixtures/valid_credhub.yml' }

    context 'when secure_binding_credentials is enabled but there is no credhub link' do
      it 'templating raises an error' do
        expect {
          rendered_template
        }.to raise_error(RuntimeError, "secure_binding_credentials is enabled, but no CredHub link was provided")
      end
    end

    context "when credhub link is provided" do
      let(:links) do
        [{
          'credhub' => {
            'instances' => [],
            'properties' => {
              'credhub' => {
                'port' => 8844,
                'ca_certificate' => 'credhub_ca_cert',
                'internal_url' => 'my.credhub.internal',
              }
            }
          }
        }]
      end

      it 'includes the credhub properties' do
        expect(YAML.load(rendered_template).fetch('credhub')).to eq(
          "api_url" => "https://my.credhub.internal:8844",
          "ca_cert" => "credhub_ca_cert",
          "client_id" => "credhub_id",
          "client_secret" => "credhub_password",
          "internal_uaa_ca_cert" => "--- INTERNAL UAA CA CERT ---\n",
        )
      end

      context "but secure binding is disabled" do
        let(:manifest_file) { File.open 'spec/fixtures/valid_disabled_credhub.yml' }

        it 'does not include the credhub properties in the broker config' do
          expect(YAML.load(rendered_template)).not_to have_key('credhub')
        end
      end

      context 'but the manifest does not contain secure binding properties' do
        let(:manifest_file) { File.open 'spec/fixtures/valid-mandatory-broker-config.yml' }

        it 'does not include the credhub properties in the broker config' do
          expect(YAML.load(rendered_template)).not_to have_key('credhub')
        end
      end
    end

    context "when credhub link is provided but set to empty" do
      let(:manifest_file) { File.open 'spec/fixtures/valid_credhub.yml' }
      let(:links) do
        [{
          'credhub' => {
            'instances' => [],
            'properties' => {
              'credhub' => {
                'port' => '',
                'ca_certificate' => '',
                'internal_url' => '',
              },
            }
          }
        }]
      end

      it "raises an error" do
          expect {
            rendered_template
          }.to raise_error(RuntimeError, "Secure service binding is enabled but CredHub link is empty")
      end
    end
  end

  context 'when the manifest contains only mandatory service catalog properties' do
    let(:manifest_file) { File.open 'spec/fixtures/valid-mandatory-broker-config.yml' }

    it 'sets the value of disable_ssl_cert_verification to false' do
      expect(rendered_template).to include 'disable_ssl_cert_verification: false'
    end
  end

  context 'when the manifest specifies a value for disable_ssl_cert_verification' do
    let(:manifest_file) { File.open 'spec/fixtures/valid-broker-config-ignoring-ssl-certs.yml' }

    it 'sets the value of disable_ssl_cert_verification to true' do
      expect(rendered_template).to include 'disable_ssl_cert_verification: true'
    end
  end

  context 'when the manifest specifies a value for metadata.shareable' do
    let(:manifest_file) { File.open 'spec/fixtures/valid-shareable-config.yml' }

    it 'sets the value correctly' do
      expect(rendered_template).to include 'shareable: true'
    end
  end

  context "when the manifest is missing mandatory service catalog property" do
    ["id", "service_name", "service_description", "bindable", "plan_updatable"].each do |missing_field|
      context "when #{missing_field} is absent" do
        let(:manifest_file) do
          generate_test_manifest do |yaml|
            yaml['instance_groups'][0]['jobs'][0]['properties']["service_catalog"].delete(missing_field)
          end
        end

        it 'templating raises an error' do
          expect {
            rendered_template
          }.to raise_error(RuntimeError, "Invalid service_catalog config - must specify #{missing_field}")
        end
      end

      context "when #{missing_field} is empty string" do
        let(:manifest_file) do
          generate_test_manifest do |yaml|
            yaml['instance_groups'][0]['jobs'][0]['properties']["service_catalog"][missing_field] = ''
          end
        end

        it 'templating raises an error' do
          expect {
            rendered_template
          }.to raise_error(RuntimeError, "Invalid service_catalog config - must specify #{missing_field}")
        end
      end
    end
  end

  context "when the manifest has no plans property" do
    let(:manifest_file) do
      generate_test_manifest do |yaml|
        yaml['instance_groups'][0]['jobs'][0]['properties']["service_catalog"].delete("plans")
      end
    end

    it 'templating raises an error' do
      expect {
        rendered_template
      }.to raise_error(RuntimeError, "Invalid service_catalog config - must specify plans")
    end
  end

  context "when the manifest has 0 plans" do
    let(:manifest_file) do
      generate_test_manifest do |yaml|
        yaml['instance_groups'][0]['jobs'][0]['properties']["service_catalog"]["plans"] = []
      end
    end

    it 'templating raises an error' do
      expect {
        rendered_template
      }.to raise_error(RuntimeError, "Invalid service_catalog config - must specify plans")
    end
  end

  context "when the manifest only has nil plans" do
    let(:manifest_file) do
      generate_test_manifest do |yaml|
        yaml['instance_groups'][0]['jobs'][0]['properties']["service_catalog"]["plans"] = [nil, nil]
      end
    end

    it 'templating raises an error' do
      expect {
        rendered_template
      }.to raise_error(RuntimeError, "Invalid service_catalog config - must specify plans")
    end
  end

  context "when the manifest also has nil plans" do
    let(:manifest_file) do
      generate_test_manifest do |yaml|
        plan = yaml['instance_groups'][0]['jobs'][0]['properties']["service_catalog"]["plans"][0]
        yaml['instance_groups'][0]['jobs'][0]['properties']["service_catalog"]["plans"] = [nil,  plan, nil]
      end
    end

    it 'filters out nil plans' do
      config = YAML.load(rendered_template)
      expect(config.fetch("service_catalog").fetch("plans").length).to eq(1)
      expect(config.fetch("service_catalog").fetch("plans")[0].fetch("name")).to eq("dedicated-vm")
    end
  end

  context 'when the manifest is missing mandatory plan fields' do
    ['name', 'plan_id', 'description', 'instance_groups'].each do |missing_field|
      context ": #{missing_field}" do
        let(:manifest_file) do
          generate_test_manifest do |yaml|
            yaml['instance_groups'][0]['jobs'][0]['properties']["service_catalog"]["plans"].first.delete(missing_field)
          end
        end

        it 'templating raises an error' do
          expect {
            rendered_template
          }.to raise_error(RuntimeError, "Invalid plan config - must specify #{missing_field}")
        end
      end
    end
  end

  context "when the manifest has 0 instance groups for a plan" do
    let(:manifest_file) do
      generate_test_manifest do |yaml|
        yaml['instance_groups'][0]['jobs'][0]['properties']["service_catalog"]["plans"].first["instance_groups"] = []
      end
    end

    it 'templating raises an error' do
      expect {
        rendered_template
      }.to raise_error(RuntimeError, "Invalid plan config - must specify instance_groups")
    end
  end

  context 'when the manifest is missing mandatory instance group fields' do
    ['name', 'vm_type', 'instances', 'networks', 'azs'].each do |missing_field|
      context ": #{missing_field}" do
        let(:manifest_file) do
          generate_test_manifest do |yaml|
            yaml['instance_groups'][0]['jobs'][0]['properties']["service_catalog"]["plans"].first["instance_groups"].first.delete(missing_field)
          end
        end

        it 'templating raises an error' do
          expect {
            rendered_template
          }.to raise_error(RuntimeError, "Invalid instance group config - must specify #{missing_field}")
        end
      end
    end
  end

  describe 'networks and azs' do
    ['networks', 'azs'].each do |missing_field|
      context "when '#{missing_field}' is an empty array" do
        let(:manifest_file) do
          generate_test_manifest do |yaml|
            yaml['instance_groups'][0]['jobs'][0]['properties']["service_catalog"]["plans"].first["instance_groups"].first[missing_field] = []
            yaml
          end
        end

        it 'templating raises an error' do
          expect {
            rendered_template
          }.to raise_error(RuntimeError, "Invalid instance group config - must specify #{missing_field}")
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

  describe 'cf authentication' do
    context "when both user and client credentials are provided" do
      let(:manifest_file) { File.open 'spec/fixtures/invalid_has_both_client_and_user_cf_auth.yml' }

      it 'templating raises an error' do
        expect {
          rendered_template
        }.to raise_error(RuntimeError, "Invalid CF authentication config - must specify either client or user credentials")
      end
    end

    context 'basic auth for CF' do
      let(:manifest_file) { File.open 'spec/fixtures/valid-cf-basic-auth.yml' }

      it 'succeeds' do
        config = YAML.load(rendered_template)
        expected = {
          'url'=>'cf-url',
          'root_ca_cert'=>nil,
          'authentication'=>{
            'uaa'=>{
              'url' => "cf-uaa-url",
              'client_credentials' => {
                'client_id' => nil,
                'client_secret' => nil
              },
              'user_credentials'=>{
                'username' => 'cf-user',
                'password' => 'cf-pass'
              },
            }
          }
        }
        expect(config.fetch('cf')).to eq(expected)
      end
    end

    context 'UAA configuration for CF' do
      let(:manifest_file) { File.open 'spec/fixtures/valid-cf-uaa.yml' }

      it 'succeeds' do
        config = YAML.load(rendered_template)
        expected = {

          "url"=>"cf-url",
          "root_ca_cert"=>nil,
          "authentication"=>{
            "uaa"=>{
              "url" => "cf-uaa-url",
              "client_credentials"=> {
                "client_id"=>"id",
                "client_secret"=>"secret",
              },
              'user_credentials'=>{
                'username' => nil,
                'password' => nil
              },
            }
          }
        }
        expect(config.fetch("cf")).to eq(expected)
      end
    end
  end

  describe 'broker credentials have special characters in them' do
    let(:manifest_file) { File.open 'spec/fixtures/valid-with-special-characters.yml' }

      it 'parses successfully' do
        expect{rendered_template}.to_not raise_error
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
          raise_error(RuntimeError, "Unsupported value 'invalid' for cf_service_access. Choose from \"enable\", \"disable\", \"manual\"")
        )
      end
    end

    context 'when a valid value is configured' do
      ['enable', 'disable', 'manual'].each do |a|
        context " : #{a}" do
          let(:manifest_file) do
            generate_test_manifest do |yaml|
              yaml['instance_groups'][0]['jobs'][0]['properties']['service_catalog']['plans'][0]['cf_service_access'] = a
              yaml
            end
          end

          it "parses successfully" do
            expect{rendered_template}.to_not raise_error
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

      it "raises an error" do
        expect { rendered_template }.to(
          raise_error(RuntimeError, "Invalid service_deployment config - must specify releases")
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

      it "raises an error" do
        expect { rendered_template }.to(
          raise_error(RuntimeError, "Invalid service_deployment config - must specify at least one release")
        )
      end
    end

    context 'when a release is missing required fields' do
      ['name', 'version', 'jobs'].each do |required_field|
        context ": #{required_field}" do
          let(:manifest_file) do
            generate_test_manifest do |yaml|
              yaml['instance_groups'][0]['jobs'][0]['properties']['service_deployment']['releases'].first.delete(required_field)
              yaml
            end
          end

          it "raises an error" do
            expect { rendered_template }.to(
              raise_error(RuntimeError, "Invalid service_deployment.releases config - must specify #{required_field}")
            )
          end
        end
      end
    end

    context 'with multiple releases' do
      let(:second_release) { {'name' => 'second-release', 'version' => 4567, 'jobs' => ['second-job']} }

      context 'and all relesaes are configured correctly' do
        let(:manifest_file) do
          generate_test_manifest do |yaml|
            yaml['instance_groups'][0]['jobs'][0]['properties']['service_deployment']['releases'][1] =
              second_release
            yaml
          end
        end

        it 'does not raise an error' do
          expect{rendered_template}.to_not(raise_error)
        end
      end

      context 'and the second is missing required fields' do
        ['name', 'version', 'jobs'].each do |required_field|
          context ": #{required_field}" do
            let(:manifest_file) do
              generate_test_manifest do |yaml|
                second_release.delete(required_field)
                yaml['instance_groups'][0]['jobs'][0]['properties']['service_deployment']['releases'][1] =
                  second_release
                yaml
              end
            end

            it "raises an error" do
              expect { rendered_template }.to(
                raise_error(RuntimeError, "Invalid service_deployment.releases config - must specify #{required_field}")
              )
            end
          end
        end
      end
    end

    context 'when no stemcell os is configured' do
      let(:manifest_file) do
        generate_test_manifest do |yaml|
          yaml['instance_groups'][0]['jobs'][0]['properties']['service_deployment']['stemcell']['os'] = nil
          yaml
        end
      end

      it "raises an error" do
        expect { rendered_template }.to(
          raise_error(RuntimeError, "Invalid service_deployment.stemcell config - must specify os")
        )
      end
    end

    context 'when no stemcell version is configured' do
      let(:manifest_file) do
        generate_test_manifest do |yaml|
          yaml['instance_groups'][0]['jobs'][0]['properties']['service_deployment']['stemcell']['version'] = nil
          yaml
        end
      end

      it "raises an error" do
        expect { rendered_template }.to(
          raise_error(RuntimeError, "Invalid service_deployment.stemcell config - must specify version")
        )
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
          raise_error(RuntimeError, "You must configure the exact release and stemcell versions in broker.service_deployment." +
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
          raise_error(RuntimeError, "You must configure the exact release and stemcell versions in broker.service_deployment. " +
          "ODB requires exact versions to detect pending changes as part of the 'cf update-service' workflow. For example, latest and 3112.latest are not supported.")
        )
      end
    end

    context 'when a stemcell version is latest' do
      let(:manifest_file) do
        generate_test_manifest do |yaml|
          yaml['instance_groups'][0]['jobs'][0]['properties']['service_deployment']['stemcell']['version'] = 'latest'
          yaml
        end
      end

      it 'raises an error' do
        expect { rendered_template }.to(
          raise_error(RuntimeError, "You must configure the exact release and stemcell versions in broker.service_deployment. " +
          "ODB requires exact versions to detect pending changes as part of the 'cf update-service' workflow. For example, latest and 3112.latest are not supported.")
        )
      end
    end

    context 'when a stemcell version is n.latest' do
      let(:manifest_file) do
        generate_test_manifest do |yaml|
          yaml['instance_groups'][0]['jobs'][0]['properties']['service_deployment']['stemcell']['version'] = '22.latest'
          yaml
        end
      end

      it 'raises an error' do
        expect { rendered_template }.to(
          raise_error(RuntimeError, "You must configure the exact release and stemcell versions in broker.service_deployment. " +
          "ODB requires exact versions to detect pending changes as part of the 'cf update-service' workflow. For example, latest and 3112.latest are not supported.")
        )
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
        expect(rendered_template).to include "enable_plan_schemas: true"
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
        expect(rendered_template).to include "enable_plan_schemas: false"
      end
    end

    context 'when pre-delete errand is specified' do
      let(:manifest_file) do
        generate_test_manifest do |yaml|
          yaml['instance_groups'][0]['jobs'][0]['properties']['service_catalog']['plans'][0]['lifecycle_errands'] = {'pre_delete' => [{'name' => 'cleanup'}]}
        end
      end

      it 'is included in the configuration' do
        expect(rendered_template).to include "- name: cleanup"
      end
    end

    context 'when pre-delete errand is in the wrong format' do
      let(:manifest_file) do
        generate_test_manifest do |yaml|
          yaml['instance_groups'][0]['jobs'][0]['properties']['service_catalog']['plans'][0]['lifecycle_errands'] = {'pre_delete' => {'name' => 'cleanup'}}
        end
      end

      it 'raises an error' do
        expect { rendered_template }.to(
          raise_error(RuntimeError, "Plan property lifecycle_errands.pre_delete must be an array.")
        )
      end
    end

    context 'when post-deploy errand is specified' do
      let(:manifest_file) do
        generate_test_manifest do |yaml|
          yaml['instance_groups'][0]['jobs'][0]['properties']['service_catalog']['plans'][0]['lifecycle_errands'] = {'post_deploy' => [{'name' => 'health-check'}]}
        end
      end

      it 'is included in the configuration' do
        expect(rendered_template).to include "- name: health-check"
      end
    end

    context 'when post-deploy errand is in the wrong format' do
      let(:manifest_file) do
        generate_test_manifest do |yaml|
          yaml['instance_groups'][0]['jobs'][0]['properties']['service_catalog']['plans'][0]['lifecycle_errands'] = {'post_deploy' => {'name' => 'health-check'}}
        end
      end

      it 'raises an error' do
        expect { rendered_template }.to(
          raise_error(RuntimeError, "Plan property lifecycle_errands.post_deploy must be an array.")
        )
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
