// Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.
// This program and the accompanying materials are made available under the
// terms of the under the Apache License, Version 2.0 (the "License"); you may
// not use this file except in compliance with the License.  You may obtain a
// copy of the License at http://www.apache.org/licenses/LICENSE-2.0 Unless
// required by applicable law or agreed to in writing, software distributed
// under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

package config

import (
	"errors"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"strings"

	"github.com/pivotal-cf/on-demand-service-broker/authorizationheader"
	"github.com/pivotal-cf/on-demand-services-sdk/serviceadapter"
	"gopkg.in/yaml.v2"
)

type Config struct {
	Broker              Broker
	Bosh                Bosh
	CF                  CF
	ServiceInstancesAPI ServiceInstancesAPI `yaml:"service_instances_api"`
	CredHub             CredHub             `yaml:"credhub"`
	ServiceAdapter      ServiceAdapter      `yaml:"service_adapter"`
	ServiceDeployment   ServiceDeployment   `yaml:"service_deployment"`
	ServiceCatalog      ServiceOffering     `yaml:"service_catalog"`
	BoshCredhub         BoshCredhub         `yaml:"bosh_credhub"`
}

type Broker struct {
	Port                       int       `yaml:"port"`
	Username                   string    `yaml:"username"`
	Password                   string    `yaml:"password"`
	DisableSSLCertVerification bool      `yaml:"disable_ssl_cert_verification"`
	DisableBoshConfigs         bool      `yaml:"disable_bosh_configs"`
	StartUpBanner              bool      `yaml:"startup_banner"`
	ShutdownTimeoutSecs        int       `yaml:"shutdown_timeout_in_seconds"`
	DisableCFStartupChecks     bool      `yaml:"disable_cf_startup_checks"`
	ExposeOperationalErrors    bool      `yaml:"expose_operational_errors"`
	EnablePlanSchemas          bool      `yaml:"enable_plan_schemas"`
	UsingStdin                 bool      `yaml:"use_stdin"`
	EnableSecureManifests      bool      `yaml:"enable_secure_manifests"`
	EnableTelemetry            bool      `yaml:"enable_telemetry"`
	EnableOptimisedUpgrades    bool      `yaml:"enable_optimised_upgrades"`
	SupportBackupAgentBinding  bool      `yaml:"support_backup_agent_binding"`
	TLS                        TLSConfig `yaml:"tls"`
}

type BoshCredhub struct {
	URL            string `yaml:"url"`
	RootCACert     string `yaml:"root_ca_cert"`
	Authentication Authentication
}

type Authentication struct {
	Basic UserCredentials
	UAA   UAAAuthentication
}

type UAAAuthentication struct {
	URL               string
	ClientCredentials ClientCredentials `yaml:"client_credentials"`
	UserCredentials   UserCredentials   `yaml:"user_credentials"`
}

type UserCredentials struct {
	Username string
	Password string
}

type ClientCredentials struct {
	ID     string `yaml:"client_id"`
	Secret string `yaml:"client_secret"`
}

// TODO: Refactor BOSH Authentication structure to look like CF one
type Bosh struct {
	URL            string `yaml:"url"`
	TrustedCert    string `yaml:"root_ca_cert"`
	Authentication Authentication
}

type UAACredentials struct {
	ClientCredentials ClientCredentials `yaml:"client_credentials"`
	UserCredentials   UserCredentials   `yaml:"user_credentials"`
}

type ClientDefinition struct {
	Authorities          string `yaml:"authorities"`
	AuthorizedGrantTypes string `yaml:"authorized_grant_types"`
	ResourceIDs          string `yaml:"resource_ids"`
	Scopes               string `yaml:"scopes"`
	Name                 string `yaml:"name"`
	AllowPublic          bool   `yaml:"allowpublic"`
}

type UAAConfig struct {
	URL              string           `yaml:"url"`
	ClientDefinition ClientDefinition `yaml:"client_definition"`
	Authentication   UAACredentials   `yaml:"authentication"`
}

type CF struct {
	URL                        string
	TrustedCert                string    `yaml:"root_ca_cert"`
	UAA                        UAAConfig `yaml:"uaa"`
	DisableSSLCertVerification bool      `yaml:"disable_ssl_cert_verification"`
}

type TLSConfig struct {
	CertFile string `yaml:"cert_file"`
	KeyFile  string `yaml:"key_file"`
}

