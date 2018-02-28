# Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.
# This program and the accompanying materials are made available under the terms of the under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

require 'bosh/template/test'

RSpec.describe 'service-backup job control script' do
  before(:all) do
    release_path = File.join(File.dirname(__FILE__), '..')
    release = Bosh::Template::Test::ReleaseDir.new(release_path)
    job = release.job('service-backup')
    @template = job.template('bin/ctl')
  end

  context 'when the manifest specifies optional properties' do
    before(:all) do
      properties = {
        'service-backup' => {
          'backup_user' => 'backuper',
          'source_folder' => '/foo'
        }
      }
      @control_script = @template.render(properties)
    end

    it 'templates the specified backup_user' do
      expect(@control_script).to include("backup_user='backuper'")
    end

    it 'templates the specified source_folder' do
      expect(@control_script).to include("source_folder='/foo'")
    end
  end

  context 'when the manifest does not specify optional properties' do
    it 'templates the default backup_user' do
      control_script = @template.render({})
      expect(control_script).to include("backup_user='vcap'")
    end
  end
end
