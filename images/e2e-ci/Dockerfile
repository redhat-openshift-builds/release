FROM registry.access.redhat.com/ubi9/ubi:latest AS builder

ARG OPERATOR_SDK_VERSION=1.36.1
ARG OC_VERSION=4.17
ARG TARGETARCH=amd64

RUN curl -Lo /tmp/operator-sdk \
    "https://github.com/operator-framework/operator-sdk/releases/download/v${OPERATOR_SDK_VERSION}/operator-sdk_linux_${TARGETARCH}" && \
    chmod +x /tmp/operator-sdk

ARG YQ_VERSION=4.44.3

RUN curl -Lo /tmp/yq \
    "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_${TARGETARCH}" && \
    chmod +x /tmp/yq

RUN curl -Lo /tmp/oc.tar.gz \
    "https://mirror.openshift.com/pub/openshift-v4/${TARGETARCH}/clients/ocp/stable-${OC_VERSION}/openshift-client-linux.tar.gz" && \
    tar -xzf /tmp/oc.tar.gz -C /tmp oc kubectl && \
    chmod +x /tmp/oc /tmp/kubectl

FROM registry.access.redhat.com/ubi9/ubi:latest

RUN dnf -y install \
    jq \
    skopeo \
    git \
    golang \
    make \
    && dnf clean all

COPY --from=builder /tmp/operator-sdk /usr/local/bin/operator-sdk
COPY --from=builder /tmp/oc /usr/local/bin/oc
COPY --from=builder /tmp/kubectl /usr/local/bin/kubectl
COPY --from=builder /tmp/yq /usr/local/bin/yq

RUN go install github.com/onsi/ginkgo/v2/ginkgo@latest && \
    mv "$(go env GOPATH)/bin/ginkgo" /usr/local/bin/ginkgo && \
    go clean -cache -modcache

ENV PATH="/usr/local/bin:${PATH}"
