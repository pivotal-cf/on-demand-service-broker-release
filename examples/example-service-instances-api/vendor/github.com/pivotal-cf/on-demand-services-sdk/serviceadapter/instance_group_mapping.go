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

package serviceadapter

import (
	"fmt"
	"strings"

	"github.com/pivotal-cf/on-demand-services-sdk/bosh"
)

func GenerateInstanceGroupsWithNoProperties(
	instanceGroups []InstanceGroup,
	serviceReleases ServiceReleases,
	stemcell string,
	deploymentInstanceGroupsToJobs map[string][]string,
) ([]bosh.InstanceGroup, error) {

	if len(instanceGroups) == 0 {
		return nil, fmt.Errorf("no instance groups provided")
	}

	boshInstanceGroups := []bosh.InstanceGroup{}
	for _, instanceGroup := range instanceGroups {
		if _, ok := deploymentInstanceGroupsToJobs[instanceGroup.Name]; !ok {
			continue
		}

		networks := []bosh.Network{}

		for _, network := range instanceGroup.Networks {
			networks = append(networks, bosh.Network{Name: network})
		}

		boshJobs, err := generateJobsForInstanceGroup(instanceGroup.Name, deploymentInstanceGroupsToJobs, serviceReleases)
		if err != nil {
			return nil, err
		}

		var migrations []bosh.Migration

		if len(instanceGroup.MigratedFrom) > 0 {
			for _, migration := range instanceGroup.MigratedFrom {
				migrations = append(migrations, bosh.Migration{Name: migration.Name})
			}
		}

		boshInstanceGroup := bosh.InstanceGroup{
			Name:               instanceGroup.Name,
			Instances:          instanceGroup.Instances,
			Stemcell:           stemcell,
			VMType:             instanceGroup.VMType,
			VMExtensions:       instanceGroup.VMExtensions,
			PersistentDiskType: instanceGroup.PersistentDiskType,
			AZs:                instanceGroup.AZs,
			Networks:           networks,
			Jobs:               boshJobs,
			Lifecycle:          instanceGroup.Lifecycle,
			MigratedFrom:       migrations,
		}
		boshInstanceGroups = append(boshInstanceGroups, boshInstanceGroup)
	}
	return boshInstanceGroups, nil
}

func FindReleaseForJob(jobName string, releases ServiceReleases) (ServiceRelease, error) {
	releasesThatMentionJob := []ServiceRelease{}
	for _, release := range releases {
		for _, job := range release.Jobs {
			if job == jobName {
				releasesThatMentionJob = append(releasesThatMentionJob, release)
			}
		}
	}

	if len(releasesThatMentionJob) == 0 {
		return ServiceRelease{}, fmt.Errorf("job '%s' not provided", jobName)
	}

	if len(releasesThatMentionJob) > 1 {
		releaseNames := []string{}
		for _, release := range releasesThatMentionJob {
			releaseNames = append(releaseNames, release.Name)
		}
		return ServiceRelease{}, fmt.Errorf("job '%s' provided %d times, by %s", jobName, len(releasesThatMentionJob), strings.Join(releaseNames, ", "))
	}

	return releasesThatMentionJob[0], nil
}

func generateJobsForInstanceGroup(instanceGroupName string, deploymentInstanceGroupsToJobs map[string][]string, serviceReleases ServiceReleases) ([]bosh.Job, error) {
	boshJobs := []bosh.Job{}
	for _, job := range deploymentInstanceGroupsToJobs[instanceGroupName] {
		release, err := FindReleaseForJob(job, serviceReleases)
		if err != nil {
			return nil, err
		}

		boshJobs = append(boshJobs, bosh.Job{Name: job, Release: release.Name})
	}
	return boshJobs, nil
}
