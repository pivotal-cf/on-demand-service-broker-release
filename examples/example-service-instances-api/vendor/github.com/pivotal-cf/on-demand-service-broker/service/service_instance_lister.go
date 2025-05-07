// Copyright (C) 2015-Present Pivotal Software, Inc. All rights reserved.

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

package service

import (
	"crypto/x509"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"net/url"

	"github.com/pivotal-cf/on-demand-service-broker/authorizationheader"
)

//counterfeiter:generate -o fakes/fake_doer.go . Doer
type Doer interface {
	Do(*http.Request) (*http.Response, error)
}

type ServiceInstanceLister struct {
	authHeaderBuilder authorizationheader.AuthHeaderBuilder
	baseURL           string
	client            Doer
	configured        bool
	logger            *log.Logger
}

var (
	InstanceNotFound = errors.New("Service instance not found")
)

func NewInstanceLister(
	client Doer,
	authHeaderBuilder authorizationheader.AuthHeaderBuilder,
	baseURL string,
	configured bool,
	logger *log.Logger) *ServiceInstanceLister {
	return &ServiceInstanceLister{
		authHeaderBuilder: authHeaderBuilder,
		baseURL:           baseURL,
		client:            client,
		configured:        configured,
		logger:            logger,
	}
}

func (s *ServiceInstanceLister) Instances(params map[string]string) ([]Instance, error) {
	request, err := http.NewRequest(http.MethodGet, s.baseURL, nil)
	if err != nil {
		return nil, err
	}

	values := request.URL.Query()
	for k, v := range params {
		values.Add(k, v)
	}
	request.URL.RawQuery = values.Encode()

	err = s.authHeaderBuilder.AddAuthHeader(request, s.logger)
	if err != nil {
		return nil, err
	}

	response, err := s.client.Do(request)

	if err != nil {
		return s.instanceListerError(response, err)
	}
	defer response.Body.Close()

	if response.StatusCode != http.StatusOK {
		genericJson := map[string]string{}
		err := json.NewDecoder(response.Body).Decode(&genericJson)
		body := ""
		if err == nil {
			body = genericJson["description"]
		}
		return s.instanceListerError(response, fmt.Errorf("HTTP response status: %s. %s", response.Status, body))
	}

	var instances []Instance
	err = json.NewDecoder(response.Body).Decode(&instances)
	if err != nil {
		return instances, err
	}
	return instances, nil
}

func (s *ServiceInstanceLister) LatestInstanceInfo(instance Instance) (Instance, error) {
	instances, err := s.Instances(nil)
	if err != nil {
		return Instance{}, err
	}
	for _, inst := range instances {
		if inst.GUID == instance.GUID {
			return inst, nil
		}
	}
	return Instance{}, InstanceNotFound
}

func (s *ServiceInstanceLister) instanceListerError(response *http.Response, err error) ([]Instance, error) {
	if s.configured {
		if urlError, ok := err.(*url.Error); ok {
			if urlError.Err != nil && urlError.URL != "" {
				switch urlError.Err.(type) {
				case x509.UnknownAuthorityError:
					return []Instance{}, fmt.Errorf(
						"SSL validation error for `service_instances_api.url`: %s. Please configure a `service_instances_api.root_ca_cert` and use a valid SSL certificate",
						urlError.URL,
					)
				default:
					return []Instance{}, fmt.Errorf("error communicating with service_instances_api (%s): %s", urlError.URL, err.Error())
				}
			}
		}

		if response != nil {
			return []Instance{}, fmt.Errorf("error communicating with service_instances_api (%s): %s", response.Request.URL, err.Error())
		}
	}
	return []Instance{}, err
}
