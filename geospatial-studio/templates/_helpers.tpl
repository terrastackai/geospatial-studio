{{/*
Check if PgBouncer is enabled
*/}}
{{- define "geospatial-studio.pgbouncer.enabled" -}}
{{ .Values.pgbouncer.enabled }}
{{- end }}

{{/*
Get database host - returns pgbouncer host if enabled, otherwise postgres host
*/}}
{{- define "geospatial-studio.postgres.host" -}}
{{- if .Values.global.pgbouncer.enabled -}}
{{ .Values.global.pgbouncer.host }}
{{- else -}}
{{ .Values.global.postgres.postgres_host }}
{{- end -}}
{{- end }}

{{/*
Get database port - returns pgbouncer port if enabled, otherwise postgres port
*/}}
{{- define "geospatial-studio.postgres.port" -}}
{{- if .Values.global.pgbouncer.enabled -}}
{{ .Values.global.pgbouncer.port }}
{{- else -}}
{{ .Values.global.postgres.postgres_port }}
{{- end -}}
{{- end }}

{{/*
Get direct postgres host (always returns postgres host, never pgbouncer)
Used for jobs that need direct database access
*/}}
{{- define "geospatial-studio.postgres.direct.host" -}}
{{ .Values.global.postgres.postgres_host }}
{{- end }}

{{/*
Get direct postgres port (always returns postgres port, never pgbouncer)
Used for jobs that need direct database access
*/}}
{{- define "geospatial-studio.postgres.direct.port" -}}
{{ .Values.global.postgres.postgres_port }}
{{- end }}

{{/*
Build DATABASE_URI for gateway database
<<<<<<< HEAD
<<<<<<< HEAD
Uses pgbouncer pool if enabled, otherwise direct postgres
=======
Uses pgbouncer if enabled, otherwise direct postgres
>>>>>>> 42c9d82 (✨ feat(pgbouncer): add connection pooling with deployment improvements)
=======
Uses pgbouncer pool if enabled, otherwise direct postgres
>>>>>>> b566d2e (✨ feat(pgbouncer): add isolated connection pools to prevent service starvation)
*/}}
{{- define "geospatial-studio.postgres.gateway.uri" -}}
{{- if .Values.global.postgres.in_cluster_db -}}
postgresql+pg8000://{{ .Values.global.postgresql.auth.username }}:{{ .Values.global.postgresql.auth.password }}@{{ .Release.Name }}-postgresql-hl.{{ .Release.Namespace }}.svc/{{ .Values.global.postgresql.dbs.gateway }}
{{- else -}}
{{- $host := include "geospatial-studio.postgres.host" . -}}
{{- $port := include "geospatial-studio.postgres.port" . -}}
<<<<<<< HEAD
<<<<<<< HEAD
=======
>>>>>>> b566d2e (✨ feat(pgbouncer): add isolated connection pools to prevent service starvation)
{{- if .Values.global.pgbouncer.enabled -}}
{{- /* Use PgBouncer pool for gateway API */ -}}
postgresql+pg8000://{{ .Values.global.postgres.postgres_user }}:{{ .Values.global.postgres.postgres_password }}@{{ $host }}:{{ $port }}/geostudio_api_pool
{{- else -}}
{{- /* Direct connection to database */ -}}
postgresql+pg8000://{{ .Values.global.postgres.postgres_user }}:{{ .Values.global.postgres.postgres_password }}@{{ $host }}:{{ $port }}/{{ .Values.global.postgres.dbs.gateway }}
{{- end -}}
{{- end -}}
<<<<<<< HEAD
=======
postgresql+pg8000://{{ .Values.global.postgres.postgres_user }}:{{ .Values.global.postgres.postgres_password }}@{{ $host }}:{{ $port }}/{{ .Values.global.postgres.dbs.gateway }}
{{- end -}}
>>>>>>> 42c9d82 (✨ feat(pgbouncer): add connection pooling with deployment improvements)
=======
>>>>>>> b566d2e (✨ feat(pgbouncer): add isolated connection pools to prevent service starvation)
{{- end }}

