#!/usr/bin/env ruby

# Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.
# This program and the accompanying materials are made available under the terms of the under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.


`cf api #{ENV.fetch('CF_URL')} --skip-ssl-validation`
`cf auth #{ENV.fetch('CF_USERNAME')} #{ENV.fetch('CF_PASSWORD')}`

def is_odb?(service_offering)
  [/^\w+-dev\d$/, /^\w+-acceptance$/, /^\w+-ci$/].each do |r|
    if r =~ service_offering
      return true
    end
  end

  false
end

services = {}
`cf orgs`.lines.drop(3).map(&:strip).each do |org|
  `cf target -o #{org}`
  `cf spaces`.lines.drop(3).map(&:strip).select { |space| space != 'No spaces found' }.each do |space|
    `cf target -s #{space}`
    `cf services`.lines.drop(4).each do |service_line|
      service_fields = service_line.split(/\s+/)

      if is_odb?(service_fields[1])
        services[service_fields[0]] = `cf service #{service_fields[0]} --guid`.strip
      end
    end
  end
end

bosh_deployments = `bosh deployments`
orphans = services.select { |instance_name, guid| !bosh_deployments.include? guid }

orphan_names = orphans.map { |instance_name, guid| instance_name }
if !orphan_names.empty?
  puts "orphans! #{orphan_names}"
  exit 1
end

puts "no orphans found"
