{{- define "microservice.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "microservice.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}{{- .Release.Name | trunc 63 | trimSuffix "-" -}}{{- else -}}{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}{{- end -}}
{{- end -}}
{{- end -}}

{{- define "microservice.selectorLabels" -}}
app.kubernetes.io/name: {{ include "microservice.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "microservice.labels" -}}
{{ include "microservice.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
app.kubernetes.io/part-of: smart-hospital-platform
{{- end -}}

{{- define "microservice.image" -}}
{{- if .Values.image.digest -}}
{{ .Values.image.repository }}@{{ .Values.image.digest }}
{{- else if .Values.image.tag -}}
{{ .Values.image.repository }}:{{ .Values.image.tag }}
{{- else -}}
{{- fail "image.digest hoặc image.tag là bắt buộc" -}}
{{- end -}}
{{- end -}}

{{- define "microservice.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{ default (include "microservice.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
{{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/* Pod template dùng chung cho Deployment và Rollout */}}
{{- define "microservice.podTemplate" -}}
metadata:
  labels:
    {{- include "microservice.selectorLabels" . | nindent 4 }}
    {{- if .Values.workloadIdentity.enabled }}
    azure.workload.identity/use: "true"
    {{- end }}
    {{- with .Values.podLabels }}{{ toYaml . | nindent 4 }}{{- end }}
  {{- if or .Values.config .Values.podAnnotations }}
  annotations:
    {{- if .Values.config }}
    checksum/config: {{ toYaml .Values.config | sha256sum }}
    {{- end }}
    {{- with .Values.podAnnotations }}{{ toYaml . | nindent 4 }}{{- end }}
  {{- end }}
spec:
  serviceAccountName: {{ include "microservice.serviceAccountName" . }}
  automountServiceAccountToken: {{ .Values.workloadIdentity.enabled }}
  securityContext:
    {{- toYaml .Values.podSecurityContext | nindent 4 }}
  containers:
    - name: app
      image: {{ include "microservice.image" . | quote }}
      imagePullPolicy: {{ .Values.image.pullPolicy }}
      ports:
        - { name: http, containerPort: {{ .Values.containerPort }} }
      env:
        - { name: ASPNETCORE_URLS, value: {{ printf "http://+:%v" .Values.containerPort | quote }} }
        {{- range $k, $v := .Values.env }}
        - { name: {{ $k }}, value: {{ $v | quote }} }
        {{- end }}
        {{- range .Values.secretEnv }}
        - name: {{ .name }}
          valueFrom: { secretKeyRef: { name: {{ .secretName }}, key: {{ .key }} } }
        {{- end }}
      {{- if .Values.config }}
      envFrom:
        - configMapRef: { name: {{ include "microservice.fullname" . }} }
      {{- end }}
      startupProbe:
        httpGet: { path: {{ .Values.probes.readyPath }}, port: http }
        {{- toYaml .Values.probes.startup | nindent 8 }}
      readinessProbe:
        httpGet: { path: {{ .Values.probes.readyPath }}, port: http }
        {{- toYaml .Values.probes.readiness | nindent 8 }}
      livenessProbe:
        httpGet: { path: {{ .Values.probes.livePath }}, port: http }
        {{- toYaml .Values.probes.liveness | nindent 8 }}
      resources:
        {{- toYaml .Values.resources | nindent 8 }}
      securityContext:
        {{- toYaml .Values.containerSecurityContext | nindent 8 }}
      volumeMounts:
        - { name: tmp, mountPath: /tmp }
        {{- if .Values.keyVault.enabled }}
        - { name: secrets-store, mountPath: {{ .Values.keyVault.mountPath }}, readOnly: true }
        {{- end }}
  volumes:
    - { name: tmp, emptyDir: {} }
    {{- if .Values.keyVault.enabled }}
    - name: secrets-store
      csi:
        driver: secrets-store.csi.k8s.io
        readOnly: true
        volumeAttributes: { secretProviderClass: {{ include "microservice.fullname" . }} }
    {{- end }}
  {{- if and .Values.topologySpread.enabled (gt (int .Values.replicaCount) 1) }}
  topologySpreadConstraints:
    - maxSkew: {{ .Values.topologySpread.maxSkew }}
      topologyKey: topology.kubernetes.io/zone
      whenUnsatisfiable: ScheduleAnyway
      labelSelector:
        matchLabels:
          {{- include "microservice.selectorLabels" . | nindent 10 }}
  {{- end }}
  {{- with .Values.nodeSelector }}
  nodeSelector: {{ toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.tolerations }}
  tolerations: {{ toYaml . | nindent 4 }}
  {{- end }}
{{- end -}}
