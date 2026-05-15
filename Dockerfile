FROM alpine:3.23

RUN apk add --no-cache \
  terraform \
  tflint \
  trivy \
  nodejs \
  npm \
  py3-pip \
  py3-pyyaml \
  ansible-lint

RUN npm install -g prettier

WORKDIR /workspace
