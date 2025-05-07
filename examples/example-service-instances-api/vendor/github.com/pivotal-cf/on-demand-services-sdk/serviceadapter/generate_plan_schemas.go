package serviceadapter

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"io/ioutil"

	"github.com/pkg/errors"
)

type GeneratePlanSchemasAction struct {
	schemaGenerator SchemaGenerator
	errorWriter     io.Writer
}

func NewGeneratePlanSchemasAction(schemaGenerator SchemaGenerator, errorWriter io.Writer) *GeneratePlanSchemasAction {
	a := GeneratePlanSchemasAction{
		schemaGenerator: schemaGenerator,
		errorWriter:     errorWriter,
	}
	return &a
}

func (g *GeneratePlanSchemasAction) IsImplemented() bool {
	return g.schemaGenerator != nil
}

func (g *GeneratePlanSchemasAction) ParseArgs(reader io.Reader, args []string) (InputParams, error) {
	var inputParams InputParams

	if len(args) > 0 {
		fs := flag.NewFlagSet("", flag.ContinueOnError)
		planJSON := fs.String("plan-json", "", "Plan JSON")
		fs.SetOutput(g.errorWriter)

		err := fs.Parse(args)
		if err != nil {
			return inputParams, err
		}

		if *planJSON == "" {
			return inputParams, NewMissingArgsError("-plan-json <plan-JSON>")
		}

		inputParams = InputParams{
			TextOutput: true,
			GeneratePlanSchemas: GeneratePlanSchemasJSONParams{
				Plan: *planJSON,
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

func (g *GeneratePlanSchemasAction) Execute(inputParams InputParams, outputWriter io.Writer) (err error) {
	var plan Plan
	if err := json.Unmarshal([]byte(inputParams.GeneratePlanSchemas.Plan), &plan); err != nil {
		return errors.Wrap(err, "error unmarshalling plan JSON")
	}
	if err := plan.Validate(); err != nil {
		return errors.Wrap(err, "error validating plan JSON")
	}
	schema, err := g.schemaGenerator.GeneratePlanSchema(GeneratePlanSchemaParams{Plan: plan})
	if err != nil {
		fmt.Fprintf(outputWriter, err.Error())
		return CLIHandlerError{ErrorExitCode, err.Error()}
	}

	err = json.NewEncoder(outputWriter).Encode(schema)
	if err != nil {
		return errors.Wrap(err, "error marshalling plan schema")
	}

	return nil
}
