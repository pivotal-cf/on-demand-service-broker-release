# Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.
# This program and the accompanying materials are made available under the terms of the under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

require 'tempfile'

RSpec.describe 'backup job config rendering' do
  let(:renderer) {
     Bosh::Template::Renderer.new({context: emulate_bosh_director_merge(YAML.load_file(manifest_file)).to_json})
  }
  let(:custom_msg) { 'custom message' }
  let(:empty_alerts) do
    {
      "product_name" => "",
      "config" => {
        "cloud_controller" => {
          "url" => "",
          "user" => "",
          "password" => ""
        },
        "notifications" => {
          "service_url" => "",
          "cf_org" => "",
          "cf_space" => "",
          "reply_to" => "",
          "client_id" => "",
          "client_secret" => ""
        },
        "timeout_seconds" => 60,
        "skip_ssl_validation" => false
      }
    }
  end

  context 'when the manifest contains valid s3 properties' do
    let(:manifest_file) { 'spec/fixtures/valid_s3.yml' }
    subject{ YAML.load(renderer.render('jobs/service-backup/templates/backup.yml.erb')) }

    it { should eq({
      "destinations" => [
        {
          "type" => "s3",
          "config" => {
            "endpoint_url" => "some-url",
            "region" => "some-region",
            "bucket_name" => "test",
            "bucket_path" => "foo/bar",
            "access_key_id" => "*4!'T#f\"J}A,~Da{)4{jz",
            "secret_access_key" => "itsasecret"
          }
        }
      ],
      "add_deployment_name_to_backup_path" => false,
      "deployment_name" => "service-backup",
      "alerts" => empty_alerts,
      "aws_cli_path" => "/var/vcap/packages/service-backup_aws-cli/bin/aws",
      "azure_cli_path" => "/var/vcap/packages/service-backup_blobxfer/bin/blobxfer",
      "source_folder" => "/foo",
      "source_executable" => "whoami",
      "cron_schedule" => "*/5 * * * * *",
      "backup_user" => "vcap",
      "cleanup_executable" => "somecleanup",
      "missing_properties_message" => "custom message",
      "exit_if_in_progress" => false,
      "service_identifier_executable" => nil
    })}
  end

  context 'when the manifest contains a custom backup user' do
    let(:manifest_file) { 'spec/fixtures/valid_with_backup_user.yml' }
    subject{ YAML.load(renderer.render('jobs/service-backup/templates/backup.yml.erb')) }
    its(["backup_user"]){ should eq("backuper")}
  end

  context 'when the manifest sets add_deployment_name_to_backup_path to true' do
    let(:manifest_file) { 'spec/fixtures/valid_with_add_deployment_name_to_backup_path.yml' }
    subject{ YAML.load(renderer.render('jobs/service-backup/templates/backup.yml.erb')) }
    its(["deployment_name"]) { should eq("service-backup") }
  end

  context 'when the manifest contains no S3 endpoint_url' do
    let(:manifest_file) { 'spec/fixtures/valid_s3_without_endpoint.yml' }
    subject{ YAML.load(renderer.render('jobs/service-backup/templates/backup.yml.erb')) }

    its(["destinations", 0, "config", "endpoint_url"]){ should eq("")}
  end

  context 'when the manifest contains no S3 region' do
    let(:manifest_file) { 'spec/fixtures/valid_s3_without_region.yml' }
    subject{ YAML.load(renderer.render('jobs/service-backup/templates/backup.yml.erb')) }

    its(["destinations", 0, "config", "region"]){ should eq("")}
  end

  context 'when the manifest contains invalid S3 properties' do
    let(:manifest_file) { 'spec/fixtures/invalid_s3.yml' }

    it 'raises an error containing a custom message' do
      expect {
        YAML.load(renderer.render('jobs/service-backup/templates/backup.yml.erb'))
      }.to raise_error(RuntimeError, "Invalid config - Missing values for s3: bucket_name, bucket_path.\n#{custom_msg}")
    end
  end

  context 'when the manifest contains no S3 config block' do
    let(:manifest_file) { 'spec/fixtures/invalid_s3_with_no_config.yml' }

    it 'raises an error containing a custom message' do
      expect {
        YAML.load(renderer.render('jobs/service-backup/templates/backup.yml.erb'))
      }.to raise_error(RuntimeError, "Invalid config - Missing config for s3.\n#{custom_msg}")
    end
  end

  context 'when the manifest contains a destination without type' do
    let(:manifest_file) { 'spec/fixtures/invalid_destination_with_no_type.yml' }

    it 'raises an error containing a custom message' do
      expect {
        YAML.load(renderer.render('jobs/service-backup/templates/backup.yml.erb'))
      }.to raise_error(RuntimeError, "Invalid config - Missing type for destination.\n#{custom_msg}")
    end
  end

  context 'when the manifest contains valid gcs properties' do
    let(:manifest_file) { 'spec/fixtures/valid_gcs.yml' }
    subject{ YAML.load(renderer.render('jobs/service-backup/templates/backup.yml.erb')) }
    it { should eq({
      "destinations" => [
        {
          "type" => "gcs",
          "config" => {
            "service_account_json" => "some-json",
            "project_id" => "gcs-project",
            "bucket_name" => "foo",
          }
        }
      ],
      "alerts" => empty_alerts,
      "add_deployment_name_to_backup_path" => false,
      "deployment_name" => "service-backup",
      "source_folder"=>"/foo",
      "aws_cli_path" => "/var/vcap/packages/service-backup_aws-cli/bin/aws",
      "azure_cli_path" => "/var/vcap/packages/service-backup_blobxfer/bin/blobxfer",
      "source_executable"=>"whoami",
      "cron_schedule"=>"*/5 * * * * *",
      "backup_user"=>"vcap",
      "cleanup_executable"=>"somecleanup",
      "missing_properties_message"=>"custom message",
      "exit_if_in_progress" => false,
      "service_identifier_executable" => nil
    })}
  end

  context 'when the manifest is missing mandatory instance group fields' do
    ['service_account_json', 'bucket_name', 'project_id'].each do |missing_field|
      context ": #{missing_field}" do
        let(:manifest_file) do
          manifest = YAML.load_file('spec/fixtures/valid_gcs.yml')
          manifest.fetch('properties').fetch('service-backup').fetch('destinations')[0].fetch('config').delete(missing_field)

          @save_me = create_temp_file(manifest.to_yaml)
          @save_me.path
        end

        it 'templating raises an error' do
          expect {
            YAML.load(renderer.render('jobs/service-backup/templates/backup.yml.erb'))
          }.to raise_error(RuntimeError, "Invalid config - Missing values for gcs: #{missing_field}.\n#{custom_msg}")
        end
      end
    end
  end


  context 'when the manifest contains valid scp properties' do
    let(:manifest_file) { 'spec/fixtures/valid_scp.yml' }
    subject{ YAML.load(renderer.render('jobs/service-backup/templates/backup.yml.erb')) }

    it { should eq({
      "destinations" => [
        {
          "type" => "scp",
          "config" => {
            "server" => "foo",
            "user" => "user",
            "destination" => "/var",
            "key" => "akey",
            "fingerprint" => "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAubiN81eDcafrgMeLzaFPsw2kNvEcq",
            "port" =>22
          }
        }
      ],
      "add_deployment_name_to_backup_path" => false,
      "deployment_name" => "service-backup",
      "alerts" => empty_alerts,
      "source_folder" => "/foo",
      "aws_cli_path" => "/var/vcap/packages/service-backup_aws-cli/bin/aws",
      "azure_cli_path" => "/var/vcap/packages/service-backup_blobxfer/bin/blobxfer",
      "source_executable" => "whoami",
      "cron_schedule" => "*/5 * * * * *",
      "backup_user" => "vcap",
      "cleanup_executable" => "somecleanup",
      "exit_if_in_progress" => false,
      "service_identifier_executable" => nil,
      "missing_properties_message" => "custom message"
    })}
  end

  context 'when the manifest contains invalid scp properties' do
    let(:manifest_file) { 'spec/fixtures/invalid_scp.yml' }

    it 'raises an error containing a custom message' do
      expect {
        renderer.render('jobs/service-backup/templates/backup.yml.erb')
      }.to raise_error(RuntimeError, "Invalid config - Missing values for scp: server, user, destination, key.\n#{custom_msg}")
    end
  end

  context 'when the manifest contains no scp config block' do
    let(:manifest_file) { 'spec/fixtures/invalid_scp_with_no_config.yml' }

    it 'raises an error containing a custom message' do
      expect {
        YAML.load(renderer.render('jobs/service-backup/templates/backup.yml.erb'))
      }.to raise_error(RuntimeError, "Invalid config - Missing config for scp.\n#{custom_msg}")
    end
  end

  context 'when the manifest contains no port for scp' do
    let(:manifest_file) { 'spec/fixtures/valid_scp_without_port.yml' }
    subject{ YAML.load(renderer.render('jobs/service-backup/templates/backup.yml.erb')) }

    its(["destinations", 0, "config", "port"]){ should eq(22)}
  end

  context 'when the manifest contains no fingerprint for scp' do
    let(:manifest_file) { 'spec/fixtures/valid_scp_without_fingerprint.yml' }
    subject{ YAML.load(renderer.render('jobs/service-backup/templates/backup.yml.erb')) }

    its(["destinations", 0, "config", "fingerprint"]){ should eq("")}
  end

  context 'when the manifest contains valid azure properties' do
    let(:manifest_file) { 'spec/fixtures/valid_azure.yml' }
    subject{ YAML.load(renderer.render('jobs/service-backup/templates/backup.yml.erb')) }

    it { should eq({
      "destinations" => [
        {
          "type" => "azure",
          "config" => {
            "storage_account" => "some-account",
            "storage_access_key" => "some-access-key",
            "container" => "some-container",
            "path" => "some/path",
            "blob_store_base_url" => "endpoint.com"
          }
        }
      ],
      "add_deployment_name_to_backup_path" => false,
      "deployment_name" => "service-backup",
      "alerts" => empty_alerts,
      "source_folder" => "/foo",
      "source_executable" => "whoami",
      "cron_schedule" => "*/5 * * * * *",
      "backup_user" => "vcap",
      "cleanup_executable" => "somecleanup",
      "exit_if_in_progress" => false,
      "service_identifier_executable" => nil,
      "aws_cli_path" => "/var/vcap/packages/service-backup_aws-cli/bin/aws",
      "azure_cli_path" => "/var/vcap/packages/service-backup_blobxfer/bin/blobxfer",
      "missing_properties_message" => "custom message"
    })}
  end

  context 'when the manifest contains valid azure properties' do
    let(:manifest_file) { 'spec/fixtures/valid_azure_without_blobstore.yml' }
    subject{ YAML.load(renderer.render('jobs/service-backup/templates/backup.yml.erb')) }

    its(["destinations", 0, "config", "blob_store_base_url"]){ should eq("core.windows.net")}
  end

  context 'when the manifest contains invalid azure properties' do
    let(:manifest_file) { 'spec/fixtures/invalid_azure.yml' }

    it 'raises an error containing a custom message' do
      expect {
        renderer.render('jobs/service-backup/templates/backup.yml.erb')
      }.to raise_error(RuntimeError, "Invalid config - Missing values for azure: storage_account, storage_access_key, container, path.\n#{custom_msg}")
    end
  end

  context 'when the manifest contains no destinations' do
    let(:manifest_file) { 'spec/fixtures/valid_no_destinations.yml' }
    subject{ YAML.load(renderer.render('jobs/service-backup/templates/backup.yml.erb')) }

    it { should eq({
      "destinations" => [],
      "alerts" => empty_alerts,
      "add_deployment_name_to_backup_path" => false,
      "deployment_name" => "service-backup",
      "source_folder" => "/foo",
      "source_executable" => "whoami",
      "cron_schedule" => "*/5 * * * * *",
      "backup_user" => "vcap",
      "cleanup_executable" => "somecleanup",
      "aws_cli_path" => "/var/vcap/packages/service-backup_aws-cli/bin/aws",
      "azure_cli_path" => "/var/vcap/packages/service-backup_blobxfer/bin/blobxfer",
      "exit_if_in_progress" => false,
      "service_identifier_executable" => nil,
      "missing_properties_message" => "custom message"
    })}
  end

  context 'when the manifest contains no backup destination properties' do
    let(:manifest_file) { 'spec/fixtures/skip_backups.yml' }
    subject{ YAML.load(renderer.render('jobs/service-backup/templates/backup.yml.erb')) }

    it { should eq({
      "destinations" => [],
      "alerts" => empty_alerts,
      "add_deployment_name_to_backup_path" => false,
      "deployment_name" => "service-backup",
      "source_folder" => "/foo",
      "source_executable" => "whoami",
      "cron_schedule" => "*/5 * * * * *",
      "backup_user" => "vcap",
      "cleanup_executable" => "somecleanup",
      "aws_cli_path" => "/var/vcap/packages/service-backup_aws-cli/bin/aws",
      "azure_cli_path" => "/var/vcap/packages/service-backup_blobxfer/bin/blobxfer",
      "exit_if_in_progress" => false,
      "service_identifier_executable" => nil,
      "missing_properties_message" => "custom message"
    })}
  end

  context 'when the manifest contains a service identifier command' do
    let(:manifest_file) { 'spec/fixtures/service_identifier.yml' }

    subject{ YAML.load(renderer.render('jobs/service-backup/templates/backup.yml.erb')) }

    its(["service_identifier_executable"]){ should eq("service-identifier-cmd")}
  end

  context 'when the manifest contains no backup properties' do
    let(:manifest_file) { 'spec/fixtures/no_service_backups.yml' }
    subject{ YAML.load(renderer.render('jobs/service-backup/templates/backup.yml.erb')) }

    it "renders all the default values in the BOSH spec" do
      expect(subject).to eq({
        "cleanup_executable" => "",
        "cron_schedule" => nil,
        "backup_user" => "vcap",
        "destinations" => [],
        "alerts" => empty_alerts,
        "add_deployment_name_to_backup_path" => false,
        "deployment_name" => "service-backup",
        "exit_if_in_progress" => false,
        "aws_cli_path" => "/var/vcap/packages/service-backup_aws-cli/bin/aws",
        "azure_cli_path" => "/var/vcap/packages/service-backup_blobxfer/bin/blobxfer",
        "missing_properties_message" => "Provide these missing fields in your manifest.",
        "service_identifier_executable" => nil,
        "source_executable" => nil,
        "source_folder" => nil
      })
    end
  end

  context "when the manifest contains a destination with unknown type" do
    let(:manifest_file) { 'spec/fixtures/invalid_unknown_destination_type.yml' }

    it 'raises an error containing a custom message' do
      expect {
        renderer.render('jobs/service-backup/templates/backup.yml.erb')
      }.to raise_error(RuntimeError, "Invalid config - Unknown destination type: unknown-type.\n#{custom_msg}")
    end
  end

  context "when the manifest is missing properties for service_backup" do
    let(:manifest_file) { 'spec/fixtures/invalid_service_backup_with_common_fields_missing.yml' }

    it 'raises an error containing a custom message' do
      expect {
        renderer.render('jobs/service-backup/templates/backup.yml.erb')
      }.to raise_error(RuntimeError, "Invalid config - Missing values for service_backup: source_folder, cron_schedule.\n#{custom_msg}")
    end
  end

  context 'when the manifest contains multiple valid destinations' do
    let(:manifest_file) { 'spec/fixtures/valid_multiple_destinations.yml' }
    subject{ YAML.load(renderer.render('jobs/service-backup/templates/backup.yml.erb')) }

    it { should eq({
      "destinations" => [
        {
          "type" => "azure",
          "name" => "long-term-backups",
          "config" => {
            "storage_account" => "some-account",
            "storage_access_key" => "some-access-key",
            "container" => "some-container",
            "path" => "some/path",
            "blob_store_base_url" => "endpoint.com"
          }
        },
        {
          "type" => "scp",
          "config" =>{
            "server" => "foo",
            "user" => "user",
            "destination" => "/var",
            "key" => "akey",
            "fingerprint" => "",
            "port" => 22
          }
        }
      ],
      "alerts" => empty_alerts,
      "add_deployment_name_to_backup_path" => false,
      "deployment_name" => "service-backup",
      "source_folder" => "/foo",
      "source_executable" => "whoami",
      "cron_schedule" => "*/5 * * * * *",
      "backup_user" => "vcap",
      "cleanup_executable" => "somecleanup",
      "exit_if_in_progress" => false,
      "service_identifier_executable" => nil,
      "aws_cli_path" => "/var/vcap/packages/service-backup_aws-cli/bin/aws",
      "azure_cli_path" => "/var/vcap/packages/service-backup_blobxfer/bin/blobxfer",
      "missing_properties_message" => "custom message"
    })}
  end

  context 'when the manifest contains valid alert configuration' do
    let(:manifest_file) { 'spec/fixtures/valid_s3_with_alerts.yml' }
    subject{ YAML.load(renderer.render('jobs/service-backup/templates/backup.yml.erb')) }
    it { should eq({
      "destinations" => [
        {
          "type" => "s3",
          "config" => {
            "endpoint_url" => "some-url",
            "region" => "some-region",
            "bucket_name" => "test",
            "bucket_path" => "foo/bar",
            "access_key_id" => "key",
            "secret_access_key" => "itsasecret"
          }
        }
      ],
      "alerts" => {
        "product_name" => "MySQL",
        "config" => {
          "cloud_controller" => {
            "url" => "https://api.cf.com",
            "user" => "admin",
            "password" => "password"
          },
          "notifications" => {
            "service_url" => "https://notifcations.cf.com",
            "cf_org" => "system",
            "cf_space" => "mysql-notifications",
            "reply_to" => "me@example.com",
            "client_id" => "admin",
            "client_secret" => "password"
          },
          "timeout_seconds" => 60,
          "skip_ssl_validation" => false
        },
      },
      "add_deployment_name_to_backup_path" => false,
      "deployment_name" => "service-backup",
      "aws_cli_path" => "/var/vcap/packages/service-backup_aws-cli/bin/aws",
      "azure_cli_path" => "/var/vcap/packages/service-backup_blobxfer/bin/blobxfer",
      "source_folder" => "/foo",
      "source_executable" => "whoami",
      "cron_schedule" => "*/5 * * * * *",
      "backup_user" => "vcap",
      "cleanup_executable" => "somecleanup",
      "missing_properties_message" => "custom message",
      "exit_if_in_progress" => false,
      "service_identifier_executable" => nil,
    })}
  end

  include Bosh::Template::PropertyHelper
  # Trying to emulate bosh director Bosh::Director::DeploymentPlan::Job#extract_template_properties
  def emulate_bosh_director_merge(manifest)
    manifest_properties = manifest["properties"]

    job_spec = YAML.load_file('jobs/service-backup/spec')
    spec_properties = job_spec["properties"]

    effective_properties = {}
    spec_properties.each_pair do |name, definition|
      copy_property(effective_properties, manifest_properties, name, definition["default"])
    end

    manifest['deployment'] = 'service-backup'

    manifest.merge({"properties" => effective_properties})
  end
end

def create_temp_file(content)
  file = Tempfile.new('template')
  file.write(content)
  file.close
  file
end
