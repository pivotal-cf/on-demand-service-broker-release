// Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.
// This program and the accompanying materials are made available under the terms of the under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
// Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

package authorizationheader

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"strings"
	"time"
)

//go:generate go run github.com/maxbrunsfeld/counterfeiter/v6 -generate
//counterfeiter:generate -o fakes/fake_auth_header_builder.go . AuthHeaderBuilder
type AuthHeaderBuilder interface {
	AddAuthHeader(request *http.Request, logger *log.Logger) error
}

func tokenExpired(token string, tokenExpiry time.Time) bool {
	if token == "" {
		return true
	}

	return tokenExpiry.Before(time.Now())
}

func getNewToken(logger *log.Logger, obtainTokenFunction func(*log.Logger) (string, int, error)) (string, time.Time, error) {
	logger.Println("no valid UAA token found in cache, obtaining a new one")
	token, expiresInSeconds, err := obtainTokenFunction(logger)
	if err != nil {
		return "", time.Time{}, err
	}
	tokenExpiry := time.Now().Add(time.Second * time.Duration(expiresInSeconds)).Add(MinimumRemainingValidity * -1)
	return token, tokenExpiry, nil
}

func bearerToken(token string) string {
	return fmt.Sprintf("Bearer %s", token)
}

func getValidToken(token string, tokenExpiry time.Time, logger *log.Logger, obtainTokenFunction func(*log.Logger) (string, int, error)) (string, time.Time, error) {
	if tokenExpired(token, tokenExpiry) {
		var err error
		token, tokenExpiry, err = getNewToken(logger, obtainTokenFunction)
		if err != nil {
			return "", time.Time{}, err
		}
	}

	return token, tokenExpiry, nil
}

func doObtainTokenRequest(httpClient HTTPClient, logger *log.Logger, request *http.Request) (string, int, error) {
	response, err := httpClient.Do(request)
	if err != nil {
		return "", 0, fmt.Errorf("Error reaching UAA: %s. Please ensure that the UAA urls and credentials under properties.<broker-job> are correct and reachable.", err)
	}
	defer response.Body.Close()

	if response.StatusCode != http.StatusOK {
		bodyBytes, err := ioutil.ReadAll(response.Body)
		if err != nil {
			bodyBytes = []byte("<error reading body>")
		}
		return "", 0, fmt.Errorf("Error authenticating (%d): %s. Please ensure that the UAA urls and credentials under properties.<broker-job> are correct and try again.", response.StatusCode, strings.TrimRight(string(bodyBytes), "\r\n"))
	}

	var responseContent ObtainTokenResponse
	if err := json.NewDecoder(response.Body).Decode(&responseContent); err != nil {
		return "", 0, err
	}

	if responseContent.Token == "" {
		return "", 0, fmt.Errorf("no access token in grant %#v", responseContent)
	}

	logger.Printf("obtained UAA token, expires in %d seconds\n", responseContent.ExpiresInSeconds)

	return responseContent.Token, responseContent.ExpiresInSeconds, nil
}

func buildTokenRequest(requestBody, uaaURL, clientID, clientSecret string) (*http.Request, error) {
	request, err := http.NewRequest(
		http.MethodPost,
		fmt.Sprintf("%s/oauth/token", uaaURL),
		strings.NewReader(requestBody),
	)
	if err != nil {
		return nil, err
	}
	request.Header.Set("Content-type", "application/x-www-form-urlencoded")
	request.SetBasicAuth(clientID, clientSecret)

	return request, nil
}
