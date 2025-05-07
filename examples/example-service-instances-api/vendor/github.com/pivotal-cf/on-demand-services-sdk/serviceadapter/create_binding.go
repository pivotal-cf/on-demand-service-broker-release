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

type CreateBindingAction struct {
	bindingCreator Binder
}

func NewCreateBindingAction(binder Binder) *CreateBindingAction {
	action := CreateBindingAction{
		bindingCreator: binder,
	}
	return &action
}

func (a *CreateBindingAction) IsImplemented() bool {
	return a.bindingCreator != nil
}

func (a *CreateBindingAction) ParseArgs(reader io.Reader, args []string) (InputParams, error) {
	var inputParams InputParams

	if len(args) > 0 {
		if len(args) < 4 {
			return inputParams, NewMissingArgsError("<binding-ID> <bosh-VMs-JSON> <manifest-YAML> <request-params-JSON>")
		}

		inputParams = InputParams{
			CreateBinding: CreateBindingJSONParams{
				BindingId:         args[0],
				BoshVms:           args[1],
				Manifest:          args[2],
				RequestParameters: args[3],
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

func (a *CreateBindingAction) Execute(inputParams InputParams, outputWriter io.Writer) error {
	var boshVMs map[string][]string
	if err := json.Unmarshal([]byte(inputParams.CreateBinding.BoshVms), &boshVMs); err != nil {
		return errors.Wrap(err, "unmarshalling BOSH VMs")
	}

	var manifest bosh.BoshManifest
	if err := yaml.Unmarshal([]byte(inputParams.CreateBinding.Manifest), &manifest); err != nil {
		return errors.Wrap(err, "unmarshalling manifest YAML")
	}

	var reqParams map[string]interface{}
	if err := json.Unmarshal([]byte(inputParams.CreateBinding.RequestParameters), &reqParams); err != nil {
		return errors.Wrap(err, "unmarshalling request binding parameters")
	}

	var secrets ManifestSecrets
	if inputParams.CreateBinding.Secrets != "" {
		if err := json.Unmarshal([]byte(inputParams.CreateBinding.Secrets), &secrets); err != nil {
			return errors.Wrap(err, "unmarshalling secrets")
		}
	}

	var dnsAddresses DNSAddresses
	if inputParams.CreateBinding.DNSAddresses != "" {
		if err := json.Unmarshal([]byte(inputParams.CreateBinding.DNSAddresses), &dnsAddresses); err != nil {
			return errors.Wrap(err, "unmarshalling DNS addresses")
		}
	}

	params := CreateBindingParams{
		BindingID:          inputParams.CreateBinding.BindingId,
		DeploymentTopology: boshVMs,
		Manifest:           manifest,
		RequestParams:      reqParams,
		Secrets:            secrets,
		DNSAddresses:       dnsAddresses,
	}
	binding, err := a.bindingCreator.CreateBinding(params)
	if err != nil {
		fmt.Fprintf(outputWriter, err.Error())
		switch err := err.(type) {
		case BindingAlreadyExistsError:
			return CLIHandlerError{BindingAlreadyExistsErrorExitCode, err.Error()}
		case AppGuidNotProvidedError:
			return CLIHandlerError{AppGuidNotProvidedErrorExitCode, err.Error()}
		default:
			return CLIHandlerError{ErrorExitCode, err.Error()}
		}
	}

	if err := json.NewEncoder(outputWriter).Encode(binding); err != nil {
		return errors.Wrap(err, "error marshalling binding")
	}

	return nil
}
