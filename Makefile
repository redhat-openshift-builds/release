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


.PHONY: operator-setup
operator-setup: ## Create new release setup
	@$(KUSTOMIZE) build konflux/operator/setup \
	| $(KUBECTL) apply -f -

.PHONY: operator-release
operator-release: operator-check-env
OPENSHIFT_BUILDS_VERSION_NAME := $(shell echo $(OPENSHIFT_BUILDS_VERSION) | sed 's/\./-/g')
operator-release: ## Create new release
	@$(KUSTOMIZE) build konflux/operator/release \
	| $(YQ) '.metadata.name += "-"+"$(OPENSHIFT_BUILDS_VERSION_NAME)", .spec.template.values[0].value = "$(OPENSHIFT_BUILDS_VERSION)"' \
	| $(KUBECTL) apply -f -

operator-check-env:
ifndef OPENSHIFT_BUILDS_VERSION
	$(error OPENSHIFT_BUILDS_VERSION environment variable is not set)
endif


.PHONY: catalog-setup
catalog-setup: ## Create new release setup
	@$(KUSTOMIZE) build konflux/catalog/setup \
	| $(KUBECTL) apply -f -

.PHONY: catalog-release
catalog-release: catalog-check-env
OPENSHIFT_VERSION_NAME := $(shell echo $(OPENSHIFT_VERSION) | sed 's/\./-/g')
catalog-release: ## Create new release
	@$(KUSTOMIZE) build konflux/catalog/release \
	| $(YQ) '.metadata.name += "-"+"$(OPENSHIFT_VERSION_NAME)", .spec.template.values[0].value = "$(OPENSHIFT_VERSION)"' \
	| $(KUBECTL) apply -f -

catalog-check-env:
ifndef OPENSHIFT_VERSION
	$(error OPENSHIFT_VERSION environment variable is not set)
endif