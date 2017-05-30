## Contributing

- We prefer small PRs often over large PRs
- For any large change proposals please raise an issue first.

### Development

It must be used on a version of BOSH that supports global cloud config (246 or higher).

### Dev/Test tools
* Ruby
* bosh_cli Ruby gem

### Running Tests
The [broker codebase](https://github.com/pivotal-cf/on-demand-service-broker)
contains a `system_tests` package that tests any deployed broker as a black box.
Those tests can be run against a BOSH deployment of this release.

### System Tests Workflow
The below system tests use Redis as an example.

1. Prepare and Upload the service release
  1. `cd` to the redis example service release directory(base)
  1. `bosh create release --name redis-service-devX`
   (devX: e.g. dev1, dev2: something to disambiguate your service release from others on shared BOSH director)
  1. `bosh upload release --rebase`
1. Prepare and Upload the service adapter release
  1. `cd` to the redis adapter release directory(base)
  1. `bosh create release --name redis-service-adapter-devX`
   (devX: e.g. dev1, dev2: something to disambiguate your service release from others on shared BOSH director)
  1. `bosh upload release --rebase`
1. Update the broker manifest
  1. Change manifest corresponding to your service and service adapter release names and version
    e.g. `change properties.broker.service_release.version` in your manifest
  1. `bosh deployment $MANIFEST_FROM_PREVIOUS_STEP`
1. Deploy broker
  1. `cd` to the broker bosh release(on-demand-service-broker-release)
  1. `bosh create release [--force] --name redis-on-demand-broker-devX`
  1. `bosh upload release --rebase`
  1. `bosh deploy`
1. Setup local Cloud Foundry CLI
  1. Ensure CF CLI pointed at testing CF and logged in
  1. `cf target -s <space>`
1. Run the tests
  1. `cd` into broker submodule of broker release
  1. `BROKER_NAME=on-demand-broker BROKER_USERNAME=$FROM_MANIFEST BROKER_PASSWORD=$FROM_MANIFEST BROKER_URL=http://${FROM_BOSH_VMS_ON_BROKER_DEPLOYMENT}:8080 SERVICE_NAME=$FROM_MANIFEST
  SERVICE_GUID=$UNIQUE_SERVICE_ID_FROM_MANIFEST
  TEST_APP_NAME=test-app ginkgo -p -nodes=4 system_tests`

### System Tests "fly execute" Workflow
1. Follow steps 1-3 above (up to and including "Deploy broker")
1. prepare a `system-tests-local.yml` file in the ci directory, which should be templated from `system-tests.yml`. This should never be checked in, and files matching this pattern are gitignored.
Task file parameters match the ones given in "run the tests" step above
1. `fly --target services-enablement e -c ci/system-tests-local.yml -x -i broker-release=.`


## Pre-commit Checklists

### When Changing Broker Config

- [ ] `development/example-manifest.yml` in this repo
- [ ] `jobs/broker/spec` in this repo
- [ ] Update the `jobs/broker/templates/broker.yml.erb` in this repo
- [ ] `config/test_assets/good_config.yml` in the `on-demand-service-broker`
- [ ] `config/broker_config.go` in the `on-demand-service-broker`


Having changed `good_config.yml` and `broker_config.go`, you should have test failures which you can resolve by changing `broker_config_test.go`

