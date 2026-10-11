{{- define "hive.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "hive.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "hive.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* The ServiceAccount the pods run as: the release name (the Vault auth role binds to it). */}}
{{- define "hive.serviceAccountName" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "hive.labels" -}}
helm.sh/chart: {{ include "hive.chart" . }}
{{ include "hive.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end -}}

{{- define "hive.selectorLabels" -}}
app.kubernetes.io/name: {{ include "hive.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "hive.image" -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) -}}
{{- end -}}

{{/* The Redis URL: the bundled subchart's master service, else whatever conf says (may be empty). */}}
{{- define "hive.redisUrl" -}}
{{- if .Values.components.redis -}}
{{- printf "redis://%s-redis-master:6379/0" .Release.Name -}}
{{- else -}}
{{- index .Values.conf "HIVE_REDIS_URL" | default "" -}}
{{- end -}}
{{- end -}}

{{/*
Vault Agent Injector annotations. Renders nothing unless vault.enabled.
agent-pre-populate-only injects only an init container (the secrets are
static); agent-run-as-same-user makes the agent run as the workload UID so
the rendered file is readable by the app.
*/}}
{{- define "hive.vaultAnnotations" -}}
{{- $v := .Values.vault -}}
{{- if $v.enabled }}
vault.hashicorp.com/agent-inject: "true"
vault.hashicorp.com/agent-pre-populate-only: "true"
vault.hashicorp.com/agent-run-as-same-user: "true"
vault.hashicorp.com/role: {{ required "vault.role is required when vault.enabled" $v.role | quote }}
vault.hashicorp.com/agent-inject-secret-env: {{ required "vault.settingsSecret is required when vault.enabled" $v.settingsSecret | quote }}
vault.hashicorp.com/agent-inject-template-env: {{ include "hive.vaultEnvTemplate" . | quote }}
{{- with $v.annotations }}
{{ toYaml . }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
The Vault Agent template that renders /vault/secrets/env: one
`export KEY="VAL"` line per key of the settings secret, so the secret's keys
ARE the environment variable names. The literal {{ }} below are emitted
verbatim for the agent (consul-template), not evaluated by Helm.
*/}}
{{- define "hive.vaultEnvTemplate" -}}
{{- printf "{{ with secret %q }}{{ range $k, $v := .Data.data }}export {{ $k }}=\"{{ $v }}\"\n{{ end }}{{ end }}" .Values.vault.settingsSecret -}}
{{- end -}}

{{/*
The container command: sources the Vault-rendered env file (when
vault.enabled) before exec-ing hive-web, so secrets reach the process without
a Kubernetes Secret.
*/}}
{{- define "hive.command" -}}
{{- $cmd := "hive-web --host 0.0.0.0 --port 8080" -}}
{{- if .Values.vault.enabled -}}
["/bin/sh", "-c", {{ printf ". /vault/secrets/env && exec %s" $cmd | quote }}]
{{- else -}}
["/bin/sh", "-c", {{ printf "exec %s" $cmd | quote }}]
{{- end -}}
{{- end -}}

{{- define "hive.podAntiAffinity" -}}
{{- if eq .Values.podAntiAffinityPreset "hard" }}
podAntiAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchLabels:
          {{- include "hive.selectorLabels" . | nindent 10 }}
      topologyKey: kubernetes.io/hostname
{{- else if eq .Values.podAntiAffinityPreset "soft" }}
podAntiAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 1
      podAffinityTerm:
        labelSelector:
          matchLabels:
            {{- include "hive.selectorLabels" . | nindent 12 }}
        topologyKey: kubernetes.io/hostname
{{- end }}
{{- end -}}