func (c Config) Validate() error {
	if err := c.Broker.Validate(); err != nil {
		return err
	}

	if err := c.Bosh.Validate(); err != nil {
		return fmt.Errorf("BOSH configuration error: %s", err)
	}
	if !c.Broker.DisableCFStartupChecks {
		if err := c.CF.Validate(); err != nil {
			return fmt.Errorf("CF configuration error: %s", err.Error())
		}
	}

	if err := checkIsExecutableFile(c.ServiceAdapter.Path); err != nil {
		return fmt.Errorf("checking for executable service adapter file: %s", err)
	}

	if err := c.ServiceDeployment.Validate(); err != nil {
		return err
	}

	if err := c.ServiceCatalog.Validate(); err != nil {
		return err
	}

	return nil
}

func (c Config) HasRuntimeCredHub() bool {
	return c.CredHub != CredHub{}
}

func (c Config) HasBindingWithDNSConfigured() bool {
	for _, plan := range c.ServiceCatalog.Plans {
		if len(plan.BindingWithDNS) > 0 {
			return true
		}
	}
	return false
}

func (c Config) HasTLS() bool {
	return c.Broker.TLS.CertFile != "" && c.Broker.TLS.KeyFile != ""
}

func (b Broker) Validate() error {
	if b.Port == 0 {
		return errors.New("broker.port can't be empty")
	}
	if b.Username == "" {
		return errors.New("broker.username can't be empty")
	}
	if b.Password == "" {
		return errors.New("broker.password can't be empty")
	}

	return nil
}

type ServiceDeployment struct {
	Releases  serviceadapter.ServiceReleases
	Stemcells []serviceadapter.Stemcell
}

func (s ServiceDeployment) Validate() error {
	for _, release := range s.Releases {
		if err := assertVersion(release.Version); err != nil {
			return err
		}
	}
	return nil
}

func assertVersion(version string) error {
	if strings.HasSuffix(version, "latest") {
		return errors.New("You must configure the exact release and stemcell versions in broker.service_deployment. ODB requires exact versions to detect pending changes as part of the 'cf update-service' workflow. For example, latest and 3112.latest are not supported.")
	}
	return nil
}

func (boshConfig Bosh) NewAuthHeaderBuilder(UAAURL string, disableSSLCertVerification bool) (AuthHeaderBuilder, error) {
	boshAuthConfig := boshConfig.Authentication
	if boshAuthConfig.Basic.IsSet() {
		return authorizationheader.NewBasicAuthHeaderBuilder(
			boshAuthConfig.Basic.Username,
			boshAuthConfig.Basic.Password,
		), nil
	} else if boshAuthConfig.UAA.IsSet() {
		return authorizationheader.NewClientTokenAuthHeaderBuilder(
			UAAURL,
			boshAuthConfig.UAA.ClientCredentials.ID,
			boshAuthConfig.UAA.ClientCredentials.Secret,
			disableSSLCertVerification,
			[]byte(boshConfig.TrustedCert),
		)
	} else {
		return nil, errors.New("No BOSH authentication configured")
	}
}

type AuthHeaderBuilder interface {
	AddAuthHeader(request *http.Request, logger *log.Logger) error
}

func (cf CF) NewAuthHeaderBuilder(disableSSLCertVerification bool) (AuthHeaderBuilder, error) {
	if cf.UAA.Authentication.ClientCredentials.IsSet() {
		return authorizationheader.NewClientTokenAuthHeaderBuilder(
			cf.UAA.URL,
			cf.UAA.Authentication.ClientCredentials.ID,
			cf.UAA.Authentication.ClientCredentials.Secret,
			disableSSLCertVerification,
			[]byte(cf.TrustedCert),
		)
	} else {
		return authorizationheader.NewUserTokenAuthHeaderBuilder(
			cf.UAA.URL,
			"cf",
			"",
			cf.UAA.Authentication.UserCredentials.Username,
			cf.UAA.Authentication.UserCredentials.Password,
			disableSSLCertVerification,
			[]byte(cf.TrustedCert),
		)
	}
}

func (b Bosh) Validate() error {
	if b.URL == "" {
		return fmt.Errorf("must specify bosh url")
	}
	return b.Authentication.Validate(false)
}

func (cf CF) Validate() error {
	if cf.URL == "" {
		return fmt.Errorf("must specify CF url")
	}
	return validateAuthenticationFields(
		true,
		cf.UAA.URL,
		cf.UAA.Authentication.ClientCredentials,
		cf.UAA.Authentication.UserCredentials,
	)
}

func (cc UAAAuthentication) IsSet() bool {
	return cc != UAAAuthentication{}
}

