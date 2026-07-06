# template-exposed-service

A Crossplane Configuration package that defines the `ExposedService` resource: a namespaced custom
resource that publishes an in-cluster Kubernetes Service on a public HTTPS URL.

Creating an `ExposedService` makes the composition create one Gateway API `HTTPRoute` that attaches the
Service to a shared `Gateway`. TLS and DNS come from cluster infrastructure, not from this package: the
shared Gateway terminates TLS with a wildcard certificate, and External-DNS creates the DNS record from
the route's hostname. The composition creates no Certificate, Secret, or DNS resource of its own.

## API

```yaml
apiVersion: openportal.dev/v1alpha1
kind: ExposedService
metadata:
  name: my-app
  namespace: my-team
spec:
  serviceName: my-app            # in-cluster Service, same namespace as this resource
  port: 8080                     # defaults to 80
  hostname: my-app               # full hostname used as-is; a bare label gets .<baseDomain> appended
  tls:   { enabled: true }       # served by the shared Gateway's HTTPS listener
  dns:   { proxied: false }      # sets the external-dns cloudflare-proxied annotation
```

Once the route is programmed, `status.url` is `https://<hostname>`.

## Cluster-specific values come from an EnvironmentConfig

The shared Gateway reference and the base domain are not hardcoded in the composition. The composition
reads them from an `EnvironmentConfig` named `gateway-config`:

| key | meaning |
|---|---|
| `gatewayName` | name of the shared Gateway |
| `gatewayNamespace` | namespace of the shared Gateway |
| `baseDomain` | suffix appended to bare-label hostnames; the wildcard certificate's domain |

Because these values live outside the composition, the same `ExposedService` renders correctly on
different clusters and against different Gateway API implementations without any change to the resource
or the composition.

The `gateway-config` EnvironmentConfig is installed once per cluster by the platform, alongside the
Gateway, the TLS issuer, and External-DNS. This package does not install it. See
`environment/gateway-config.example.yaml` for the expected keys.

## Install

```bash
kubectl apply -f - <<EOF
apiVersion: pkg.crossplane.io/v1
kind: Configuration
metadata:
  name: configuration-exposed-service
  namespace: crossplane-system
spec:
  package: ghcr.io/open-service-portal/configuration-exposed-service:latest
EOF
```

## Test

```bash
bash tests/run-tests.sh
```

The script runs `crossplane render` on the examples and checks the output. It needs the Crossplane CLI
(v2 or later) and a container runtime. See `tests/README.md` for the checks and their coverage.

## Layout

```
configuration/   crossplane.yaml (package metadata), xrd.yaml, composition.yaml
examples/        sample ExposedService resources
environment/     gateway-config.example.yaml (the per-cluster EnvironmentConfig contract)
tests/           functions.yaml, render/*.yaml, run-tests.sh
```

## Scope

This repository contains the `ExposedService` template only. The cluster infrastructure it depends on
(the Gateway, the TLS issuer, and External-DNS) is installed separately by the platform. End-to-end
validation on a live cluster, meaning a browser-trusted HTTPS response, is a manual step and is not
covered by the render tests here.
