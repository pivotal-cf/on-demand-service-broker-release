// Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.

// This program and the accompanying materials are made available under
// the terms of the under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at

// http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package bosh

type Job struct {
	Name                      string                     `yaml:"name"`
	Release                   string                     `yaml:"release"`
	Provides                  map[string]ProvidesLink    `yaml:"provides,omitempty"`
	Consumes                  map[string]interface{}     `yaml:"consumes,omitempty"`
	CustomProviderDefinitions []CustomProviderDefinition `yaml:"custom_provider_definitions,omitempty"`
	Properties                map[string]interface{}     `yaml:"properties,omitempty"`
}

type CustomProviderDefinition struct {
	Name       string   `yaml:"name"`
	Type       string   `yaml:"type"`
	Properties []string `yaml:"properties,omitempty"`
}

type ProvidesLink struct {
	As      string  `yaml:"as,omitempty"`
	Shared  bool    `yaml:"shared,omitempty"`
	Aliases []Alias `yaml:"aliases,omitempty"`
}

type Alias struct {
	Domain             string `yaml:"domain"`
	HealthFilter       string `yaml:"health_filter,omitempty"`
	InitialHealthCheck string `yaml:"initial_health_check,omitempty"`
	PlaceHolderType    string `yaml:"placeholder_type,omitempty"`
}

type ConsumesLink struct {
	From       string `yaml:"from,omitempty"`
	Deployment string `yaml:"deployment,omitempty"`
	Network    string `yaml:"network,omitempty"`
}

func (j Job) AddCustomProviderDefinition(name, providerType string, properties []string) Job {
	if j.CustomProviderDefinitions == nil {
		j.CustomProviderDefinitions = []CustomProviderDefinition{}
	}
	j.CustomProviderDefinitions = append(
		j.CustomProviderDefinitions,
		CustomProviderDefinition{Name: name, Type: providerType, Properties: properties},
	)
	return j
}

func (j Job) AddSharedProvidesLink(name string) Job {
	return j.addProvidesLink(name, ProvidesLink{Shared: true})
}

func (j Job) AddProvidesLinkWithAliases(name string, aliases []Alias) Job {
	return j.addProvidesLink(name, ProvidesLink{Aliases: aliases})
}

func (j Job) AddConsumesLink(name, fromJob string) Job {
	return j.addConsumesLink(name, ConsumesLink{From: fromJob})
}

func (j Job) AddCrossDeploymentConsumesLink(name, fromJob string, deployment string) Job {
	return j.addConsumesLink(name, ConsumesLink{From: fromJob, Deployment: deployment})
}

func (j Job) AddNullifiedConsumesLink(name string) Job {
	return j.addConsumesLink(name, "nil")
}

func (j Job) addConsumesLink(name string, value interface{}) Job {
	if j.Consumes == nil {
		j.Consumes = map[string]interface{}{}
	}
	j.Consumes[name] = value
	return j
}

func (j Job) addProvidesLink(name string, providesLink ProvidesLink) Job {
	if j.Provides == nil {
		j.Provides = map[string]ProvidesLink{}
	}
	j.Provides[name] = providesLink
	return j
}
