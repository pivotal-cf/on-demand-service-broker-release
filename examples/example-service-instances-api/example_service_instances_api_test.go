package main_test

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net"
	"net/http"
	"os"
	"os/exec"
	"strings"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"
	"github.com/pivotal-cf/on-demand-service-broker/service"
)

var url string

var _ = Describe("ExampleServiceInstancesApi", func() {
	BeforeEach(func() {
		url = fmt.Sprintf("http://localhost:%s/service_instances", appPort)
		startServerWithEnv(username, password)
	})

	AfterEach(func() {
		gexec.KillAndWait()
	})

	It("requires basic authentication", func() {
		resp, err := http.Get(url)
		Expect(err).NotTo(HaveOccurred())
		Expect(resp.StatusCode).To(Equal(http.StatusUnauthorized))
		Expect(resp.Header.Get("WWW-Authenticate")).To(ContainSubstring("Basic realm"))
	})

	It("returns a default empty list of service instance objects if none defined", func() {
		assertServiceInstanceList(url, []service.Instance{})
	})

	It("returns http.StatusNotFound if request is not GET or POST", func() {
		resp, err := putWithBasicAuth(url)
		Expect(err).NotTo(HaveOccurred())
		Expect(resp.StatusCode).To(Equal(http.StatusNotFound))
	})

	It("returns the content previous set service instance list invocation", func() {
		postWithBasicAuth(url, `[{"service_instance_id":"instance1","plan_id":"plan1"},{"service_instance_id":"instance2","plan_id":"plan1"}]`)
		assertServiceInstanceList(url, []service.Instance{{GUID: "instance1", PlanUniqueID: "plan1"}, {GUID: "instance2", PlanUniqueID: "plan1"}})
	})

	It("returns the content latest service instance list invocation", func() {
		postWithBasicAuth(url, `[{"service_instance_id":"instance2","plan_id":"plan2"}]`)
		postWithBasicAuth(url, `[{"service_instance_id":"instance1","plan_id":"plan1"},{"service_instance_id":"instance2","plan_id":"plan1"}]`)
		assertServiceInstanceList(url, []service.Instance{{GUID: "instance1", PlanUniqueID: "plan1"}, {GUID: "instance2", PlanUniqueID: "plan1"}})
	})

	It("returns the content previous set for specific params", func() {
		urlWithParams := url + "?foo=bar&name=bob"
		urlWithParams2 := url + "?name=bob&foo=bar"
		postWithBasicAuth(urlWithParams, `[{"service_instance_id":"instance1","plan_id":"plan1"},{"service_instance_id":"instance2","plan_id":"plan1"}]`)
		postWithBasicAuth(url, `[{"service_instance_id":"instance2","plan_id":"plan2"}]`)

		assertServiceInstanceList(urlWithParams, []service.Instance{{GUID: "instance1", PlanUniqueID: "plan1"}, {GUID: "instance2", PlanUniqueID: "plan1"}})
		assertServiceInstanceList(urlWithParams2, []service.Instance{{GUID: "instance1", PlanUniqueID: "plan1"}, {GUID: "instance2", PlanUniqueID: "plan1"}})
		assertServiceInstanceList(url, []service.Instance{{GUID: "instance2", PlanUniqueID: "plan2"}})
	})

	It("fails with 4xx code when it POSTs a status-code=400 param", func() {
		urlWithParams := url + "?a=b&status-code=400"
		postWithBasicAuth(urlWithParams, `[]`)
		assertErrorResponse(url, http.StatusBadRequest)
	})

	It("fails with 5xx code when it POSTs a status-code=500 param", func() {
		urlWithParams := url + "?a=b&status-code=500&c=2"
		postWithBasicAuth(urlWithParams, `[]`)
		assertErrorResponse(url, http.StatusInternalServerError)
	})

	It("does not fail if status-code is unset via a status-code=200 param", func() {
		urlWithParams := url + "?a=b&status-code=400"
		postWithBasicAuth(urlWithParams, `[{"service_instance_id":"instance1","plan_id":"plan1"}]`)
		assertErrorResponse(url, http.StatusBadRequest)
		urlWithUnsetParams := url + "?a=b&status-code=200"
		postWithBasicAuth(urlWithUnsetParams, `[{"service_instance_id":"instance1","plan_id":"plan1"}]`)
		assertServiceInstanceList(url+"?a=b", []service.Instance{{GUID: "instance1", PlanUniqueID: "plan1"}})
	})
})

func getWithErrorHeader(url, header, headerVal string) (*http.Response, error) {
	req, err := http.NewRequest("GET", url, nil)
	Expect(err).NotTo(HaveOccurred())
	req.Header.Add(header, headerVal)
	req.SetBasicAuth(username, password)
	client := http.Client{}
	return client.Do(req)
}

func putWithBasicAuth(url string) (*http.Response, error) {
	return reqWithBasicAuth(url, "PUT", "")
}

func getWithBasicAuth(url string) (*http.Response, error) {
	return reqWithBasicAuth(url, "GET", "")
}

func postWithBasicAuth(url, body string) (*http.Response, error) {
	return reqWithBasicAuth(url, "POST", body)
}

func reqWithBasicAuth(url, method, body string) (*http.Response, error) {
	client := &http.Client{}
	bodyReader := strings.NewReader(body)
	req, err := http.NewRequest(method, url, bodyReader)
	if err != nil {
		return nil, err
	}

	req.SetBasicAuth(username, password)
	return client.Do(req)
}

func startServerWithEnv(username, password string) {
	var err error

	os.Setenv("PORT", appPort)
	os.Setenv("USERNAME", username)
	os.Setenv("PASSWORD", password)

	command = exec.Command(pathToExe)
	session, err = gexec.Start(command, GinkgoWriter, GinkgoWriter)
	Expect(err).NotTo(HaveOccurred())

	Eventually(func() error {
		_, err := net.Dial("tcp", fmt.Sprintf(":%s", os.Getenv("PORT")))
		return err
	}).ShouldNot(HaveOccurred())
}

func assertServiceInstanceList(url string, expectedInstances []service.Instance) {
	resp, err := getWithBasicAuth(url)
	Expect(err).NotTo(HaveOccurred())
	Expect(resp.StatusCode).To(Equal(http.StatusOK))
	Expect(resp.Header.Get("Content-Type")).To(Equal("application/json"))

	content, err := ioutil.ReadAll(resp.Body)
	Expect(err).NotTo(HaveOccurred())

	var instances []service.Instance
	err = json.Unmarshal(content, &instances)
	Expect(err).NotTo(HaveOccurred())
	Expect(instances).To(Equal(expectedInstances))
}

func assertErrorResponse(url string, expectedStatusCode int) {
	resp, err := getWithBasicAuth(url)
	Expect(err).NotTo(HaveOccurred())
	Expect(resp.StatusCode).To(Equal(expectedStatusCode))
	Expect(resp.Header.Get("Content-Type")).To(Equal("application/json"))

	content, err := ioutil.ReadAll(resp.Body)
	Expect(err).NotTo(HaveOccurred())

	Expect(string(content)).To(Equal(`{"description": "a forced error"}`))
}