{{/*
Build AUTH_DATABASE_URI for auth database
<<<<<<< HEAD
<<<<<<< HEAD
Uses pgbouncer if enabled (pool name matches database name), otherwise direct postgres
=======
Uses pgbouncer if enabled, otherwise direct postgres
>>>>>>> 42c9d82 (✨ feat(pgbouncer): add connection pooling with deployment improvements)
=======
Uses pgbouncer if enabled (pool name matches database name), otherwise direct postgres
>>>>>>> b566d2e (✨ feat(pgbouncer): add isolated connection pools to prevent service starvation)
*/}}
{{- define "geospatial-studio.postgres.auth.uri" -}}
{{- if .Values.global.postgres.in_cluster_db -}}
postgresql+pg8000://{{ .Values.global.postgresql.auth.username }}:{{ .Values.global.postgresql.auth.password }}@{{ .Release.Name }}-postgresql-hl.{{ .Release.Namespace }}.svc/{{ .Values.global.postgresql.dbs.auth }}
{{- else -}}
{{- $host := include "geospatial-studio.postgres.host" . -}}
{{- $port := include "geospatial-studio.postgres.port" . -}}
<<<<<<< HEAD
<<<<<<< HEAD
{{- /* Pool name matches database name, so same URI works for both PgBouncer and direct */ -}}
=======
>>>>>>> 42c9d82 (✨ feat(pgbouncer): add connection pooling with deployment improvements)
=======
{{- /* Pool name matches database name, so same URI works for both PgBouncer and direct */ -}}
>>>>>>> b566d2e (✨ feat(pgbouncer): add isolated connection pools to prevent service starvation)
postgresql+pg8000://{{ .Values.global.postgres.postgres_user }}:{{ .Values.global.postgres.postgres_password }}@{{ $host }}:{{ $port }}/{{ .Values.global.postgres.dbs.auth }}
{{- end -}}
{{- end }}

{{/*
Build MLFLOW_DATABASE_URI for mlflow database
<<<<<<< HEAD
<<<<<<< HEAD
Uses pgbouncer if enabled (pool name matches database name), otherwise direct postgres
=======
Uses pgbouncer if enabled, otherwise direct postgres
>>>>>>> 42c9d82 (✨ feat(pgbouncer): add connection pooling with deployment improvements)
=======
Uses pgbouncer if enabled (pool name matches database name), otherwise direct postgres
>>>>>>> b566d2e (✨ feat(pgbouncer): add isolated connection pools to prevent service starvation)
*/}}
{{- define "geospatial-studio.postgres.mlflow.uri" -}}
{{- if .Values.global.postgres.in_cluster_db -}}
postgresql+pg8000://{{ .Values.global.postgresql.auth.username }}:{{ .Values.global.postgresql.auth.password }}@{{ .Release.Name }}-postgresql-hl.{{ .Release.Namespace }}.svc/{{ .Values.global.postgresql.dbs.mlflow }}
{{- else -}}
{{- $host := include "geospatial-studio.postgres.host" . -}}
{{- $port := include "geospatial-studio.postgres.port" . -}}
<<<<<<< HEAD
<<<<<<< HEAD
{{- /* Pool name matches database name, so same URI works for both PgBouncer and direct */ -}}
=======
>>>>>>> 42c9d82 (✨ feat(pgbouncer): add connection pooling with deployment improvements)
=======
{{- /* Pool name matches database name, so same URI works for both PgBouncer and direct */ -}}
>>>>>>> b566d2e (✨ feat(pgbouncer): add isolated connection pools to prevent service starvation)
postgresql+pg8000://{{ .Values.global.postgres.postgres_user }}:{{ .Values.global.postgres.postgres_password }}@{{ $host }}:{{ $port }}/{{ .Values.global.postgres.dbs.mlflow }}
{{- end -}}
{{- end }}

{{/*
Build orchestration database URI for pipelines
<<<<<<< HEAD
<<<<<<< HEAD
Uses pgbouncer if enabled (pool name matches database name), otherwise direct postgres
=======
Uses pgbouncer if enabled, otherwise direct postgres
>>>>>>> 42c9d82 (✨ feat(pgbouncer): add connection pooling with deployment improvements)
=======
Uses pgbouncer if enabled (pool name matches database name), otherwise direct postgres
>>>>>>> b566d2e (✨ feat(pgbouncer): add isolated connection pools to prevent service starvation)
*/}}
{{- define "geospatial-studio.postgres.orchestrate.uri" -}}
{{- $host := include "geospatial-studio.postgres.host" . -}}
{{- $port := include "geospatial-studio.postgres.port" . -}}
<<<<<<< HEAD
<<<<<<< HEAD
{{- /* Pool name matches database name, so same URI works for both PgBouncer and direct */ -}}
=======
>>>>>>> 42c9d82 (✨ feat(pgbouncer): add connection pooling with deployment improvements)
=======
{{- /* Pool name matches database name, so same URI works for both PgBouncer and direct */ -}}
>>>>>>> b566d2e (✨ feat(pgbouncer): add isolated connection pools to prevent service starvation)
postgresql+pg8000://{{ .Values.global.postgres.postgres_user }}:{{ .Values.global.postgres.postgres_password }}@{{ $host }}:{{ $port | int }}/{{ .Values.global.postgres.dbs.gateway }}
{{- end }}

