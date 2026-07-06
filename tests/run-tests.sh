#!/usr/bin/env bash
# Render tests for template-exposed-service. Exercises the composition with `crossplane render`
# and asserts the acceptance criteria of specs/exposed-service (US-exp-1..3).
# Requires: crossplane CLI (>=v2) + a container runtime (functions run via Docker).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="$HERE/../configuration"

# crossplane render runs functions via Docker. If the default socket is absent (e.g. Rancher
# Desktop / colima), point the Docker SDK at the active context's socket.
if [ -z "${DOCKER_HOST:-}" ] && [ ! -S /var/run/docker.sock ]; then
  ctx_host="$(docker context inspect 2>/dev/null | grep -m1 '"Host"' | sed -E 's/.*"(unix:\/\/[^"]+)".*/\1/')"
  [ -n "$ctx_host" ] && export DOCKER_HOST="$ctx_host"
fi
FUNCS="$HERE/functions.yaml"
fails=0

render() {  # render <xr> <extra-env> -> stdout
  crossplane render "$1" "$CFG/composition.yaml" "$FUNCS" --extra-resources "$2" 2>/dev/null
}
assert()     { if grep -qF -- "$2" <<<"$1"; then echo "  ✓ $3"; else echo "  ✗ $3 (missing: $2)"; fails=$((fails+1)); fi; }
refute()     { if grep -qF -- "$2" <<<"$1"; then echo "  ✗ $3 (unexpected: $2)"; fails=$((fails+1)); else echo "  ✓ $3"; fi; }

echo "== US-exp-1 / render/httproute — full FQDN + Gateway from EnvironmentConfig =="
OUT="$(render "$HERE/render/xr-full.yaml" "$HERE/render/environment-a.yaml")"
assert "$OUT" "kind: HTTPRoute"                 "AC-exp-1-1 authors an HTTPRoute"
assert "$OUT" "valkey-admin.openportal.dev"     "AC-exp-1-1 hostname = spec.hostname"
assert "$OUT" "name: openportal"                "AC-exp-1-1 parentRef gatewayName from env"
assert "$OUT" "namespace: gateway-system"       "AC-exp-1-1 parentRef gatewayNamespace from env"
assert "$OUT" "port: 8080"                       "AC-exp-1-1 backend port"

echo "== render/tls + render/no-secrets — no cert/secret authored (AC-exp-1-2, 2-2) =="
refute "$OUT" "kind: Certificate"               "AC-exp-1-2 no Certificate"
refute "$OUT" "kind: Secret"                    "AC-exp-2-2 no Secret"
refute "$OUT" "certificateRefs"                 "AC-exp-1-2 no per-route cert ref"
refute "$OUT" "secretName"                      "AC-exp-2-2 no secretName"

echo "== render/dns — proxied annotation + no DNS CR (AC-exp-1-3) =="
assert "$OUT" 'external-dns.alpha.kubernetes.io/cloudflare-proxied: "false"' "AC-exp-1-3 proxied annotation"
refute "$OUT" "kind: DNSEndpoint"               "AC-exp-1-3 no DNSEndpoint authored"
refute "$OUT" "kind: DNSRecord"                 "AC-exp-1-3 no DNSRecord authored"

echo "== render/env-portability — same XR, two EnvironmentConfigs -> two Gateways/domains (AC-exp-3-1) =="
A="$(render "$HERE/render/xr-minimal.yaml" "$HERE/render/environment-a.yaml")"
B="$(render "$HERE/render/xr-minimal.yaml" "$HERE/render/environment-b.yaml")"
assert "$A" "my-app.openportal.dev"             "cluster A: bare label + baseDomain A"
assert "$A" "name: openportal"                  "cluster A: gateway A"
assert "$B" "my-app.example.test"               "cluster B: bare label + baseDomain B"
assert "$B" "name: edge-gw"                     "cluster B: gateway B"
refute "$B" "my-app.openportal.dev"             "cluster B: no leak of domain A"

echo
if [ "$fails" -eq 0 ]; then echo "ALL PASS"; else echo "$fails ASSERTION(S) FAILED"; exit 1; fi
