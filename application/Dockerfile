FROM nginxinc/nginx-unprivileged:1.28-alpine

WORKDIR /app

LABEL com.azure.containerizationassist.createdby="containerization-assist"

COPY --chown=101:101 index.html /usr/share/nginx/html/index.html

USER 101:101
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 CMD wget -q -O /dev/null http://127.0.0.1:8080/ || exit 1
