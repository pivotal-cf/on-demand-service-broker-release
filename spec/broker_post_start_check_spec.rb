# frozen_string_literal: true

# Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.
# This program and the accompanying materials are made available under the terms of the under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

require 'spec_helper'

RSpec.describe 'broker-post-start script' do
  before(:all) do
    release_path = File.join(File.dirname(__FILE__), '..')
    release = Bosh::Template::Test::ReleaseDir.new(release_path)
    job = release.job('broker')
    @template = job.template('bin/post-start')
  end

  context 'when the broker credentials contain special characters' do
    before(:all) do
      @properties = VALID_MANDATORY_BROKER_PROPERTIES.merge(
        'username' => "%username'\"t:%!",
        'password' => "%password'\"t:%!"
      )
    end

    it 'escapes the broker username' do
      post_start_script = @template.render(@properties)
      expect(post_start_script).to include("-brokerUsername '%username'\\''\"t:%!'")
    end

    it 'escapes the broker password' do
      post_start_script = @template.render(@properties)
      expect(post_start_script).to include "-brokerPassword '%password'\\''\"t:%!'"
    end
  end
end
