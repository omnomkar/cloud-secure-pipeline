{{- define "secure-cloud-pipeline.name" -}}
{{- .Chart.Name -}}
{{- end -}}

{{- define "secure-cloud-pipeline.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "secure-cloud-pipeline.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "secure-cloud-pipeline.labels" -}}
app.kubernetes.io/name: {{ include "secure-cloud-pipeline.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end -}}

{{- define "secure-cloud-pipeline.selectorLabels" -}}
app.kubernetes.io/name: {{ include "secure-cloud-pipeline.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
