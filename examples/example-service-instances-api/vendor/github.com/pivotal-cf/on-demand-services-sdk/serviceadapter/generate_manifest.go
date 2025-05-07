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

type GenerateManifestAction struct {
	manifestGenerator ManifestGenerator
}

func NewGenerateManifestAction(manifestGenerator ManifestGenerator) *GenerateManifestAction {
	return &GenerateManifestAction{
		manifestGenerator: manifestGenerator,
	}
}

func (g *GenerateManifestAction) IsImplemented() bool {
	return g.manifestGenerator != nil
}

func (g *GenerateManifestAction) ParseArgs(reader io.Reader, args []string) (InputParams, error) {
	var inputParams InputParams

	if len(args) > 0 { // Legacy positional arguments
		if len(args) < 5 {
			return inputParams, NewMissingArgsError("<service-deployment-JSON> <plan-JSON> <request-params-JSON> <previous-manifest-YAML> <previous-plan-JSON>")
		}

		inputParams = InputParams{
			GenerateManifest: GenerateManifestJSONParams{
				ServiceDeployment: args[0],
				Plan:              args[1],
				RequestParameters: args[2],
				PreviousManifest:  args[3],
				PreviousPlan:      args[4],
			},
			TextOutput: true,
		}
		return inputParams, nil
	}

	data, err := ioutil.ReadAll(reader)
	if err != nil {
		return inputParams, CLIHandlerError{ErrorExitCode, fmt.Sprintf("error reading input params JSON, error: %s", err)}
	}
	if len(data) <= 0 {
		return inputParams, CLIHandlerError{ErrorExitCode, "expecting parameters to be passed via stdin"}
	}

	err = json.Unmarshal(data, &inputParams)
	if err != nil {
		return inputParams, CLIHandlerError{ErrorExitCode, fmt.Sprintf("error unmarshalling input params JSON, error: %s", err)}
	}

	return inputParams, nil
}

type ServiceInstanceUAAClient struct {
	Authorities          string `json:"authorities"`
	AuthorizedGrantTypes string `json:"authorized_grant_types"`
	ClientID             string `json:"client_id"`
	ClientSecret         string `json:"client_secret"`
	Name                 string `json:"name"`
	ResourceIDs          string `json:"resource_ids"`
	Scopes               string `json:"scopes"`
}

func (g *GenerateManifestAction) Execute(inputParams InputParams, outputWriter io.Writer) (err error) {
	var serviceDeployment ServiceDeployment
	generateManifestParams := inputParams.GenerateManifest

	if err = json.Unmarshal([]byte(generateManifestParams.ServiceDeployment), &serviceDeployment); err != nil {
		return errors.Wrap(err, "unmarshalling service deployment")
	}
	if err = serviceDeployment.Validate(); err != nil {
		return errors.Wrap(err, "validating service deployment")
	}

	var plan Plan
	if err = json.Unmarshal([]byte(generateManifestParams.Plan), &plan); err != nil {
		return errors.Wrap(err, "unmarshalling service plan")
	}
	if err = plan.Validate(); err != nil {
		return errors.Wrap(err, "validating service plan")
	}

	var requestParams map[string]interface{}
	if err = json.Unmarshal([]byte(generateManifestParams.RequestParameters), &requestParams); err != nil {
		return errors.Wrap(err, "unmarshalling requestParams")
	}

	var previousManifest *bosh.BoshManifest
	if err = yaml.Unmarshal([]byte(generateManifestParams.PreviousManifest), &previousManifest); err != nil {
		return errors.Wrap(err, "unmarshalling previous manifest")
	}

	var previousPlan *Plan
	if err = json.Unmarshal([]byte(generateManifestParams.PreviousPlan), &previousPlan); err != nil {
		return errors.Wrap(err, "unmarshalling previous service plan")
	}
	if previousPlan != nil {
		if err = previousPlan.Validate(); err != nil {
			return errors.Wrap(err, "validating previous service plan")
		}
	}

	previousSecrets := ManifestSecrets{}
	if generateManifestParams.PreviousSecrets != "" {
		if err = json.Unmarshal([]byte(generateManifestParams.PreviousSecrets), &previousSecrets); err != nil {
			return errors.Wrap(err, "unmarshalling previous secrets")
		}
	}

	var previousConfigs BOSHConfigs
	if generateManifestParams.PreviousConfigs != "" {
		if err = json.Unmarshal([]byte(generateManifestParams.PreviousConfigs), &previousConfigs); err != nil {
			return errors.Wrap(err, "unmarshalling previous configs")
		}
	}

	var serviceInstanceClient *ServiceInstanceUAAClient
	if generateManifestParams.ServiceInstanceUAAClient != "" {
		if err = json.Unmarshal([]byte(generateManifestParams.ServiceInstanceUAAClient), &serviceInstanceClient); err != nil {
			return errors.Wrap(err, "unmarshalling service instance client")
		}
	}

	generateManifestOutput, err := g.manifestGenerator.GenerateManifest(GenerateManifestParams{
		ServiceDeployment:        serviceDeployment,
		Plan:                     plan,
		RequestParams:            requestParams,
		PreviousManifest:         previousManifest,
		PreviousPlan:             previousPlan,
		PreviousSecrets:          previousSecrets,
		PreviousConfigs:          previousConfigs,
		ServiceInstanceUAAClient: serviceInstanceClient,
	})
	if err != nil {
		fmt.Fprintf(outputWriter, err.Error())
		return CLIHandlerError{ErrorExitCode, err.Error()}
	}

	var output []byte
	if inputParams.TextOutput {
		defer handleErr(&err)
		manifestBytes, err := yaml.Marshal(generateManifestOutput.Manifest)
		if err != nil {
			return errors.Wrap(err, "error marshalling bosh manifest")
		}
		output = manifestBytes
	} else {
		defer handleErr(&err)
		manifestBytes, err := yaml.Marshal(generateManifestOutput.Manifest)
		if err != nil {
			return errors.Wrap(err, "error marshalling manifest yaml output")
		}
		marshalledOutput := MarshalledGenerateManifest{
			Manifest:          string(manifestBytes),
			ODBManagedSecrets: generateManifestOutput.ODBManagedSecrets,
			Configs:           generateManifestOutput.Configs,
		}
		output, err = json.Marshal(marshalledOutput)
		if err != nil {
			return errors.Wrap(err, "error marshalling generate-manifest json output")
		}
	}

	fmt.Fprint(outputWriter, string(output))
	return nil
}

func handleErr(err *error) {
	if v := recover(); v != nil {
		*err = errors.New("error marshalling bosh manifest")
	}
}
