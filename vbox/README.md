# Creating a Local VirtualBox Environment to run ODB System Tests

## Setup

1. Ensure [VirtualBox](https://www.virtualbox.org/wiki/Downloads) is installed
   and running, following instructions from the website.

1. Clone the [ODB release](https://github.com/pivotal-cf/on-demand-service-broker-release).
   In this example we'll put it in $HOME/workspace:
    ```bash
    $ mkdir -p $HOME/workspace
    $ cd $HOME/workspace
    $ git clone https://github.com/pivotal-cf/on-demand-service-broker-release
    ```

1. Fetch the submodules to get the ODB source, and example adapter and service releases:
    ```bash
    $ cd on-demand-service-broker-release
    $ git submodule update --init --recursive
    ```

1. Make any tweaks to vbox/config.sh to modify passwords, for example.

1. Deploy bosh and cf in VirtualBox (this may take around 30 minutes)
    ```bash
    $ cd vbox
    $ ./make-vbox-cf-env
    ```
The environment is now ready to be used. It has been aliased as `vbox`, so the
command `bosh -e vbox deployments`, for example, should show the *cf* deployment.
It might be useful to snapshot the VM using VirtualBox at this point in case
you need to get back to a pristine state in the future.

## Running tests

ODB has 'old-style' and 'new-style' system tests. The old-style rely on a broker having
been deployed to BOSH with the correct configuration. The new-style tests perform that configuration
and deployment themselves. When starting out, it may make sense to restrict yourself to running
the new-style tests, which include lifecycle_tests/with_maintenance_info, recreate_all_tests and
dynamic_bosh_config.

1. Create and upload the required releases from the ODB-release source tree:
    ```bash
    $ cd $HOME/workspace/on-demand-service-broker-release
    $ # On-Demand-Broker
    $ ./vbox/create-and-upload-releases.sh
    $ # Redis Service
    $ pushd examples/redis-example-service-release
    $ ./vbox/create-and-upload-releases.sh
    $ popd
    $ # Redis Adapter
    $ pushd examples/redis-example-service-adapter-release
    $ ./vbox/create-and-upload-releases.sh
    $ popd
    ```

1. Set the GOPATH:
    ```
    $ export GOPATH=$HOME/workspace/on-demand-service-broker-release
    ```

1. Run the required system test, e.g. dynamic_bosh_config:
    ```bash
    $ cd src/github.com/pivotal-cf/on-demand-service-broker/system_tests
    $ ./run_system_tests_local.sh ../../../../../vbox/artifacts/broker-deployment-vars.yml dynamic_bosh_config
    ```

## Delete VM

1. Run `cleanup` to delete deploymet and remove vm
    ```bash
    $ cd $HOME/workspace/on-demand-service-broker-release/vbox
    $ ./cleanup
    ```

*Note*

If you delete directly on the VirtualBox, `state.json` will not be deleted. This will cause `make-vbox-cf-env` to fail next time it runs.
