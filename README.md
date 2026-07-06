# template-exposed-service

Crossplane Configuration for **ExposedService** — publish an in-cluster `Service` over HTTPS with a
single order. The composition authors **one** Gateway API `HTTPRoute` attached to the platform's shared
`Gateway`; **TLS and DNS are automatic platform behaviours** (shared wildcard cert on the Gateway
listener + External-DNS from the route hostname). No per-service certificate, secret, or DNS record.

> Restaurant analogy: the **menu** (XRD) lets a developer *order* a public hostname for their Service;
> the **kitchen** (Composition) plates a single HTTPRoute and the house (platform) handles TLS + DNS.

Built from the lab-proven manifests in `exposed-service-gateway-api/impl/` (ESG track). Design &
decision record: `open-service-portal/open-service-portal#135`.

## API

```yaml
apiVersion: openportal.dev/v1alpha1
kind: ExposedService
metadata:
  name: my-app
  namespace: my-team
spec:
  serviceName: my-app            # in-cluster Service (same namespace)
  port: 8080                     # default 80
  hostname: my-app               # full FQDN used as-is; a bare label gets .<baseDomain>
  tls:   { enabled: true }       # served by the shared Gateway HTTPS listener
  dns:   { proxied: false }      # -> external-dns cloudflare-proxied annotation
```

`status.url` is `https://<hostname>` once the route is programmed.

## Cluster-specific values come from an EnvironmentConfig (not the XR)

The shared Gateway reference and base domain are **not** hardcoded in the composition — they are read
from a `gateway-config` `EnvironmentConfig` (AC-exp-3-1), so the same `ExposedService` is portable
across clusters and Gateway implementations:

| key | meaning |
|---|---|
| `gatewayName` | `metadata.name` of the shared Gateway |
| `gatewayNamespace` | namespace of the shared Gateway |
| `baseDomain` | suffix for bare-label hostnames; the wildcard cert domain |

See `environment/gateway-config.example.yaml`. The EnvironmentConfig itself is installed **once per
cluster by the platform infra** (ESG-T2b), alongside Gateway API + Traefik + cert-manager DNS-01 +
External-DNS — **not** by this package.

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
bash tests/run-tests.sh    # crossplane render + assertions (US-exp-1..3); needs crossplane CLI + Docker
```

## Layout

```
configuration/   crossplane.yaml (package meta) · xrd.yaml · composition.yaml
examples/        valkey-admin.yaml (first consumer) · minimal.yaml
environment/     gateway-config.example.yaml (the per-cluster contract)
tests/           functions.yaml · render/*.yaml · run-tests.sh
```

## Scope note

This repo is **ESG-T2a** (the template). Per-cluster infra is **ESG-T2b**; the Valkey Admin consumer
wiring is **US-exp-4 / ESG-T4** in `template-valkey`. E2E (AC-exp-1-4) is validated on a live cluster,
not in these render tests.
