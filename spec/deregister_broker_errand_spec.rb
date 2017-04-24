# Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.
# This program and the accompanying materials are made available under the terms of the under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

require 'spec_helper'

RSpec.describe 'deregister-broker errand' do
  let(:renderer) { Bosh::Template::Renderer.new(context: BoshEmulator.director_merge(YAML.load_file(manifest_file), 'deregister-broker').to_json) }

  let(:rendered_template) { renderer.render('jobs/deregister-broker/templates/errand.sh.erb') }

  context 'disable_ssl_cert_verification not set' do
    let(:manifest_file) { 'spec/fixtures/deregister_broker_disable_ssl_verification_not_set.yml' }

    it 'does not skip ssl validation' do
      expect(rendered_template).not_to include '--skip-ssl-validation'
    end
  end

  context 'disable_ssl_cert_verification set to false' do
    let(:manifest_file) { 'spec/fixtures/deregister_broker_disable_ssl_verification_false.yml' }

    it 'does not skip ssl validation' do
      expect(rendered_template).not_to include '--skip-ssl-validation'
    end
  end

  context 'disable_ssl_cert_verification set to true' do
    let(:manifest_file) { 'spec/fixtures/deregister_broker_disable_ssl_verification_true.yml' }

    it 'skips ssl validation' do
      expect(rendered_template).to include '--skip-ssl-validation'
    end
  end

  context 'when the cf credentials contain special characters' do
    let(:manifest_file) { 'spec/fixtures/deregister_broker_with_special_characters.yml' }

    it 'escapes the cf username and password' do
      expect(rendered_template).to include "cf auth '%username'\\''\"t:%!' '%password'\\''\"t:%!'"
    end
  end
end
