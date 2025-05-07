// Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.
// This program and the accompanying materials are made available under the terms of the under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
// Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

package cf

const (
	defaultPerPage = 100

	OperationTypeDelete OperationType = "delete"

	OperationStateSucceeded  OperationState = "succeeded"
	OperationStateFailed     OperationState = "failed"
	OperationStateInProgress OperationState = "in progress"
)

type OperationType string
type OperationState string

type serviceResponse struct {
	pagination
	Services services `json:"resources"`
}

type services []service

func (services services) findByUniqueID(id string) *service {
	for _, service := range services {
		if service.ServiceEntity.UniqueID == id {
			return &service
		}
	}
	return nil
}

type service struct {
	ServiceEntity serviceEntity `json:"entity"`
}

type serviceEntity struct {
	UniqueID        string `json:"unique_id"`
	ServicePlansUrl string `json:"service_plans_url"`
}

type pagination struct {
	TotalResults int    `json:"total_results"`
	TotalPages   int    `json:"total_pages"`
	NextPath     string `json:"next_url"`
}

type infoResponse struct {
	APIVersion    string `json:"api_version"`
	OSBAPIVersion string `json:"osbapi_version"`
}

type ServicePlanResponse struct {
	pagination
	ServicePlans []ServicePlan `json:"resources"`
}

type ServicePlan struct {
	Metadata          Metadata          `json:"metadata"`
	ServicePlanEntity ServicePlanEntity `json:"entity"`
}

type ServicePlanEntity struct {
	UniqueID            string          `json:"unique_id"`
	ServiceInstancesUrl string          `json:"service_instances_url"`
	Name                string          `json:"name"`
	MaintenanceInfo     MaintenanceInfo `json:"maintenance_info"`
}

type MaintenanceInfo struct {
	Version string `json:"version"`
}

type ServiceInstanceResource struct {
	Metadata Metadata              `json:"metadata"`
	Entity   ServiceInstanceEntity `json:"entity"`
}

type Metadata struct {
	GUID string `json:"guid"`
}

type LastOperation struct {
	Type  OperationType  `json:"type"`
	State OperationState `json:"state"`
}

func (o LastOperation) IsDelete() bool {
	return o.Type == OperationTypeDelete
}

type ServiceInstanceEntity struct {
	SpaceGUID       string          `json:"space_guid"`
	ServicePlanURL  string          `json:"service_plan_url"`
	LastOperation   LastOperation   `json:"last_operation"`
	MaintenanceInfo MaintenanceInfo `json:"maintenance_info"`
}

type serviceInstancesResponse struct {
	pagination
	ServiceInstances []ServiceInstanceResource `json:"resources"`
}

func (o LastOperation) OperationFailed() bool {
	return o.State == OperationStateFailed
}

type InstanceState struct {
	PlanID              string
	OperationInProgress bool
}

type Binding struct {
	GUID    string
	AppGUID string
}

type bindingsResponse struct {
	pagination
	Resources []bindingResource
}

type bindingResource struct {
	Metadata Metadata
	Entity   bindingResourceEntity
}

type bindingResourceEntity struct {
	AppGUID             string `json:"app_guid"`
	ServiceInstanceGUID string `json:"service_instance_guid"`
}

type ServiceBroker struct {
	GUID string
	Name string
}

type serviceBrokerResponse struct {
	pagination
	Resources []serviceBrokerResource
}

type serviceBrokerResource struct {
	Metadata Metadata
	Entity   serviceBrokerEntity
}

type serviceBrokerEntity struct {
	Name string
}

type ServiceKey struct {
	GUID string
}

type serviceKeysResponse struct {
	pagination
	Resources []serviceKeyResource
}

type serviceKeyResource struct {
	Metadata Metadata
}

type errorResponse struct {
	Description string `json:"description"`
}

type ServicePlanVisibilityMetadata struct {
	GUID string `json:"guid"`
}

type ServicePlanVisibility struct {
	Metadata ServicePlanVisibilityMetadata `json:"metadata"`
}

type visibilityResponse struct {
	pagination
	Resources []ServicePlanVisibility `json:"resources"`
}

type GetInstancesFilter struct {
	ServiceOfferingID string `json:"service_offering_id"`
	OrgName           string `json:"org_name"`
	SpaceName         string `json:"space_name"`
}
