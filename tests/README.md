# tests/

Render tests for the `ExposedService` composition. They run `crossplane render` (functions execute in
Docker) and assert the acceptance criteria of `specs/exposed-service` (US-exp-1..3).

```bash
bash tests/run-tests.sh
```

**Requirements:** crossplane CLI (>=v2) + a container runtime. The runner auto-detects a non-default
Docker socket (Rancher Desktop / colima) via `docker context`; set `DOCKER_HOST` yourself to override.

## Files
| file | role |
|---|---|
| `functions.yaml` | Function packages for render (versions match the platform install) |
| `render/xr-full.yaml` | full-FQDN order (valkey-admin) |
| `render/xr-minimal.yaml` | bare-label order (→ suffixed with baseDomain) |
| `render/environment-a.yaml` | cluster A EnvironmentConfig (openportal / gateway-system / openportal.dev) |
| `render/environment-b.yaml` | cluster B EnvironmentConfig (edge-gw / edge-system / example.test) |
| `run-tests.sh` | renders each case + asserts the ACs |

## Coverage
| AC | test group | automated |
|---|---|---|
| AC-exp-1-1 HTTPRoute + Gateway from env | render/httproute | ✅ |
| AC-exp-1-2 / 2-2 no cert / secret | render/tls, render/no-secrets | ✅ |
| AC-exp-1-3 proxied annotation, no DNS CR | render/dns | ✅ |
| AC-exp-3-1 portability (two EnvironmentConfigs) | render/env-portability | ✅ |
| AC-exp-1-4 E2E browser-trusted HTTPS | — | ❌ manual (ESG-T2b infra) |
| AC-exp-2-1 issuer/listener Ready on cluster | — | ❌ infra (ESG-T2b) |
| AC-exp-4-1 template-valkey composes ExposedService | — | ❌ lives in template-valkey (ESG-T4) |

When output changes, edit assertions in `run-tests.sh` **surgically** — keep the AC labels.
