{{- define "edge-nginx.listen-http" -}}
listen 80;
{{- end -}}

{{- define "edge-nginx.listen-https" -}}
listen 443 ssl;
ssl_certificate     /etc/nginx/tls/tls.crt;
ssl_certificate_key /etc/nginx/tls/tls.key;
{{- end -}}

{{- define "edge-nginx.proxy-headers" -}}
proxy_set_header Host $host;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
{{- end -}}