func (a UAAAuthentication) Validate(URLRequired bool) error {
	return validateAuthenticationFields(URLRequired, a.URL, a.ClientCredentials, a.UserCredentials)
}

func validateAuthenticationFields(URLRequired bool, url string, clientCredentials ClientCredentials, userCredentials UserCredentials) error {
	urlIsSet := url != ""
	clientCredentialsSet := clientCredentials.IsSet()
	userCredentialsSet := userCredentials.IsSet()

	switch {
	case !urlIsSet && !clientCredentialsSet && !userCredentialsSet:
		return fmt.Errorf("must specify UAA authentication")
	case !urlIsSet && URLRequired:
		return newFieldError("uaa url", errors.New("can't be empty"))
	case !clientCredentialsSet && !userCredentialsSet:
		return fmt.Errorf("authentication should contain either user_credentials or client_credentials")
	case clientCredentialsSet && userCredentialsSet:
		return fmt.Errorf("contains both client and user credentials")
	case clientCredentialsSet:
		if err := clientCredentials.Validate(); err != nil {
			return newFieldError("client_credentials", err)
		}
	case userCredentialsSet:
		if err := userCredentials.Validate(); err != nil {
			return newFieldError("user_credentials", err)
		}
	}
	return nil
}

func (c UserCredentials) IsSet() bool {
	return c != UserCredentials{}
}

func (b UserCredentials) Validate() error {
	if b.Username == "" {
		return newFieldError("username", errors.New("can't be empty"))
	}
	if b.Password == "" {
		return newFieldError("password", errors.New("can't be empty"))
	}
	return nil
}

func (cc ClientCredentials) IsSet() bool {
	return cc != ClientCredentials{}
}

func (c ClientCredentials) Validate() error {
	if c.ID == "" {
		return newFieldError("client_id", errors.New("can't be empty"))
	}
	if c.Secret == "" {
		return newFieldError("client_secret", errors.New("can't be empty"))
	}
	return nil
}

type FieldError struct {
	Field string
	Msg   string
}

func (f FieldError) Error() string {
	return fmt.Sprintf("%s %s", f.Field, f.Msg)
}

func newFieldError(field string, err error) error {
	switch newErr := err.(type) {
	case *FieldError:
		newErr.Field = fmt.Sprintf("%s.%s", field, newErr.Field)
		return newErr
	default:
		return &FieldError{
			Field: field,
			Msg:   err.Error(),
		}
	}
}

func (a Authentication) Validate(URLRequired bool) error {
	uaaSet := a.UAA.IsSet()
	basicSet := a.Basic.IsSet()

	switch {
	case !uaaSet && !basicSet:
		return fmt.Errorf("must specify an authentication type")
	case uaaSet && basicSet:
		return fmt.Errorf("cannot specify both basic and UAA authentication")
	case uaaSet:
		if err := a.UAA.Validate(URLRequired); err != nil {
			return newFieldError("authentication.uaa", err)
		}
	case basicSet:
		if err := a.Basic.Validate(); err != nil {
			return newFieldError("authentication.basic", err)
		}
	}
	return nil
}

type CredHub struct {
	APIURL            string `yaml:"api_url"`
	ClientID          string `yaml:"client_id"`
	ClientSecret      string `yaml:"client_secret"`
	CaCert            string `yaml:"ca_cert"`
	InternalUAACaCert string `yaml:"internal_uaa_ca_cert"`
}

type ServiceAdapter struct {
	Path string
}

func Parse(configFilePath string) (Config, error) {
	configFileBytes, err := ioutil.ReadFile(configFilePath)
	if err != nil {
		return Config{}, err
	}

	var config Config
	if err := yaml.Unmarshal(configFileBytes, &config); err != nil {
		return Config{}, err
	}

	if err := config.Validate(); err != nil {
		return Config{}, err
	}

	return config, nil
}

type MaintenanceInfo struct {
	Public      map[string]string `yaml:"public,omitempty"`
	Private     map[string]string `yaml:"private,omitempty"`
	Version     string            `yaml:"version,omitempty"`
	Description string            `yaml:"description,omitempty"`
}

type ServiceOffering struct {
	ID               string
	Name             string `yaml:"service_name"`
	Description      string `yaml:"service_description"`
	Bindable         bool
	PlanUpdatable    bool     `yaml:"plan_updatable"`
	Requires         []string `yaml:"requires,omitempty"`
	Metadata         ServiceMetadata
	DashboardClient  *DashboardClient `yaml:"dashboard_client,omitempty"`
	Tags             []string
	GlobalProperties serviceadapter.Properties `yaml:"global_properties"`
	GlobalQuotas     Quotas                    `yaml:"global_quotas"`
	Plans            Plans
	MaintenanceInfo  *MaintenanceInfo `yaml:"maintenance_info,omitempty"`
}

