package main_test

import (
	"os/exec"
	"testing"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"
)

var (
	pathToExe string
	command   *exec.Cmd
	session   *gexec.Session
	username  string
	password  string
)

const appPort = "12345"

var _ = BeforeSuite(func() {
	var err error

	username = "admin"
	password = "supersecret"

	pathToExe, err = gexec.Build("github.com/pivotal-cf-experimental/example-service-instances-api")
	Expect(err).NotTo(HaveOccurred())
})

var _ = AfterSuite(func() {
	gexec.KillAndWait()
	gexec.CleanupBuildArtifacts()
})

func TestExampleServiceInstancesApi(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "ExampleServiceInstancesApi Suite")
}
