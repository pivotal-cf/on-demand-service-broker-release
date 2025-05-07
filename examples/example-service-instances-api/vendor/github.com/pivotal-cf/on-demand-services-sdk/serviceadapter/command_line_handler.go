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
	"io"
	"os"
	"sort"

	"strings"

	"path/filepath"
)

// CommandLineHandler contains all of the implementers required for the service adapter interface
type CommandLineHandler struct {
	ManifestGenerator     ManifestGenerator
	Binder                Binder
	DashboardURLGenerator DashboardUrlGenerator
	SchemaGenerator       SchemaGenerator
}

type CLIHandlerError struct {
	ExitCode int
	Message  string
}

func (e CLIHandlerError) Error() string {
	return e.Message
}

// Deprecated: Use HandleCLI method of a CommandLineHandler
//
// HandleCommandLineInvocation constructs a CommandLineHandler based on minimal
// service adapter interface handlers and runs HandleCLI based on the
// arguments provided
func HandleCommandLineInvocation(args []string, manifestGenerator ManifestGenerator, binder Binder, dashboardUrlGenerator DashboardUrlGenerator) {
	handler := CommandLineHandler{
		ManifestGenerator:     manifestGenerator,
		Binder:                binder,
		DashboardURLGenerator: dashboardUrlGenerator,
	}
	HandleCLI(args, handler)
}

// HandleCLI calls the correct Service Adapter handler method based on command
// line arguments. The first argument at the command line should be one of:
// generate-manifest, create-binding, delete-binding, dashboard-url.
func HandleCLI(args []string, handler CommandLineHandler) {
	err := handler.Handle(args, os.Stdout, os.Stderr, os.Stdin)
	switch e := err.(type) {
	case nil:
	case CLIHandlerError:
		failWithCode(e.ExitCode, err.Error())
	default:
		failWithCode(ErrorExitCode, err.Error())
	}
}

// Handle executes required action and returns an error. Writes responses to the writer provided
func (h CommandLineHandler) Handle(args []string, outputWriter, errorWriter io.Writer, inputParamsReader io.Reader) error {
	actions := map[string]Action{
		"generate-manifest":     NewGenerateManifestAction(h.ManifestGenerator),
		"create-binding":        NewCreateBindingAction(h.Binder),
		"delete-binding":        NewDeleteBindingAction(h.Binder),
		"dashboard-url":         NewDashboardUrlAction(h.DashboardURLGenerator),
		"generate-plan-schemas": NewGeneratePlanSchemasAction(h.SchemaGenerator, errorWriter),
	}
	supportedCommands := h.generateSupportedCommandsMessage(actions)

	if len(args) < 2 {
		return CLIHandlerError{
			ErrorExitCode,
			fmt.Sprintf("the following commands are supported: %s", supportedCommands),
		}
	}

	action, arguments := args[1], args[2:]
	fmt.Fprintf(errorWriter, "[odb-sdk] handling %s\n", action)

	var inputParams InputParams

	var err error
	ac, ok := actions[action]
	if !ok {
		failWithCode(ErrorExitCode, fmt.Sprintf("unknown subcommand: %s. The following commands are supported: %s", args[1], supportedCommands))
		return nil
	}

	if !ac.IsImplemented() {
		return CLIHandlerError{NotImplementedExitCode, fmt.Sprintf("%s not implemented", action)}
	}

	if inputParams, err = ac.ParseArgs(inputParamsReader, arguments); err != nil {
		switch e := err.(type) {
		case MissingArgsError:
			return missingArgsError(args, e.Error())
		default:
			return e
		}
	}
	return ac.Execute(inputParams, outputWriter)
}

func failWithMissingArgsError(args []string, argumentNames string) {
	failWithCode(
		ErrorExitCode,
		fmt.Sprintf(
			"Missing arguments for %s. Usage: %s %s %s",
			args[1],
			filepath.Base(args[0]),
			args[1],
			argumentNames,
		),
	)
}

func incorrectArgsError(cmd string) error {
	return CLIHandlerError{
		ErrorExitCode,
		fmt.Sprintf("Incorrect arguments for %s", cmd),
	}
}

func missingArgsError(args []string, argumentNames string) error {
	return CLIHandlerError{
		ExitCode: ErrorExitCode,
		Message: fmt.Sprintf(
			"Missing arguments for %s. Usage: %s %s %s",
			args[1],
			filepath.Base(args[0]),
			args[1],
			argumentNames,
		),
	}
}

func (h CommandLineHandler) generateSupportedCommandsMessage(actions map[string]Action) string {
	commands := []string{}
	for key, action := range actions {
		if action.IsImplemented() {
			commands = append(commands, key)
		}
	}

	sort.Strings(commands)
	return strings.Join(commands, ", ")
}

func (h CommandLineHandler) must(err error, msg string) {
	if err != nil {
		fail("error %s: %s\n", msg, err)
	}
}

func (h CommandLineHandler) mustNot(err error, msg string) {
	h.must(err, msg)
}

func fail(format string, params ...interface{}) {
	failWithCode(ErrorExitCode, format, params...)
}

func failWithCode(code int, format string, params ...interface{}) {
	fmt.Fprintf(os.Stderr, fmt.Sprintf("[odb-sdk] %s\n", format), params...)
	os.Exit(code)
}

func failWithCodeAndNotifyUser(code int, format string) {
	fmt.Fprintf(os.Stdout, fmt.Sprintf("%s", format))
	os.Exit(code)
}
