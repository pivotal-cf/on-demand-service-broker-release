package serviceadapter

import (
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"

	"github.com/pivotal-cf/on-demand-services-sdk/bosh"
	"github.com/pkg/errors"
	yaml "gopkg.in/yaml.v2"
)

type DashboardUrlAction struct {
	dashboardUrlGenerator DashboardUrlGenerator
}

func NewDashboardUrlAction(dashboardUrlGenerator DashboardUrlGenerator) *DashboardUrlAction {
	return &DashboardUrlAction{
		dashboardUrlGenerator: dashboardUrlGenerator,
	}
}

func (d *DashboardUrlAction) IsImplemented() bool {
	return d.dashboardUrlGenerator != nil
}

func (d *DashboardUrlAction) ParseArgs(reader io.Reader, args []string) (InputParams, error) {
	var inputParams InputParams

	if len(args) > 0 {
		if len(args) < 3 {
			return inputParams, NewMissingArgsError("<instance-ID> <plan-JSON> <manifest-YAML>")
		}

		inputParams = InputParams{
			DashboardUrl: DashboardUrlJSONParams{
				InstanceId: args[0],
				Plan:       args[1],
				Manifest:   args[2],
			},
		}
		return inputParams, nil
	}

	data, err := ioutil.ReadAll(reader)
	if err != nil {
		return inputParams, CLIHandlerError{ErrorExitCode, fmt.Sprintf("error reading input params JSON, error: %s", err)}
	}

	if len(data) > 0 {
		err = json.Unmarshal(data, &inputParams)
		if err != nil {
			return inputParams, CLIHandlerError{ErrorExitCode, fmt.Sprintf("error unmarshalling input params JSON, error: %s", err)}
		}

		return inputParams, err
	}

	return inputParams, CLIHandlerError{ErrorExitCode, "expecting parameters to be passed via stdin"}
}

func (d *DashboardUrlAction) Execute(inputParams InputParams, outputWriter io.Writer) error {
	var plan Plan
	if err := json.Unmarshal([]byte(inputParams.DashboardUrl.Plan), &plan); err != nil {
		return errors.Wrap(err, "unmarshalling service plan")
	}
	if err := plan.Validate(); err != nil {
		return errors.Wrap(err, "validating service plan")
	}

	var manifest bosh.BoshManifest
	if err := yaml.Unmarshal([]byte(inputParams.DashboardUrl.Manifest), &manifest); err != nil {
		return errors.Wrap(err, "unmarshalling manifest YAML")
	}

	params := DashboardUrlParams{
		InstanceID: inputParams.DashboardUrl.InstanceId,
		Plan:       plan,
		Manifest:   manifest,
	}
	dashboardUrl, err := d.dashboardUrlGenerator.DashboardUrl(params)
	if err != nil {
		fmt.Fprintf(outputWriter, err.Error())
		return CLIHandlerError{ErrorExitCode, err.Error()}
	}

	if err := json.NewEncoder(outputWriter).Encode(dashboardUrl); err != nil {
		return errors.Wrap(err, "marshalling dashboardUrl")
	}

	return nil
}
