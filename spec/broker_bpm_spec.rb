
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

RSpec.describe 'broker bpm templating' do
  let(:links) { [] }
  let(:renderer) do
    Bosh::Template::Renderer.new(context: BoshEmulator.director_merge(
      YAML.load_file(manifest_file.path), 'broker', links
    ).to_json)
  end
  let(:rendered_template) { renderer.render('jobs/broker/templates/bpm.yml.erb') }
  let(:manifest_file) { nil }

  after do
    manifest_file.close unless manifest_file.nil?
  end

  before(:all) do
    release_path = File.join(File.dirname(__FILE__), '..')
    release = Bosh::Template::Test::ReleaseDir.new(release_path)
    job = release.job('broker')
    @template = job.template('config/bpm.yml')
  end

  describe 'successful templating' do
    let(:manifest_file) { File.open 'spec/fixtures/valid-broker-bpm-config.yml' }

    it 'succeeds' do
      config = YAML.safe_load(rendered_template)
      expected = {
        'processes' => [{
          'name' => 'broker',
          'executable' => '/var/vcap/packages/broker/bin/on-demand-service-broker',
          'args' => [
            '-configFilePath',
            '/var/vcap/jobs/broker/config/broker.yml'
          ],
          'unsafe' => {
              'unrestricted_volumes' => [
                {
                  'path' => '/var/vcap/packages/odb-service-adapter/bin/service-adapter',
                  'writable' => false,
                  'allow_executions' => true,
                  'mount_only' => true
                },
                {
                  'path' => '/var/vcap/path-to-some-config-directory',
                  'writable' => false,
                  'allow_executions' => true,
                  'mount_only' => true
                },
                {
                  'path' => '/var/vcap/path-to-some-other-directory',
                  'writable' => false,
                  'allow_executions' => true,
                  'mount_only' => true
                }
              ]
            }
          }]
        }
      expect(config).to eq(expected)
    end
  end

  describe 'with no mount paths configured' do
    let(:manifest_file) { File.open 'spec/fixtures/valid-broker-bpm-config-no-mounts.yml' }

    it 'succeeds' do
      config = YAML.safe_load(rendered_template)
      expected_unrestricted_volumes = [
        {
          'path' => '/var/vcap/packages/odb-service-adapter/bin/service-adapter',
          'writable' => false,
          'allow_executions' => true,
          'mount_only' => true
        }
      ]
      expect(config['processes'][0]['unsafe']['unrestricted_volumes']).to eq(expected_unrestricted_volumes)
    end
  end

  describe 'with a custom service adapter path' do
    let(:manifest_file) { File.open 'spec/fixtures/valid-broker-bpm-config-custom-adapter-path.yml' }
    it 'templates the directory of the adapter path into unrestricted_volumes' do
      config = YAML.safe_load(rendered_template)
      expected_unrestricted_volumes = [
        {
          'path' => '/var/vcap/custom/adapter/executable.sh',
          'writable' => false,
          'allow_executions' => true,
          'mount_only' => true
        },
        {
          'path' => '/var/vcap/path-to-some-config-directory',
          'writable' => false,
          'allow_executions' => true,
          'mount_only' => true
        }
      ]
      expect(config['processes'][0]['unsafe']['unrestricted_volumes']).to eq(expected_unrestricted_volumes)
    end
  end
end
