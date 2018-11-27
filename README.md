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

## Releases and versioning

The on-demand services SDK is pre-1.0.0 and uses semantic versioning. This means that we reserve the right to release breaking changes in minor versions. Breaking changes will always be clearly flagged in release notes. We do not backwards apply patches, as no version other than the current is in support. 

### A note on breaking changes

There are three different categories of breaking changes when talking about ODB
Behavioural/Functional breaking changes
Manifest breaking changes
SDK Interface breaking changes

It is safe to assume that, from version x to version x+1, ODB will not introduce Behavioural/Functional breaking changes. We may introduce new functionality, but it will be feature flagged and off by default (in most cases). Keep in mind that we might remove a feature flag (or most likely turn it on by default) from version x to version x+2.

While we try our best to not introduce Manifest or SDK Interface breaking changes, they are the most likely to occur in a minor bump. It usually means that the service adapter author will need to update the signature of their functions to continue to use the SDK. Note that changing the signature doesn’t enable the feature, as it usually needs an updated manifest with the feature flag turned on.

### Support

The on-demand services SDK is not an end customer-facing product, and as such we do not have an official support policy. Our unofficial policy is that only the current (latest) version is supported. We do not maintain pipelines or testing for any branch of our codebase other than master.

There have been situations where we have released patch updates, e.g. 0.21.2 where we had to downgrade golang due to a cert validation issue, but this was classified as a patch due to the content of the release (small dependency change) and we did not backport the patch to any previous version.

### Best practice for maintaining ODB in your tile

We recommend that you float ODB versions and bump all supported tiles whenever a new ODB version is available, in order to ensure all the latest security patches and bug fixes reach your end users (in case you want to know more about this strategy, RabbitMQ for PCF and Redis for PCF teams have been doing this successfully). In the vast majority of cases we use feature flags to ensure you stay in control of when you introduce new features to your users.

### Availability of old versions

Whilst we have no official support policy, we remove all ODB versions released more than nine months ago from availability on pivnet. This is in keeping with Pivotal tiles’ official support policy. We remove docs for old versions accordingly, though they are still available in PDF format (e.g. 0.20).
