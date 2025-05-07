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

type DeleteBindingAction struct {
	unbinder Binder
}

func NewDeleteBindingAction(unbinder Binder) *DeleteBindingAction {
	return &DeleteBindingAction{
		unbinder: unbinder,
	}
}

func (d *DeleteBindingAction) IsImplemented() bool {
	return d.unbinder != nil
}

func (d *DeleteBindingAction) ParseArgs(reader io.Reader, args []string) (InputParams, error) {
	var inputParams InputParams

	if len(args) > 0 {
		if len(args) < 4 {
			return inputParams, NewMissingArgsError("<binding-ID> <bosh-VMs-JSON> <manifest-YAML> <request-params-JSON>")
		}

		inputParams = InputParams{
			DeleteBinding: DeleteBindingJSONParams{
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

func (d *DeleteBindingAction) Execute(inputParams InputParams, outputWriter io.Writer) error {
	var boshVMs map[string][]string
	if err := json.Unmarshal([]byte(inputParams.DeleteBinding.BoshVms), &boshVMs); err != nil {
		return errors.Wrap(err, "unmarshalling BOSH VMs")
	}

	var manifest bosh.BoshManifest
	if err := yaml.Unmarshal([]byte(inputParams.DeleteBinding.Manifest), &manifest); err != nil {
		return errors.Wrap(err, "unmarshalling manifest YAML")
	}

	var reqParams map[string]interface{}
	if err := json.Unmarshal([]byte(inputParams.DeleteBinding.RequestParameters), &reqParams); err != nil {
		return errors.Wrap(err, "unmarshalling request binding parameters")
	}

	var secrets ManifestSecrets
	if inputParams.DeleteBinding.Secrets != "" {
		if err := json.Unmarshal([]byte(inputParams.DeleteBinding.Secrets), &secrets); err != nil {
			return errors.Wrap(err, "unmarshalling secrets")
		}
	}

	var dnsAddresses DNSAddresses
	if inputParams.DeleteBinding.DNSAddresses != "" {
		if err := json.Unmarshal([]byte(inputParams.DeleteBinding.DNSAddresses), &dnsAddresses); err != nil {
			return errors.Wrap(err, "unmarshalling DNS addresses")
		}
	}

	params := DeleteBindingParams{
		BindingID:          inputParams.DeleteBinding.BindingId,
		DeploymentTopology: boshVMs,
		Manifest:           manifest,
		RequestParams:      reqParams,
		Secrets:            secrets,
		DNSAddresses:       dnsAddresses,
	}
	err := d.unbinder.DeleteBinding(params)
	if err != nil {
		fmt.Fprintf(outputWriter, err.Error())
		switch err.(type) {
		case BindingNotFoundError:
			return CLIHandlerError{BindingNotFoundErrorExitCode, err.Error()}
		default:
			return CLIHandlerError{ErrorExitCode, err.Error()}
		}
	}

	return nil
}
