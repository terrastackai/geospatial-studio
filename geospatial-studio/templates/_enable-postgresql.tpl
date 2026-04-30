{{- if .Values.global.postgresql.enabled }}
# This file ensures the postgresql subchart is enabled when global.postgresql.enabled=true
# The actual PostgreSQL configuration is in the global.postgresql section of values.yaml
{{- end }}
