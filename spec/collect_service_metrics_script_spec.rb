# frozen_string_literal: true

# Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.
# This program and the accompanying materials are made available under the terms of the under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

require 'spec_helper'

RSpec.describe 'collect-service-metrics script' do
  let(:links) do
    [{
      'broker' => {
        'instances' => [
          {
            'address' => '123.456.789.101'
          }
        ],
        'properties' => {
          'username' => "%username'\"t:%!",
          'password' => "%password'\"t:%!",
          'port' => 7070
        }
      }
    }]
  end

  let(:renderer) do
    merged_context = BoshEmulator.director_merge(YAML.load_file(manifest_file), 'service-metrics-adapter', links)
    Bosh::Template::Renderer.new(context: merged_context.to_json)
  end

  let(:rendered_template) { renderer.render('jobs/service-metrics-adapter/templates/collect-service-metrics.sh.erb') }

  context 'when the broker credentials contain special characters' do
    let(:manifest_file) { 'spec/fixtures/collect_service_metrics_with_special_characters.yml' }

    it 'escapes the broker credentials' do
      expect(rendered_template).to include "-brokerUsername '%username'\\''\"t:%!'"
      expect(rendered_template).to include "-brokerPassword '%password'\\''\"t:%!'"
    end
  end

  context 'when the broker uri is configured' do
    let(:manifest_file) { 'spec/fixtures/collect_service_metrics_with_special_characters.yml' }

    it 'uses the configured broker uri' do
      expect(rendered_template).to include '-brokerUrl http://example.com:8080'
    end
  end

  context 'when the broker uri property is missing and TLS is disabled on the broker' do
    let(:manifest_file) { 'spec/fixtures/collect_service_metrics_without_broker_uri.yml' }

    it 'uses the broker job link with an http prefix' do
      expect(rendered_template).to include '-brokerUrl http://123.456.789.101:7070'
    end
  end

  context 'when the broker uri property is missing and TLS is enabled on the broker' do
    let(:manifest_file) { 'spec/fixtures/collect_service_metrics_without_broker_uri_with_tls.yml' }

    it 'uses the broker job link with an https prefix' do
      expect(rendered_template).to include '-brokerUrl https://123.456.789.101:7070'
    end
  end

  context 'disableSSLCertVerification property' do
    context 'when disableSSLCertVerification is set to true' do
      let(:manifest_file) { 'spec/fixtures/collect_service_metrics_with_disable_ssl_cert_verification.yml' }

      it 'is passed to the command line' do
        expect(rendered_template).to include '-disableSSLCertVerification=true'
      end
    end

    context 'when disableSSLCertVerification is not set' do
      let(:manifest_file) { 'spec/fixtures/collect_service_metrics_without_broker_uri.yml' }

      it 'is passed to the command line as false' do
        expect(rendered_template).to include '-disableSSLCertVerification=false'
      end
    end
  end

  context 'when tls.ca_cert is passed' do
    let(:manifest_file) { 'spec/fixtures/collect_service_metrics_with_tls_certificate.yml' }

    it 'is passed to the command line' do
      expect(rendered_template).to include '-tlsCertificate "a certificate"'
    end
  end

end
