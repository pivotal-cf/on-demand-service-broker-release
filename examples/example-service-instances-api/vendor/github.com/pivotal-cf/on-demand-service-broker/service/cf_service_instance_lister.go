// Copyright (C) 2015-Present Pivotal Software, Inc. All rights reserved.

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

package service

import (
	"fmt"
	"log"
	"strings"

	"github.com/pivotal-cf/on-demand-service-broker/cf"

	"github.com/pkg/errors"
)

type CFServiceInstanceLister struct {
	client            CFListerClient
	serviceOfferingID string
	logger            *log.Logger
}

const (
	cfOrgFilterKey   = "cf_org"
	cfSpaceFilterKey = "cf_space"
)

func NewCFServiceInstanceLister(cfClient CFListerClient, serviceOfferingID string, logger *log.Logger) *CFServiceInstanceLister {
	return &CFServiceInstanceLister{serviceOfferingID: serviceOfferingID, client: cfClient, logger: logger}
}

func (l *CFServiceInstanceLister) Instances(filter map[string]string) ([]Instance, error) {
	orgName, spaceName, err := l.filtersFromMap(filter)
	if err != nil {
		return nil, err
	}

	cfInstances, err := l.client.GetServiceInstances(cf.GetInstancesFilter{
		ServiceOfferingID: l.serviceOfferingID,
		OrgName:           orgName,
		SpaceName:         spaceName,
	}, l.logger)
	if err != nil {
		return nil, errors.Wrap(err, "could not retrieve list of instances")
	}

	return l.convertToInstances(cfInstances), nil
}

func (l *CFServiceInstanceLister) filtersFromMap(filter map[string]string) (orgName string, spaceName string, err error) {
	orgName = filter[cfOrgFilterKey]
	spaceName = filter[cfSpaceFilterKey]

	if len(filter) != 0 {
		if orgName == "" {
			return "", "", fmt.Errorf("missing required filter cf_org")
		}
		if spaceName == "" {
			return "", "", fmt.Errorf("missing required filter cf_space")
		}
	}

	if len(filter) > 2 {
		var unknownFilters []string
		for key := range filter {
			if key != cfOrgFilterKey && key != cfSpaceFilterKey {
				unknownFilters = append(unknownFilters, key)
			}
		}
		return "", "", fmt.Errorf("unsupported filters: %s; supported filters are: cf_org, cf_space", strings.Join(unknownFilters, ", "))
	}
	return orgName, spaceName, nil
}

func (l *CFServiceInstanceLister) convertToInstances(cfInstances []cf.Instance) []Instance {
	var instances []Instance
	for _, instance := range cfInstances {
		instances = append(instances, Instance(instance))
	}
	return instances
}
