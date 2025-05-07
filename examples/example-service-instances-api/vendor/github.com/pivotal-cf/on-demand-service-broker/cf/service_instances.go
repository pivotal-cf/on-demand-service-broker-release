package cf

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"

	"github.com/pkg/errors"
)

func (c Client) GetServiceInstance(serviceInstanceGUID string, logger *log.Logger) (ServiceInstanceResource, error) {
	path := fmt.Sprintf("/v2/service_instances/%s", serviceInstanceGUID)
	var instance ServiceInstanceResource
	err := c.get(fmt.Sprintf("%s%s", c.url, path), &instance, logger)
	return instance, err
}

func (c Client) GetServiceInstances(filters GetInstancesFilter, logger *log.Logger) ([]Instance, error) {
	plans, err := c.getPlansForServiceID(filters.ServiceOfferingID, logger)
	if err != nil {
		return nil, err
	}

	query, err := c.createQuery(filters, logger)
	switch err.(type) {
	case ResourceNotFoundError:
		return []Instance{}, nil
	case error:
		return nil, err
	}

	return c.getInstances(plans, query, logger)
}

func (c Client) UpgradeServiceInstance(serviceInstanceGUID string, maintenanceInfo MaintenanceInfo, logger *log.Logger) (LastOperation, error) {
	path := fmt.Sprintf(`%s/v2/service_instances/%s?accepts_incomplete=true`, c.url, serviceInstanceGUID)

	requestBody, err := serialiseMaintenanceInfo(maintenanceInfo)
	if err != nil {
		return LastOperation{}, errors.Wrap(err, "failed to serialize request body")
	}

	resp, err := c.put(path, requestBody, logger)
	if err != nil {
		return LastOperation{}, err
	}
	if resp.StatusCode != http.StatusAccepted && resp.StatusCode != http.StatusCreated {
		body, _ := ioutil.ReadAll(resp.Body)
		return LastOperation{},
			fmt.Errorf("unexpected response status %d when upgrading service instance %q; response body %q", resp.StatusCode, serviceInstanceGUID, string(body))
	}

	defer resp.Body.Close()
	body, _ := ioutil.ReadAll(resp.Body)
	var parsedResponse ServiceInstanceResource
	err = json.Unmarshal(body, &parsedResponse)
	if err != nil {
		return LastOperation{}, errors.Wrap(err, "failed to de-serialise the response body")
	}

	return parsedResponse.Entity.LastOperation, nil
}

func (c Client) DeleteServiceInstance(instanceGUID string, logger *log.Logger) error {
	url := fmt.Sprintf(
		"%s/v2/service_instances/%s?accepts_incomplete=true",
		c.url,
		instanceGUID,
	)

	return c.delete(url, logger)
}

func (c Client) GetBindingsForInstance(instanceGUID string, logger *log.Logger) ([]Binding, error) {
	path := fmt.Sprintf(
		"/v2/service_instances/%s/service_bindings?results-per-page=%d",
		instanceGUID,
		defaultPerPage,
	)

	var bindings []Binding
	for path != "" {
		var bindingResponse bindingsResponse
		bindingsURL := fmt.Sprintf("%s%s", c.url, path)

		err := c.get(bindingsURL, &bindingResponse, logger)
		if err != nil {
			return nil, err
		}

		for _, bindingResource := range bindingResponse.Resources {
			bindings = append(bindings, Binding{
				GUID:    bindingResource.Metadata.GUID,
				AppGUID: bindingResource.Entity.AppGUID,
			})
		}

		path = bindingResponse.NextPath
	}

	return bindings, nil
}

func (c Client) GetServiceKeysForInstance(instanceGUID string, logger *log.Logger) ([]ServiceKey, error) {
	path := fmt.Sprintf(
		"/v2/service_instances/%s/service_keys?results-per-page=%d",
		instanceGUID,
		defaultPerPage,
	)

	var serviceKeys []ServiceKey
	for path != "" {
		var serviceKeyResponse serviceKeysResponse
		serviceKeysURL := fmt.Sprintf("%s%s", c.url, path)

		err := c.get(serviceKeysURL, &serviceKeyResponse, logger)
		if err != nil {
			return nil, err
		}

		for _, serviceKeyResource := range serviceKeyResponse.Resources {
			serviceKeys = append(serviceKeys, ServiceKey{
				GUID: serviceKeyResource.Metadata.GUID,
			})
		}

		path = serviceKeyResponse.NextPath
	}

	return serviceKeys, nil
}

func (c Client) createQuery(filters GetInstancesFilter, logger *log.Logger) (string, error) {
	var query string
	if filters.OrgName != "" && filters.SpaceName != "" {
		orgResponse, err := c.getOrganization(filters.OrgName, logger)
		if err != nil {
			return "", err
		}

		orgSpacesURL := orgResponse.Resources[0].Entity["spaces_url"].(string)

		spaceResponse, err := c.getSpace(orgSpacesURL, filters.SpaceName, logger)
		if err != nil {
			return "", err
		}

		query = fmt.Sprintf("&q=space_guid:%s", spaceResponse.Resources[0].Metadata["guid"])
	}
	return query, nil
}

func (c Client) getInstances(plans []ServicePlan, query string, logger *log.Logger) ([]Instance, error) {
	instances := []Instance{}
	for _, plan := range plans {
		path := fmt.Sprintf(
			"/v2/service_plans/%s/service_instances?results-per-page=%d%s",
			plan.Metadata.GUID,
			defaultPerPage,
			query,
		)

		for path != "" {
			var serviceInstancesResp serviceInstancesResponse

			instancesURL := fmt.Sprintf("%s%s", c.url, path)

			err := c.get(instancesURL, &serviceInstancesResp, logger)
			if err != nil {
				return nil, err
			}
			for _, instance := range serviceInstancesResp.ServiceInstances {
				instances = append(
					instances,
					Instance{
						GUID:         instance.Metadata.GUID,
						PlanUniqueID: plan.ServicePlanEntity.UniqueID,
						SpaceGUID:    instance.Entity.SpaceGUID,
					},
				)
			}
			path = serviceInstancesResp.NextPath
		}
	}
	return instances, nil
}

func serialiseMaintenanceInfo(maintenanceInfo MaintenanceInfo) (string, error) {
	var requestBody struct {
		MaintenanceInfo MaintenanceInfo `json:"maintenance_info"`
	}
	requestBody.MaintenanceInfo = maintenanceInfo
	serialisedRequestBody, err := json.Marshal(requestBody)
	if err != nil {
		return "", err
	}
	return string(serialisedRequestBody), nil
}
