{{/*
© Copyright IBM Corporation 2025
SPDX-License-Identifier: Apache-2.0
*/}}


{{/*
Expand the name of the chart.
*/}}
{{- define "gfm-mlflow.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
}}
{{- define "gfm-mlflow.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end */}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "gfm-mlflow.fullname" -}}
{{- printf .Values.global.appNames.mlflow }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "gfm-mlflow.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "gfm-mlflow.labels" -}}
helm.sh/chart: {{ include "gfm-mlflow.chart" . }}
{{ include "gfm-mlflow.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "gfm-mlflow.selectorLabels" -}}
app.kubernetes.io/name: {{ include "gfm-mlflow.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "gfm-mlflow.serviceAccountName" -}}
{{- if .Values.global.serviceAccount.create }}
{{- default (include "gfm-mlflow.fullname" .) .Values.global.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.global.serviceAccount.name }}
{{- end }}
{{- end }}


{{/*
Create chart ingress label for cash. - copied over from geoserver
*/}}
{{- define "gfm-mlflow.ingresslabel" -}}
ingress-router: cash
{{- end }}