func (s ServiceOffering) FindPlanByID(id string) (Plan, bool) {
	return s.Plans.FindByID(id)
}

func (s ServiceOffering) HasLifecycleErrands() bool {
	for _, plan := range s.Plans {
		if plan.LifecycleErrands != nil {
			if len(plan.LifecycleErrands.PostDeploy) > 0 || len(plan.LifecycleErrands.PreDelete) > 0 {
				return true
			}
		}
	}

	return false
}

func (s ServiceOffering) Validate() error {
	for _, plan := range s.Plans {
		if plan.LifecycleErrands != nil {
			for _, errand := range plan.LifecycleErrands.PostDeploy {
				if err := s.validateLifecycleErrands(errand); err != nil {
					return err
				}
			}
			for _, errand := range plan.LifecycleErrands.PreDelete {
				if err := s.validateLifecycleErrands(errand); err != nil {
					return err
				}
			}
		}
	}

	return nil
}

func (s ServiceOffering) validateLifecycleErrands(errands serviceadapter.Errand) error {
	for _, instanceName := range errands.Instances {
		pieces := strings.Split(instanceName, "/")
		if len(pieces) != 1 && len(pieces) != 2 {
			return fmt.Errorf("Must specify pool or instance '%s' in format 'name' or 'name/id-or-index'", instanceName)
		}

		if len(pieces[0]) == 0 {
			return fmt.Errorf("Must specify pool or instance '%s' in format 'name' or 'name/id-or-index'", instanceName)
		}

		if len(pieces) == 2 {
			if len(pieces[1]) == 0 {
				return fmt.Errorf("Must specify pool or instance '%s' in format 'name' or 'name/id-or-index'", instanceName)
			}
		}
	}
	return nil
}

type Plans []Plan

func (p Plans) FindByID(id string) (Plan, bool) {
	for _, plan := range p {
		if plan.ID == id {
			return plan, true
		}
	}
	return Plan{}, false
}

type Plan struct {
	ID               string `yaml:"plan_id"`
	Name             string
	Free             *bool
	Bindable         *bool
	Description      string
	Metadata         PlanMetadata
	Quotas           Quotas `yaml:"quotas,omitempty"`
	Properties       serviceadapter.Properties
	InstanceGroups   []serviceadapter.InstanceGroup   `yaml:"instance_groups,omitempty"`
	Update           *serviceadapter.Update           `yaml:"update,omitempty"`
	LifecycleErrands *serviceadapter.LifecycleErrands `yaml:"lifecycle_errands,omitempty"`
	BindingWithDNS   []BindingDNS                     `yaml:"binding_with_dns"`
	MaintenanceInfo  *MaintenanceInfo                 `yaml:"maintenance_info,omitempty"`
}

func (p Plan) AdapterPlan(globalProperties serviceadapter.Properties) serviceadapter.Plan {
	lifecycleErrands := serviceadapter.LifecycleErrands{}
	if p.LifecycleErrands != nil {
		lifecycleErrands = *p.LifecycleErrands
	}

	return serviceadapter.Plan{
		Properties:       mergeProperties(p.Properties, globalProperties),
		InstanceGroups:   p.InstanceGroups,
		Update:           p.Update,
		LifecycleErrands: lifecycleErrands,
	}
}

func mergeProperties(planProperties, globalProperties serviceadapter.Properties) serviceadapter.Properties {
	properties := serviceadapter.Properties{}
	for k, v := range globalProperties {
		properties[k] = v
	}
	for k, v := range planProperties {
		properties[k] = v
	}
	return properties
}

func (p Plan) PostDeployErrands() []Errand {
	var errands []Errand

	if p.LifecycleErrands != nil {
		for _, errand := range p.LifecycleErrands.PostDeploy {
			errands = append(errands, Errand(errand))
		}
	}

	return errands
}

type Errand struct {
	Name      string
	Instances []string
}

func (p Plan) PreDeleteErrands() []Errand {
	var errands []Errand

	if p.LifecycleErrands != nil {
		for _, errand := range p.LifecycleErrands.PreDelete {
			errands = append(errands, Errand(errand))
		}
	}

	return errands
}

