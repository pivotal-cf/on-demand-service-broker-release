# Service Backups for Pivotal Cloud Foundry&reg;

BOSH operators running services (e.g. Redis service broker for Cloud Foundry) may want to back up certain files from the virtual machines running these services so that they can restore them after a disaster.

## Using Service Backup

User documentation can be found [here](https://docs.pivotal.io/service-backup).

## Contributing to Service Backup

We welcome contributions to Service Backup.

Below are the steps to clone and work on the Service Backup repo, however, if you have an idea for an improvement, we encourage you to get in touch with us via GitHub, Slack, or email, and we will help you.

### Setting up development environment

- **Clone the repo**:

    ```bash
    git clone git@github.com:pivotal-cf/service-backup-release.git
    ```

    Note that development is carried out on a branch called `master`; this will be checked out by default.

This repository is the BOSH release, and contains the Go code for the service backup daemon and its dependencies as submodules.

- **Ensure the submodules are up to date**:

    ```bash
    cd service-backup-release
    git submodule update --init --recursive
    ```

- **Set the `$GOPATH`**

    The `$GOPATH` should be set to the release directory. To do this automatically, we recommend using `direnv`. In this example, we have used homebrew:

    ```bash
    brew install direnv
    ```

### Deploying a release

- **Update the package spec file**

    When adding or removing submodules to the BOSH release, use the `sync-package-specs` helper script as shown below:

    ```bash
    ./scripts/sync-package-specs
    ```

- **Create your own standalone (i.e. not co-located) BOSH manifest**

    An example of a bosh-lite manifest can be found at `manifests/bosh-lite-deployment.yml.template`.

    The values in the first section must be updated with your own `director_uuid` and `properties`.

- **Deploy the standalone BOSH release**

    As above, the example provided assumes you are using `bosh-lite`:

    ```bash
    bosh target lite # or the alias/IP for your BOSH lite director
    bosh deployment manifests/bosh-lite-deployment.yml
    bosh create release --name service-backup
    bosh upload release
    bosh deploy
    ```

### Committing your changes

- **Update the .gitmodules file**

    When adding or removing submodules to the BOSH release, use the `sync-submodule-config` helper script as shown below:

    ```bash
    ./scripts/sync-submodule-config
    ```

    This script will overwrite the `.gitmodules` file. Due to a [bug in gosub](https://github.com/vito/gosub/issues/1), it will replace `git@` with
    `https://`. This needs to be manually corrected for any private repositories, e.g. `pivotal-cf/service-backup`.

- **Send a pull request**

    Set up a pull request to the service-backup repository. Remember that development is carried out on a branch called `master`; please submit to this branch!
