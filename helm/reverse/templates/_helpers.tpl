{{- define "reverse.name" -}}
reverse
{{- end -}}

{{- define "reverse.fullname" -}}
{{ .Release.Name }}
{{- end -}}

{{- define "reverse.selectorLabels" -}}
app.kubernetes.io/name: {{ include "reverse.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "reverse.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{ include "reverse.selectorLabels" . }}
{{- end -}}
