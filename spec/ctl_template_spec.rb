# Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.
# This program and the accompanying materials are made available under the terms of the under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

RSpec.describe 'Service Backups Ctl script' do
  let(:renderer) do
    Bosh::Template::Renderer.new(
      context: BoshEmulator.director_merge(
        YAML.load_file(manifest_file.path), 'service-backup'
      ).to_json
    )
  end
  let(:rendered_template) { renderer.render('jobs/service-backup/templates/ctl.erb') }

  after(:each) { manifest_file.close }

  context 'when the manifest contains a custom backup user' do
    let(:manifest_file) { File.open('spec/fixtures/valid_with_backup_user.yml') }

    it 'templates the value of backup_user' do
      expect(rendered_template).to include("backup_user='backuper'")
    end
  end

  context 'when the manifest does not specify a custom backup user' do
    let(:manifest_file) { File.open('spec/fixtures/valid_s3.yml') }

    it 'templates the default value' do
      expect(rendered_template).to include("backup_user='vcap'")
    end
  end

  context 'when the manifest specifies a source folder' do
    let(:manifest_file) { File.open('spec/fixtures/valid_s3.yml') }

    it 'templates the value of source folder' do
      expect(rendered_template).to include("source_folder='/foo'")
    end
  end
end
