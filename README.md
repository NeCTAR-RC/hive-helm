# hive-helm

Helm chart for [Hive](https://github.com/NeCTAR-RC/hive), the Nectar
Research Cloud dashboard: one Deployment (FastAPI serving the API and the
built SPA), with an optional Bitnami Redis subchart for sessions and caches.

Hive needs Redis. The subchart is off by default: either point
`conf.HIVE_REDIS_URL` at an existing Redis, or set `components.redis: true`
to deploy the bundled one.

## Configuration

Everything non-secret is a `HIVE_*` environment variable under `conf:`;
see `backend/hive/config.py` in the hive repo. Secrets come from Vault:
`secret/data/k8s/<namespace>/<release>/settings` holds `HIVE_SECRET_KEY`,
`HIVE_SENTRY_DSN` and `HIVE_PASSWORD_RESET_TOKEN` (the shared original
password Horizon's reset password view uses), each key being
the environment variable name. The pods run as a ServiceAccount named after
the release, which the Vault Kubernetes auth role binds to.

Each deployment also needs:

- an HTTPRoute hostname (`gateway.hostnames`), with the matching
  `https://<hostname>/auth/websso/` added to manuka's whitelist so it can
  POST login tokens to Hive;
- `conf.HIVE_PUBLIC_URL` set to that hostname.

Releases: Jenkins bumps `appVersion` on every hive image tag and packages
the chart to `oci://registry.rc.nectar.org.au/nectar-helm`; Renovate then
proposes the new chart version in the argocd-apps repos. Do not hand-edit
`appVersion`.
