# CLAUDE.md — template-exposed-service

Crossplane Configuration package for the `ExposedService` composite resource (a Gateway API HTTPRoute,
with TLS and DNS provided by the platform). This repository contains the template only.

## Conventions (open-service-portal `template-*`)
- Crossplane v2, XRD `scope: Namespaced` (direct composite resources, no claims).
- Composition in Pipeline mode; the functions it uses are installed cluster-wide (see below).
- Built as a Configuration package (`configuration/crossplane.yaml`), published to
  `ghcr.io/open-service-portal/configuration-exposed-service`.
- Released by pushing a `vX.Y.Z` tag (`.github/workflows/release.yaml`); the version is stamped onto `xrd.yaml`.

## The one design rule
Cluster-specific values (`gatewayName`, `gatewayNamespace`, `baseDomain`) must come from the
`gateway-config` EnvironmentConfig, never hardcoded. The composition loads it with
`function-environment-configs` (pipeline step `environment`) and reads
`index .context "apiextensions.crossplane.io/environment"`. The template defaults
(`openportal` / `gateway-system`) are a fallback only.

## Composition pipeline
1. `environment`: `function-environment-configs` references the `gateway-config` EnvironmentConfig.
2. `render`: `function-go-templating` authors one provider-kubernetes `Object` wrapping an `HTTPRoute`
   and sets `status.url`. A full hostname is used as-is; a bare label becomes `<label>.<baseDomain>`.
3. `auto-ready`: `function-auto-ready`.

The composition authors no Certificate, Secret, or DNS resource. TLS is the shared Gateway's wildcard
certificate; DNS is created by External-DNS from the route hostname.

## Functions (must exist in-cluster; pinned for render in `tests/functions.yaml`)
`function-environment-configs`, `function-go-templating`, `function-auto-ready`.

## Testing
`bash tests/run-tests.sh` runs `crossplane render` per case and asserts the acceptance criteria.
It needs the Crossplane CLI (v2 or later) and a container runtime; the script detects a non-default
Docker socket (for example Rancher Desktop or colima) through `docker context`. When the rendered
output changes, edit the assertions surgically and keep their labels.

## Boundaries (out of scope for this repository)
- Per-cluster infrastructure: the Gateway and its controller, the cert-manager DNS-01 issuer,
  External-DNS, and the `gateway-config` EnvironmentConfig itself. These live in the platform cluster
  setup, not here.
- Consumer wiring: another template composing an `ExposedService` for its own Service (for example a
  database template exposing its admin UI) belongs in that template's repository.
