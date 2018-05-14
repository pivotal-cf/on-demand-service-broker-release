# on-demand-service-broker-release
A BOSH release for a [Cloud Foundry on-demand service broker](https://github.com/pivotal-cf/on-demand-service-broker).

The broker deploys any service release on demand. One service instance corresponds to one BOSH deployment.

To create the release, ensure you are using the Bosh CLI v2.0.48+.

## User Documentation

Full user documentation can be found [here](https://docs.pivotal.io/svc-sdk/odb).

### Getting Started with ODB

Follow [this guide](https://docs.pivotal.io/svc-sdk/odb/getting-started.html) to try out an example product.

### Creating a ODB Based Service 

We have [an SDK](https://github.com/pivotal-cf/on-demand-services-sdk) to start you off building on demand services. This helps you create [service adapters](https://docs.pivotal.io/svc-sdk/odb/creating.html), required by the ODB to deploy on demand instances of your [BOSH release](https://bosh.io/docs)

### Packaging for Pivotal Cloud Foundry (PCF)

Once you have an ODB integration completed for your service you may wish to create a tile for the PCF marketplace. You can [follow this guide to tile development](https://docs.pivotal.io/svc-sdk/odb/0-15/tile.html).

## Contributing

- See [CONTRIBUTING](CONTRIBUTING.md)
- Trigger the CI PR pipeline
