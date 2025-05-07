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

import (
	"fmt"
	"regexp"
)

type BoshManifest struct {
	Addons         []Addon         `yaml:"addons,omitempty" json:"addons"`
	Name           string          `yaml:"name" json:"name"`
	Releases       []Release       `yaml:"releases" json:"releases"`
	Stemcells      []Stemcell      `yaml:"stemcells" json:"stemcells"`
	InstanceGroups []InstanceGroup `yaml:"instance_groups" json:"instance_groups"`
	Update         *Update         `yaml:"update" json:"update"`
	// DEPRECATED: BOSH deprecated deployment level "properties". Use Job properties instead.
	Properties map[string]interface{} `yaml:"properties,omitempty" json:"properties,omitempty"`
	Variables  []Variable             `yaml:"variables,omitempty" json:"variables,omitempty"`
	Tags       map[string]interface{} `yaml:"tags,omitempty" json:"tags,omitempty"`
	Features   BoshFeatures           `yaml:"features,omitempty" json:"features,omitempty"`
}

type BoshFeatures struct {
	UseDNSAddresses      *bool                  `yaml:"use_dns_addresses,omitempty"`
	RandomizeAZPlacement *bool                  `yaml:"randomize_az_placement,omitempty"`
	UseShortDNSAddresses *bool                  `yaml:"use_short_dns_addresses,omitempty"`
	ExtraFeatures        map[string]interface{} `yaml:"extra_features,inline"`
}

func BoolPointer(val bool) *bool {
	return &val
}

type PlacementRuleStemcell struct {
	OS string `yaml:"os"`
}

type PlacementRule struct {
	Stemcell       []PlacementRuleStemcell `yaml:"stemcell,omitempty"`
	Deployments    []string                `yaml:"deployments,omitempty"`
	Jobs           []Job                   `yaml:"jobs,omitempty"`
	InstanceGroups []string                `yaml:"instance_groups,omitempty"`
	Networks       []string                `yaml:"networks,omitempty"`
	Teams          []string                `yaml:"teams,omitempty"`
}

type Addon struct {
	Name    string        `yaml:"name"`
	Jobs    []Job         `yaml:"jobs"`
	Include PlacementRule `yaml:"include,omitempty"`
	Exclude PlacementRule `yaml:"exclude,omitempty"`
}

// Variable represents a variable in the `variables` block of a BOSH manifest
type Variable struct {
	Name       string                 `yaml:"name"`
	Type       string                 `yaml:"type"`
	UpdateMode string                 `yaml:"update_mode,omitempty"`
	Options    map[string]interface{} `yaml:"options,omitempty"`

	// Variables of type `certificate` can optionally be configured with a
	// `consumes` block, so generated certificates can be created with automatic
	// BOSH DNS records in their Common Name and/or Subject Alternative Names.
	//
	// Should be used in conjunction to the `custom_provider_definitions` block in
	// a Job.
	//
	// Requires BOSH v267+
	Consumes *VariableConsumes `yaml:"consumes,omitempty"`
}

type VariableConsumes struct {
	AlternativeName VariableConsumesLink `yaml:"alternative_name,omitempty"`
	CommonName      VariableConsumesLink `yaml:"common_name,omitempty"`
}

type VariableConsumesLink struct {
	From       string                 `yaml:"from"`
	Properties map[string]interface{} `yaml:"properties,omitempty"`
}

type Release struct {
	Name    string `yaml:"name"`
	Version string `yaml:"version"`
}

type Stemcell struct {
	Alias   string `yaml:"alias"`
	OS      string `yaml:"os"`
	Version string `yaml:"version"`
}

type InstanceGroup struct {
	Name               string    `yaml:"name,omitempty"`
	Lifecycle          string    `yaml:"lifecycle,omitempty"`
	Instances          int       `yaml:"instances"`
	Jobs               []Job     `yaml:"jobs,omitempty"`
	VMType             string    `yaml:"vm_type"`
	VMExtensions       []string  `yaml:"vm_extensions,omitempty"`
	Stemcell           string    `yaml:"stemcell"`
	PersistentDiskType string    `yaml:"persistent_disk_type,omitempty"`
	AZs                []string  `yaml:"azs,omitempty"`
	Networks           []Network `yaml:"networks"`
	// DEPRECATED: BOSH deprecated instance_group level "properties". Use Job properties instead.
	Properties   map[string]interface{} `yaml:"properties,omitempty"`
	MigratedFrom []Migration            `yaml:"migrated_from,omitempty"`
	Env          map[string]interface{} `yaml:"env,omitempty"`
	Update       *Update                `yaml:"update,omitempty"`
}

type Migration struct {
	Name string `yaml:"name"`
}

type Network struct {
	Name      string   `yaml:"name"`
	StaticIPs []string `yaml:"static_ips,omitempty"`
	Default   []string `yaml:"default,omitempty"`
}

// MaxInFlightValue holds a value of one of these types:
//
//	int, for YAML numbers
//	string, for YAML string literals representing a percentage
type MaxInFlightValue interface{}

type UpdateStrategy string

const (
	SerialUpdate   UpdateStrategy = "serial"
	ParallelUpdate UpdateStrategy = "parallel"
)

type Update struct {
	Canaries        int              `yaml:"canaries"`
	CanaryWatchTime string           `yaml:"canary_watch_time"`
	UpdateWatchTime string           `yaml:"update_watch_time"`
	MaxInFlight     MaxInFlightValue `yaml:"max_in_flight"`
	Serial          *bool            `yaml:"serial,omitempty"`
	VmStrategy      string           `yaml:"vm_strategy,omitempty"`
	// See bosh.SerialUpdate and bosh.ParallelUpdate
	InitialDeployAZUpdateStrategy UpdateStrategy `yaml:"initial_deploy_az_update_strategy,omitempty"`
}

type updateAlias Update

func (u *Update) MarshalYAML() (interface{}, error) {
	if u != nil {
		if err := ValidateMaxInFlight(u.MaxInFlight); err != nil {
			return []byte{}, err
		}
	}

	return (*updateAlias)(u), nil
}

func (u *Update) UnmarshalYAML(unmarshal func(interface{}) error) error {
	err := unmarshal((*updateAlias)(u))
	if err != nil {
		return err
	}

	if u != nil {
		return ValidateMaxInFlight(u.MaxInFlight)
	}

	return nil
}

func ValidateMaxInFlight(m MaxInFlightValue) error {
	switch v := m.(type) {
	case string:
		matched, err := regexp.Match(`\d+%`, []byte(v))
		if !matched || err != nil {
			return fmt.Errorf("MaxInFlight must be either an integer or a percentage. Got %v", v)
		}
	case int:
	default:
		return fmt.Errorf("MaxInFlight must be either an integer or a percentage. Got %v", v)
	}

	return nil
}
