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

RSpec.describe 'indicator config templating' do
  let(:brokerProperties) {
    YAML
        .load_file('spec/fixtures/valid-mandatory-broker-config.yml')
        .fetch('instance_groups')
        .first
        .fetch('jobs')
        .first
        .fetch('properties')
  }

  let(:links) {[]}

  let(:rendered_template) {
    YAML.load(@template.render(brokerProperties))
  }

  let(:indicator) {
    rendered_template['spec']['indicators'].filter {|i| i['name'] == indicator_name}[0]
  }

  before(:all) do
    release_path = File.join(File.dirname(__FILE__), '..')
    release = Bosh::Template::Test::ReleaseDir.new(release_path)
    job = release.job('broker')
    @template = job.template('config/indicators.yml')
  end

  it 'sets `product` correctly' do
    expected_product = {
        "name" => "my-deployment",
        "version" => "1.0.0"
    }
    expect(rendered_template['spec']['product']).to eq(expected_product)
  end

  it 'sets `metadata` correctly' do
    expected_metadata = {
        "deployment" => "my-deployment",
        "source_id" => "my-deployment",
    }
    expect(rendered_template['metadata']['labels']).to eq(expected_metadata)
  end

  describe 'layout' do
    it 'should be not empty' do
      expect(rendered_template['spec']['layout']).not_to be_nil
      expect(rendered_template['spec']['layout']['title']).not_to be_nil
      expect(rendered_template['spec']['layout']['owner']).not_to be_nil
      expect(rendered_template['spec']['layout']['description']).not_to be_nil

      sections = rendered_template['spec']['layout']['sections']
      expect(sections).to include a_hash_including('indicators' => include('global_total_instances', 'dedicated_vm_total_instances', 'dedicated_high_mem_vm_total_instances',))
      expect(sections).to include a_hash_including('indicators' => start_with('global_total_instances'))
    end
  end

  describe 'global_total_instances indicator' do
    let(:indicator_name) {'global_total_instances'}

    describe 'promql' do
      before(:each) do
        brokerProperties['service_catalog']['service_name'] = "test-redis-broker"
      end

      it 'builds the right query' do
        expect(indicator['promql']).to eq('_on_demand_broker_test_redis_broker_total_instances{deployment="$deployment",source_id="$source_id"}')
      end
    end

    describe 'thresholds' do
      context 'when "service_catalog.global_quotas.service_instance_limit" is set' do
        before(:each) do
          brokerProperties['service_catalog']['global_quotas'] = {
              'service_instance_limit' => 200
          }
        end

        it 'is configured correctly' do
          expected_thresholds = [
              {"level" => "critical", "operator" => "gte", "value" => 200},
              {"level" => "warning", "operator" => "gte", "value" => (200 * 0.8).to_i}
          ]
          expect(indicator['thresholds']).to eq expected_thresholds
        end
      end

      context 'when "service_catalog.global_quotas.service_instance_limit" is not set' do
        it 'is empty' do
          expect(indicator['thresholds']).to be_empty
        end
      end
    end

    describe 'documentation' do
      it 'should be not empty' do
        expect(indicator['documentation']).not_to be_nil
        expect(indicator['documentation']['title']).not_to be_nil
        expect(indicator['documentation']['description']).not_to be_nil
        expect(indicator['documentation']['thresholdNote']).not_to be_nil
        expect(indicator['documentation']['recommendedResponse']).not_to be_nil
      end
    end
  end


  describe 'plan_total_instances indicator' do

    describe 'with no plan' do
      before(:each) do
        brokerProperties['service_catalog'].delete("plans")
      end

      it "has only the global total instances" do
        total_instances_indicator = rendered_template['spec']["indicators"].filter {|indicator| indicator["name"].end_with? "total_instances"}
        expect(total_instances_indicator.size).to eq 1

        sections = rendered_template['spec']['layout']['sections'][0]["indicators"]
        sections_for_total_instances = sections.filter {|s| s.end_with? "total_instances"}
        expect(sections_for_total_instances).to contain_exactly 'global_total_instances'
      end
    end

    describe 'for first plan' do
      let(:indicator_name) {'dedicated_vm_total_instances'}
      before(:each) do
        brokerProperties['service_catalog']['service_name'] = "test-redis-broker"
      end

      it 'builds the right query' do
        expect(indicator['promql']).to eq('_on_demand_broker_test_redis_broker_dedicated_vm_total_instances{deployment="$deployment",source_id="$source_id"}')
      end

      describe 'when a plan is "null"' do
        before(:each) do
          brokerProperties['service_catalog']['plans'][0] = nil
        end

        it 'ignores the plan' do
          expect(rendered_template['spec']['indicators'].size).to eq 2
        end
      end

      describe 'thresholds' do
        context 'when plan service instance limit is set' do
          before(:each) do
            brokerProperties['service_catalog']['plans'][0]['quotas'] = {
                'service_instance_limit' => 150
            }
          end

          it 'is configured correctly' do
            expected_thresholds = [
                {"level" => "critical", "operator" => "gte", "value" => 150},
                {"level" => "warning", "operator" => "gte", "value" => 120}
            ]
            expect(indicator['thresholds']).to eq expected_thresholds
          end
        end

        context 'when "service_catalog.global_quotas.service_instance_limit" is not set' do
          it 'is empty' do
            expect(indicator['thresholds']).to be_empty
          end
        end
      end

      describe 'documentation' do
        it 'should be not empty' do
          expect(indicator['documentation']).not_to be_nil
          expect(indicator['documentation']['title']).to eq('dedicated-vm Instance Count')
          expect(indicator['documentation']['description']).not_to be_nil
          expect(indicator['documentation']['thresholdNote']).not_to be_nil
          expect(indicator['documentation']['recommendedResponse']).not_to be_nil
        end
      end
    end

    describe 'for second plan' do
      let(:indicator_name) {'dedicated_high_mem_vm_total_instances'}
      before(:each) do
        brokerProperties['service_catalog']['service_name'] = "test-redis-broker"
      end

      it 'builds the right query' do
        expect(indicator['promql']).to eq('_on_demand_broker_test_redis_broker_dedicated_high_mem_vm_total_instances{deployment="$deployment",source_id="$source_id"}')
      end

      describe 'documentation' do
        it 'should be not empty' do
          expect(indicator['documentation']['title']).to eq('dedicated-high-mem-vm Instance Count')
        end
      end
    end
  end
end
