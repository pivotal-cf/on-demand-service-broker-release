// Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.
// This program and the accompanying materials are made available under the terms of the under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
// Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

package cf

import (
	"crypto/x509"
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"time"

	"bytes"

	"github.com/craigfurman/herottp"
)

type httpJsonClient struct {
	client            *herottp.Client
	AuthHeaderBuilder AuthHeaderBuilder
}

//go:generate go run github.com/maxbrunsfeld/counterfeiter/v6 -generate
//counterfeiter:generate -o fakes/fake_auth_header_builder.go . AuthHeaderBuilder
type AuthHeaderBuilder interface {
	AddAuthHeader(request *http.Request, logger *log.Logger) error
}

func (w httpJsonClient) get(path string, body interface{}, logger *log.Logger) error {
	req, err := http.NewRequest(http.MethodGet, path, nil)
	if err != nil {
		return err
	}

	err = w.AuthHeaderBuilder.AddAuthHeader(req, logger)
	if err != nil {
		return err
	}

	logger.Printf(fmt.Sprintf("GET %s", path))

	response, err := w.client.Do(req)
	if err != nil {
		return err
	}
	return w.readResponse(response, body)
}

func (c httpJsonClient) post(path string, reqBody io.Reader, logger *log.Logger) (*http.Response, error) {
	req, err := http.NewRequest(http.MethodPost, path, reqBody)
	if err != nil {
		return nil, err
	}

	err = c.AuthHeaderBuilder.AddAuthHeader(req, logger)
	if err != nil {
		return nil, err
	}
	req.Header.Add("Content-Type", "application/json")

	logger.Printf(fmt.Sprintf("POST %s", path))

	resp, err := c.client.Do(req)
	if err != nil {
		return nil, err
	}

	return resp, err
}

func (c httpJsonClient) put(path, reqBody string, logger *log.Logger) (*http.Response, error) {
	req, err := http.NewRequest(http.MethodPut, path, bytes.NewBufferString(reqBody))
	if err != nil {
		return nil, err
	}

	err = c.AuthHeaderBuilder.AddAuthHeader(req, logger)
	if err != nil {
		return nil, err
	}
	req.Header.Add("Content-Type", "application/x-www-form-urlencoded")

	logger.Printf(fmt.Sprintf("PUT %s", path))

	return c.client.Do(req)
}

func (c httpJsonClient) delete(path string, logger *log.Logger) error {
	req, err := http.NewRequest(http.MethodDelete, path, nil)
	if err != nil {
		return err
	}

	err = c.AuthHeaderBuilder.AddAuthHeader(req, logger)
	if err != nil {
		return err
	}

	req.Header.Add("Content-Type", "application/x-www-form-urlencoded")

	logger.Printf(fmt.Sprintf("DELETE %s", path))

	resp, err := c.client.Do(req)
	if err != nil {
		return err
	}

	switch resp.StatusCode {
	case http.StatusNoContent, http.StatusAccepted, http.StatusNotFound:
		return nil
	}

	body, _ := ioutil.ReadAll(resp.Body)
	return fmt.Errorf("Unexpected reponse status %d, %q", resp.StatusCode, string(body))
}

func (w httpJsonClient) readResponse(response *http.Response, obj interface{}) error {
	defer response.Body.Close()
	rawBody, _ := ioutil.ReadAll(response.Body)
	switch response.StatusCode {
	case http.StatusOK:
		if string(rawBody) == "{}" {
			return NewInvalidResponseError("Empty response body")
		}
		err := json.Unmarshal(rawBody, &obj)
		if err != nil {
			return NewInvalidResponseError(fmt.Sprintf("Invalid response body: %s", err))
		}

		return nil
	case http.StatusNotFound:
		return NewResourceNotFoundError(errorMessageFromRawBody(rawBody))
	case http.StatusUnauthorized:
		return NewUnauthorizedError(errorMessageFromRawBody(rawBody))
	case http.StatusForbidden:
		return NewForbiddenError(errorMessageFromRawBody(rawBody))
	default:
		return fmt.Errorf("Unexpected reponse status %d, %q", response.StatusCode, string(rawBody))
	}
}

func errorMessageFromRawBody(rawBody []byte) string {
	var body errorResponse
	err := json.Unmarshal(rawBody, &body)

	var message string
	if err != nil {
		message = string(rawBody)
	} else {
		message = body.Description
	}

	return message
}

func newWrappedHttpClient(authHeaderBuilder AuthHeaderBuilder, trustedCertPEM []byte, disableTLSCertVerification bool) (httpJsonClient, error) {
	rootCAs, err := x509.SystemCertPool()
	if err != nil {
		return httpJsonClient{}, err
	}
	rootCAs.AppendCertsFromPEM(trustedCertPEM)
	config := herottp.Config{
		DisableTLSCertificateVerification: disableTLSCertVerification,
		RootCAs:                           rootCAs,
		Timeout:                           30 * time.Second,
	}

	return httpJsonClient{
		client:            herottp.New(config),
		AuthHeaderBuilder: authHeaderBuilder,
	}, nil
}
