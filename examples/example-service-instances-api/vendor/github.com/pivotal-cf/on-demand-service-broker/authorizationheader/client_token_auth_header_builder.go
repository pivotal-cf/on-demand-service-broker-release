// Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.
// This program and the accompanying materials are made available under the terms of the under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
// Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

package authorizationheader

import (
	"crypto/x509"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/craigfurman/herottp"
)

type HTTPClient interface {
	Do(req *http.Request) (*http.Response, error)
}

type ClientTokenAuthHeaderBuilder struct {
	uaaURL            string
	clientID          string
	clientSecret      string
	httpClient        HTTPClient
	cachedToken       string
	cachedTokenExpiry time.Time
	tokenLock         *sync.Mutex
}

type ObtainTokenResponse struct {
	Token            string `json:"access_token"`
	ExpiresInSeconds int    `json:"expires_in"`
}

var MinimumRemainingValidity = time.Second * 10

func NewClientTokenAuthHeaderBuilder(
	uaaURL,
	clientID,
	clientSecret string,
	disableSSLCertVerification bool,
	trustedCertPEM []byte,
) (*ClientTokenAuthHeaderBuilder, error) {
	rootCAs, err := x509.SystemCertPool()
	if err != nil {
		return nil, err
	}
	rootCAs.AppendCertsFromPEM(trustedCertPEM)

	return &ClientTokenAuthHeaderBuilder{
		uaaURL:       uaaURL,
		clientID:     clientID,
		clientSecret: clientSecret,
		httpClient: herottp.New(herottp.Config{
			DisableTLSCertificateVerification: disableSSLCertVerification,
			RootCAs:                           rootCAs,
			Timeout:                           30 * time.Second,
		}),
		tokenLock: new(sync.Mutex),
	}, nil
}

func (hb *ClientTokenAuthHeaderBuilder) AddAuthHeader(request *http.Request, logger *log.Logger) error {
	hb.tokenLock.Lock()
	defer hb.tokenLock.Unlock()

	var err error
	hb.cachedToken, hb.cachedTokenExpiry, err = getValidToken(hb.cachedToken, hb.cachedTokenExpiry, logger, hb.obtainToken)
	if err != nil {
		return err
	}

	bearerTokenHeader := bearerToken(hb.cachedToken)
	request.Header.Add("Authorization", bearerTokenHeader)
	return nil
}

func (hb *ClientTokenAuthHeaderBuilder) obtainToken(logger *log.Logger) (string, int, error) {
	requestBody := "grant_type=client_credentials"

	request, err := buildTokenRequest(requestBody, hb.uaaURL, hb.clientID, hb.clientSecret)
	if err != nil {
		return "", 0, err
	}

	return doObtainTokenRequest(hb.httpClient, logger, request)
}
