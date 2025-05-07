package cf

import (
	"fmt"
	"github.com/pkg/errors"
	"log"
)

func (c Client) GetPlanByServiceInstanceGUID(serviceGUID string, logger *log.Logger) (ServicePlan, error) {
	servicePlanResponse := ServicePlanResponse{}
	err := c.get(fmt.Sprintf("%s%s", c.url, "/v2/service_plans?q=service_instance_guid:"+serviceGUID), &servicePlanResponse, logger)
	if err != nil {
		return ServicePlan{}, errors.Wrap(err, fmt.Sprintf("failed to retrieve plan for service %q", serviceGUID))
	}
	return servicePlanResponse.ServicePlans[0], nil
}
