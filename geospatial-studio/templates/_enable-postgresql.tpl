{{- if .Values.infrastructure.postgresql.enabled }}
# This file ensures the postgresql subchart is enabled when infrastructure.postgresql.enabled=true
# The actual PostgreSQL configuration is in the postgresql section of values.yaml
{{- end }}
