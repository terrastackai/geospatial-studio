# Stage 1: Pull the Helm chart from OCI registry
FROM alpine/helm:latest AS chart-puller

# Set up Helm and pull the chart
WORKDIR /charts
ARG CHART_VERSION=0.1.4
ARG CHART_REGISTRY=oci://quay.io/geospatial-studio/charts
ARG CHART_NAME=geospatial-studio

# Install necessary tools
RUN apk add --no-cache docker-cli

RUN helm pull ${CHART_REGISTRY}/${CHART_NAME} --version ${CHART_VERSION} --untar

# Stage 2: Build the operator image
FROM quay.io/operator-framework/helm-operator:v1.42.0

ENV HOME=/opt/helm
COPY watches.yaml ${HOME}/watches.yaml
COPY --from=chart-puller /charts/geospatial-studio ${HOME}/helm-charts/geospatial-studio
WORKDIR ${HOME}
