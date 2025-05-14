# Make file config
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
WHITE  := $(shell tput -Txterm setaf 7)
CYAN   := $(shell tput -Txterm setaf 6)
RESET  := $(shell tput -Txterm sgr0)

## Help:
help: ## Show this help.
	@echo ''
	@echo 'Usage:'
	@echo '  ${YELLOW}make${RESET} ${GREEN}<target>${RESET}'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} { \
		if (/^[a-zA-Z_-]+:.*?##.*$$/) {printf "    ${YELLOW}%-20s${GREEN}%s${RESET}\n", $$1, $$2} \
		else if (/^## .*$$/) {printf "  ${CYAN}%s${RESET}\n", substr($$1,4)} \
		}' $(MAKEFILE_LIST)

# Location to install dependencies to
LOCALBIN ?= $(shell pwd)/bin
$(LOCALBIN):
	mkdir -p $(LOCALBIN)

# Tool Binaries
KUBECTL ?= kubectl
YQ ?= yq
KUSTOMIZE ?= $(LOCALBIN)/kustomize

# Tool Versions
KUSTOMIZE_VERSION ?= v5.3

# Application version
VERSION_NAME := $(shell echo $(VERSION) | sed 's/\./-/g')

.PHONE: update-pipelines
update-pipelines: ## Update pipelines with latest task bundles
	bash scripts/update-task-bundles.sh pipelines/*.yaml

.PHONY: kustomize
kustomize: $(KUSTOMIZE) ## Download kustomize locally if necessary. If wrong version is installed, it will be removed before downloading.
$(KUSTOMIZE): $(LOCALBIN)
	@if test -x $(LOCALBIN)/kustomize && ! $(LOCALBIN)/kustomize version | grep -q $(KUSTOMIZE_VERSION); then \
		echo "$(LOCALBIN)/kustomize version is not expected $(KUSTOMIZE_VERSION). Removing it before installing."; \
		rm -rf $(LOCALBIN)/kustomize; \
	fi
	test -s $(LOCALBIN)/kustomize || GOBIN=$(LOCALBIN) GO111MODULE=on go install sigs.k8s.io/kustomize/kustomize/v5@$(KUSTOMIZE_VERSION)


.PHONY: release-template
release-template: ## Create release template for catalog and operator
	@$(KUSTOMIZE) build operator/setup \
	| $(KUBECTL) apply -f -

#	@$(KUSTOMIZE) build catalog/setup \
#	| $(KUBECTL) apply -f -

.PHONY: release-opeartor
release-operator: check-parameter
release-operator: ## Create new operator release
	@$(KUSTOMIZE) build operator/release \
	| $(YQ) '.metadata.name += "-"+"$(VERSION_NAME)", .spec.template.values[0].value = "$(VERSION)"' \
	| $(KUBECTL) apply -f -

check-parameter:
ifndef VERSION
	$(error VERSION parameter not provided)
endif

.PHONY: release-catalog
release-catalog: check-parameter-catalog
OPENSHIFT_VERSION_NAME := $(shell echo $(OPENSHIFT_VERSION) | sed 's/\./-/g')
release-catalog: ## Create new catalog release
	@$(KUSTOMIZE) build catalog/release \
	| $(YQ) '.metadata.name += "-"+"$(OPENSHIFT_VERSION_NAME)", .spec.template.values[0].value = "$(OPENSHIFT_VERSION)"' \
	| $(KUBECTL) apply -f -

check-parameter-catalog:
ifndef OPENSHIFT_VERSION
	$(error OPENSHIFT_VERSION parameter not provided)
endif

#.PHONY: create-snapshot
#release-catalog: ## Create override snapshot