{{/*
Build MLflow backend URI (without +pg8000 driver)
<<<<<<< HEAD
<<<<<<< HEAD
Uses pgbouncer if enabled (pool name matches database name), otherwise direct postgres
=======
Uses pgbouncer if enabled, otherwise direct postgres
>>>>>>> 42c9d82 (✨ feat(pgbouncer): add connection pooling with deployment improvements)
=======
Uses pgbouncer if enabled (pool name matches database name), otherwise direct postgres
>>>>>>> b566d2e (✨ feat(pgbouncer): add isolated connection pools to prevent service starvation)
*/}}
{{- define "geospatial-studio.postgres.mlflow.backend.uri" -}}
{{- $host := include "geospatial-studio.postgres.host" . -}}
{{- $port := include "geospatial-studio.postgres.port" . -}}
<<<<<<< HEAD
<<<<<<< HEAD
{{- /* Pool name matches database name, so same URI works for both PgBouncer and direct */ -}}
=======
>>>>>>> 42c9d82 (✨ feat(pgbouncer): add connection pooling with deployment improvements)
=======
{{- /* Pool name matches database name, so same URI works for both PgBouncer and direct */ -}}
>>>>>>> b566d2e (✨ feat(pgbouncer): add isolated connection pools to prevent service starvation)
postgresql://{{ .Values.global.postgres.postgres_user }}:{{ .Values.global.postgres.postgres_password }}@{{ $host }}:{{ $port }}/{{ .Values.global.postgres.dbs.mlflow }}
{{- end }}

{{/*
Build DATABASE_URI for jobs (direct postgres connection, bypassing pgbouncer)
Jobs need direct database access for operations like migrations
*/}}
{{- define "geospatial-studio.postgres.gateway.jobs.uri" -}}
{{- if .Values.global.postgres.in_cluster_db -}}
postgresql+pg8000://{{ .Values.global.postgresql.auth.username }}:{{ .Values.global.postgresql.auth.password }}@{{ .Release.Name }}-postgresql-hl.{{ .Release.Namespace }}.svc/{{ .Values.global.postgresql.dbs.gateway }}
{{- else -}}
{{- $host := .Values.global.postgres.postgres_host -}}
{{- $port := .Values.global.postgres.postgres_port -}}
postgresql+pg8000://{{ .Values.global.postgres.postgres_user }}:{{ .Values.global.postgres.postgres_password }}@{{ $host }}:{{ $port }}/{{ .Values.global.postgres.dbs.gateway }}
{{- end -}}
{{- end }}

{{/*
Build AUTH_DATABASE_URI for jobs (direct postgres connection)
*/}}
{{- define "geospatial-studio.postgres.auth.jobs.uri" -}}
{{- if .Values.global.postgres.in_cluster_db -}}
postgresql+pg8000://{{ .Values.global.postgresql.auth.username }}:{{ .Values.global.postgresql.auth.password }}@{{ .Release.Name }}-postgresql-hl.{{ .Release.Namespace }}.svc/{{ .Values.global.postgresql.dbs.auth }}
{{- else -}}
{{- $host := .Values.global.postgres.postgres_host -}}
{{- $port := .Values.global.postgres.postgres_port -}}
postgresql+pg8000://{{ .Values.global.postgres.postgres_user }}:{{ .Values.global.postgres.postgres_password }}@{{ $host }}:{{ $port }}/{{ .Values.global.postgres.dbs.auth }}
{{- end -}}
{{- end }}

{{/*
Build MLFLOW_DATABASE_URI for jobs (direct postgres connection)
*/}}
{{- define "geospatial-studio.postgres.mlflow.jobs.uri" -}}
{{- if .Values.global.postgres.in_cluster_db -}}
postgresql+pg8000://{{ .Values.global.postgresql.auth.username }}:{{ .Values.global.postgresql.auth.password }}@{{ .Release.Name }}-postgresql-hl.{{ .Release.Namespace }}.svc/{{ .Values.global.postgresql.dbs.mlflow }}
{{- else -}}
{{- $host := .Values.global.postgres.postgres_host -}}
{{- $port := .Values.global.postgres.postgres_port -}}
postgresql+pg8000://{{ .Values.global.postgres.postgres_user }}:{{ .Values.global.postgres.postgres_password }}@{{ $host }}:{{ $port }}/{{ .Values.global.postgres.dbs.mlflow }}
{{- end -}}
{{- end }}

{{/*
Build Redis URL based on architecture
*/}}
{{- define "geospatial-studio.redis.url" -}}
{{- if .Values.global.redis.enabled -}}
{{- if eq .Values.global.redis.architecture "standalone" -}}
redis://:{{ .Values.global.redis.password }}@{{ .Release.Name }}-redis-headless.{{ .Release.Namespace }}.svc
{{- else -}}
redis://:{{ .Values.global.redis.password }}@{{ .Values.global.redis.fullnameOverride }}-master.{{ .Release.Namespace }}.svc
{{- end -}}
{{- end -}}
{{- end }}