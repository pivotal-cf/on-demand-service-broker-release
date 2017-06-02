# Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.
# This program and the accompanying materials are made available under the terms of the under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

require 'rspec'
require 'rspec/its'
require 'bosh/template/property_helper'
require 'bosh/template/renderer'
require 'yaml'

ROOT = File.expand_path('..', __dir__)

class BoshEmulator
  extend ::Bosh::Template::PropertyHelper

  def self.director_merge(manifest, job_name)
    manifest_properties = manifest['properties']

    job_spec = YAML.load_file("jobs/#{job_name}/spec")
    spec_properties = job_spec['properties']

    effective_properties = {}
    spec_properties.each_pair do |name, definition|
      copy_property(effective_properties, manifest_properties, name, definition['default'])
    end

    manifest.merge({'properties' => effective_properties})
  end
end

RSpec.configure do |c|
  c.disable_monkey_patching!
  c.color = true
  c.full_backtrace = true
  c.order = 'random'
end
