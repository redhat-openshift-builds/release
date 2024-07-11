## Location to install dependencies to
LOCALBIN ?= $(shell pwd)/bin
$(LOCALBIN):
	mkdir -p $(LOCALBIN)

## Tool Binaries
KUBECTL ?= kubectl
YQ ?= yq
KUSTOMIZE ?= $(LOCALBIN)/kustomize

## Tool Versions
KUSTOMIZE_VERSION ?= v5.3

.PHONY: kustomize
kustomize: $(KUSTOMIZE) ## Download kustomize locally if necessary. If wrong version is installed, it will be removed before downloading.
$(KUSTOMIZE): $(LOCALBIN)
	@if test -x $(LOCALBIN)/kustomize && ! $(LOCALBIN)/kustomize version | grep -q $(KUSTOMIZE_VERSION); then \
		echo "$(LOCALBIN)/kustomize version is not expected $(KUSTOMIZE_VERSION). Removing it before installing."; \
		rm -rf $(LOCALBIN)/kustomize; \
	fi
	test -s $(LOCALBIN)/kustomize || GOBIN=$(LOCALBIN) GO111MODULE=on go install sigs.k8s.io/kustomize/kustomize/v5@$(KUSTOMIZE_VERSION)


.PHONY: setup
setup: ## Create new release setup
	@$(KUSTOMIZE) build manifests/konflux/setup \
	| $(KUBECTL) apply -f -

.PHONY: release
release: check-env
OPENSHIFT_BUILD_VERSION_NAME := $(shell echo $(OPENSHIFT_BUILD_VERSION) | sed 's/\./-/g')
release: ## Create new release
	@$(KUSTOMIZE) build manifests/konflux/release \
	| $(YQ) '.metadata.name += "-"+"$(OPENSHIFT_BUILD_VERSION_NAME)", .spec.template.values[0].value = "$(OPENSHIFT_BUILD_VERSION)"' \
	| $(KUBECTL) apply -f -

check-env:
ifndef OPENSHIFT_BUILD_VERSION
	$(error OPENSHIFT_BUILD_VERSION environment variable is not set)
endif