# CLAUDE.md — template-exposed-service

Crossplane Configuration package for the `ExposedService` XR (Gateway API HTTPRoute + platform TLS/DNS).
Part of the **ESG** track (ExposedService via Gateway API). This repo = **ESG-T2a** (the template only).

## Conventions (osp `template-*`)
- Crossplane **v2**, XRD `scope: Namespaced` (direct XRs, no claims).
- Composition **Pipeline** mode; functions installed platform-wide (see below).
- Package built as a **Configuration** (`configuration/crossplane.yaml`) → `ghcr.io/open-service-portal/configuration-exposed-service`.
- Released by tagging `vX.Y.Z` (`.github/workflows/release.yaml`); the version is stamped onto `xrd.yaml`.

## The one design rule (AC-exp-3-1)
Cluster-specific values — `gatewayName`, `gatewayNamespace`, `baseDomain` — MUST come from the
`gateway-config` **EnvironmentConfig**, never hardcoded. The composition loads it via
`function-environment-configs` (step `environment`) and reads
`index .context "apiextensions.crossplane.io/environment"`. Defaults in the template
(`openportal` / `gateway-system`) are a fallback only.

## Composition pipeline
1. `environment` — `function-environment-configs`, refs EnvironmentConfig `gateway-config`.
2. `render` — `function-go-templating`, authors ONE provider-kubernetes `Object` wrapping a `HTTPRoute`
   (+ sets `status.url`). Full-FQDN hostname used as-is; bare label → `<label>.<baseDomain>`.
3. `auto-ready` — `function-auto-ready`.

Authors **no** Certificate/Secret/DNS resource (TLS = shared Gateway wildcard, DNS = External-DNS).

## Functions (must exist in-cluster; pinned for render in `tests/functions.yaml`)
`function-environment-configs` · `function-go-templating` · `function-auto-ready`.

## Testing
`bash tests/run-tests.sh` — runs `crossplane render` per case and asserts the ACs (US-exp-1..3).
Needs the crossplane CLI (>=v2) + a container runtime; the script auto-detects a non-default Docker
socket (Rancher Desktop / colima) via `docker context`. Edit assertions surgically when output changes.

## Boundaries (do NOT do here)
- **Per-cluster infra** (Gateway, Traefik, cert-manager DNS-01, External-DNS, the `gateway-config`
  EnvironmentConfig itself) → **ESG-T2b**, lives in the platform `cluster-setup`, owned by the Mac/infra session.
- **Consumer wiring** (`template-valkey` composing an ExposedService for its admin UI) → **ESG-T4 / US-exp-4**.
