## Example Deployments

In order to deploy an on-demand service broker you could use the base manifest and
operation files provided in `examples/deployment`.


To deploy a Redis on-demand service broker execute:

```bash
$ cd deployment
$ bosh -d redis-example-odb deploy base_odb_manifest.yml \
  -o operations/redis.yml \
  -o operations/redis_example_service_catalog.yml \
  -l operations/example_vars.yml \
  --vars-store=creds.yml
```

To deploy a Kafka on-demand service broker execute:

```bash
$ cd deployment
$ bosh -d kafka-example-odb deploy base_odb_manifest.yml \
  -o operations/kafka.yml \
  -o operations/kafka_example_service_catalog.yml \
  -l operations/example_vars.yml \
  -v syslog_forwarding_address=some.example.com \
  -v syslog_forwarding_port=1337 \
  --vars-store=creds.yml
```

Notice that `example_vars.yml` needs to be populated according to your
environment.