type PlanMetadata struct {
	DisplayName        string                 `yaml:"display_name"`
	Bullets            []string               `yaml:"bullets,omitempty"`
	Costs              []PlanCost             `yaml:"costs"`
	AdditionalMetadata map[string]interface{} `yaml:"additional_metadata,inline,omitempty"`
}

type PlanCost struct {
	Amount map[string]float64 `yaml:"amount"`
	Unit   string             `yaml:"unit"`
}

type ServiceMetadata struct {
	DisplayName         string                 `yaml:"display_name"`
	ImageURL            string                 `yaml:"image_url"`
	LongDescription     string                 `yaml:"long_description"`
	ProviderDisplayName string                 `yaml:"provider_display_name"`
	DocumentationURL    string                 `yaml:"documentation_url"`
	SupportURL          string                 `yaml:"support_url"`
	Shareable           bool                   `yaml:"shareable"`
	AdditionalMetadata  map[string]interface{} `yaml:"additional_metadata,inline,omitempty"`
}

type DashboardClient struct {
	ID          string
	Secret      string
	RedirectUri string `yaml:"redirect_uri"`
}

type ResourceQuota struct {
	Limit int `yaml:"limit,omitempty"`
	Cost  int `yaml:"cost,omitempty"`
}

type Quotas struct {
	ServiceInstanceLimit *int                     `yaml:"service_instance_limit,omitempty"`
	Resources            map[string]ResourceQuota `yaml:"resources,omitempty"`
}

type CanarySelectionParams map[string]string

func (filter CanarySelectionParams) String() string {
	filters := []string{}
	for k, v := range filter {
		filters = append(filters, fmt.Sprintf("%s: %s", k, v))
	}
	return strings.Join(filters, ", ")
}

type InstanceIteratorConfig struct {
	BrokerAPI              BrokerAPI             `yaml:"broker_api"`
	PollingInterval        int                   `yaml:"polling_interval"`
	AttemptInterval        int                   `yaml:"attempt_interval"`
	AttemptLimit           int                   `yaml:"attempt_limit"`
	RequestTimeout         int                   `yaml:"request_timeout"`
	MaxInFlight            int                   `yaml:"max_in_flight"`
	Canaries               int                   `yaml:"canaries"`
	CanarySelectionParams  CanarySelectionParams `yaml:"canary_selection_params"`
	Bosh                   Bosh                  `yaml:"bosh"`
	CF                     CF                    `yaml:"cf"`
	MaintenanceInfoPresent bool                  `yaml:"maintenance_info_present"`
}

type BrokerAPI struct {
	URL            string          `yaml:"url"`
	Authentication Authentication  `yaml:"authentication"`
	TLS            ErrandTLSConfig `yaml:"tls"`
}

type ServiceInstancesAPI struct {
	URL                        string         `yaml:"url"`
	RootCACert                 string         `yaml:"root_ca_cert"`
	Authentication             Authentication `yaml:"authentication"`
	DisableSSLCertVerification bool           `yaml:"disable_ssl_cert_verification"`
}

type BindingDNS struct {
	Name          string               `yaml:"name"`
	LinkProvider  string               `yaml:"link_provider"`
	InstanceGroup string               `yaml:"instance_group"`
	Properties    BindingDNSProperties `yaml:"properties"`
}

type BindingDNSProperties struct {
	AZS    []string `yaml:"azs"`
	Status string   `yaml:"status"`
}

type OrphanDeploymentsErrandConfig struct {
	BrokerAPI BrokerAPI `yaml:"broker_api"`
}

type ErrandTLSConfig struct {
	CACert                     string `yaml:"ca_cert"`
	DisableSSLCertVerification bool   `yaml:"disable_ssl_cert_verification"`
}

type RegisterBrokerErrandConfig struct {
	BrokerName        string       `yaml:"broker_name"`
	BrokerUsername    string       `yaml:"broker_username"`
	BrokerPassword    string       `yaml:"broker_password"`
	BrokerURL         string       `yaml:"broker_url"`
	CF                CF           `yaml:"cf"`
	ServiceOfferingID string       `yaml:"service_offering_id"`
	Plans             []PlanAccess `yaml:"plans"`
}

type CFServiceAccess string

const (
	PlanEnabled       = CFServiceAccess("enable")
	PlanDisabled      = CFServiceAccess("disable")
	PlanOrgRestricted = CFServiceAccess("org-restricted")
)

type PlanAccess struct {
	Name             string          `yaml:"name"`
	ServiceAccessOrg string          `yaml:"service_access_org"`
	CFServiceAccess  CFServiceAccess `yaml:"cf_service_access"`
}
