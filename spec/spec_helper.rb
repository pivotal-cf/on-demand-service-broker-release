# Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.
# This program and the accompanying materials are made available under the terms of the under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

require 'rspec'
require 'yaml'

require 'bosh/template/renderer'
require 'bosh/template/property_helper'
require 'bosh/template/test'

VALID_MANDATORY_BROKER_PROPERTIES = YAML.
  load_file('spec/fixtures/valid-mandatory-broker-config.yml').
  fetch('instance_groups').
  first.
  fetch('jobs').
  first.
  fetch('properties')

class BoshEmulator
  extend ::Bosh::Template::PropertyHelper

  def self.director_merge(manifest, job_name, links = [])
    broker_job_properties = manifest['instance_groups'][0]['jobs'][0].fetch('properties', {})

    job_spec = YAML.load_file("jobs/#{job_name}/spec")
    spec_properties = job_spec['properties']

    effective_properties = {}
    spec_properties.each_pair do |name, definition|
      copy_property(effective_properties, broker_job_properties, name, definition['default'])
    end

    manifest_links = {}

    spec_links = job_spec['consumes'] || {}
    spec_links.each do |spec_link|
      found = false
      link_name = spec_link['name']
      links.each do |link|
        link.each do |defined_link_name, defined_link_data|
          if link_name == defined_link_name
            manifest_links[link_name] = defined_link_data
            found = true
          end
        end
      end

      if !found && !spec_link['optional']
        raise("Expected #{link_name} link to exist")
      end
    end

    manifest.merge({
      'properties' => effective_properties,
      'links' => manifest_links,
    })
  end
end

RSpec.configure do |c|
  c.disable_monkey_patching!
  c.color = true
  c.order = 'random'
end
