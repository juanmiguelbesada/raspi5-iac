# ─── Stage 1: Collect tool binaries ───────────────────────────────
FROM hashicorp/terraform:1.15 AS terraform

FROM ghcr.io/terraform-linters/tflint:v0.62.1 AS tflint

FROM aquasec/trivy:0.70.0 AS trivy

# ─── Stage 2: Runtime image ───────────────────────────────────────
FROM alpine:3.23

# Copy tool binaries from their official images
COPY --from=terraform /bin/terraform /usr/local/bin/terraform
COPY --from=tflint    /usr/local/bin/tflint    /usr/local/bin/tflint
COPY --from=trivy     /usr/local/bin/trivy     /usr/local/bin/trivy

# Install Alpine packages
RUN apk add --no-cache \
  nodejs \
  npm \
  py3-pip \
  py3-yaml \
  ansible-lint

RUN npm install -g prettier

# Install Ansible collections required by playbooks
RUN ansible-galaxy collection install community.general ansible.posix

WORKDIR /workspace
