# Terraform DAG Orchestration Makefile
# Provides dependency-aware execution order

# Configuration
ENVIRONMENT ?= dev
REGION ?= us-east-1
AUTO_APPROVE ?= false

# Terraform command settings
TF_VARS := -var="environment=$(ENVIRONMENT)" -var="region=$(REGION)"
TF_AUTO := $(if $(filter true,$(AUTO_APPROVE)),-auto-approve,)

# Helper function to execute terraform in a directory
define terraform_exec
	@echo "🚀 Executing $(1) in $(2)"
	@cd $(2) && \
	terraform init && \
	if [ -f "environments/$(ENVIRONMENT).tfvars" ]; then \
		terraform $(1) $(TF_AUTO) $(TF_VARS) -var-file="environments/$(ENVIRONMENT).tfvars"; \
	elif [ -f "settings.auto.tfvars" ]; then \
		terraform $(1) $(TF_AUTO) $(TF_VARS) -var-file="settings.auto.tfvars"; \
	else \
		terraform $(1) $(TF_AUTO) $(TF_VARS); \
	fi
	@echo "✅ Completed $(1) in $(2)"
endef

# Layer definitions with dependencies
.PHONY: governance-providers governance-iam governance-org
.PHONY: core-networking core-security core-routing
.PHONY: services-databases services-caching services-messaging
.PHONY: apps-1 apps-2

# Governance Layer (Level 0)
governance-providers:
	$(call terraform_exec,apply,00-governance/providers)

governance-iam: governance-providers
	$(call terraform_exec,apply,00-governance/iam)

governance-org: governance-providers
	$(call terraform_exec,apply,00-governance/organization)

# Core Layer (Level 1)
core-networking: governance-iam governance-org
	$(call terraform_exec,apply,01-core/01-networking)

core-security: core-networking
	$(call terraform_exec,apply,01-core/02-security)

core-routing: core-networking
	$(call terraform_exec,apply,01-core/03-routing)

# Services Layer (Level 2)
services-databases: core-security core-routing
	$(call terraform_exec,apply,02-services/01-databases)

services-caching: core-security core-routing
	$(call terraform_exec,apply,02-services/02-caching)

services-messaging: core-security core-routing
	$(call terraform_exec,apply,02-services/03-messaging)

# Applications Layer (Level 3)
apps-1: services-databases services-caching
	$(call terraform_exec,apply,03-applications/app-1)

apps-2: services-databases services-messaging
	$(call terraform_exec,apply,03-applications/app-2)

# Aggregate targets
.PHONY: governance core services applications all

governance: governance-providers governance-iam governance-org
core: governance core-networking core-security core-routing
services: core services-databases services-caching services-messaging
applications: services apps-1 apps-2
all: applications

# Plan targets
.PHONY: plan-all plan-governance plan-core plan-services plan-applications

plan-governance:
	$(call terraform_exec,plan,00-governance/providers)
	$(call terraform_exec,plan,00-governance/iam)
	$(call terraform_exec,plan,00-governance/organization)

plan-core: plan-governance
	$(call terraform_exec,plan,01-core/01-networking)
	$(call terraform_exec,plan,01-core/02-security)
	$(call terraform_exec,plan,01-core/03-routing)

plan-services: plan-core
	$(call terraform_exec,plan,02-services/01-databases)
	$(call terraform_exec,plan,02-services/02-caching)
	$(call terraform_exec,plan,02-services/03-messaging)

plan-applications: plan-services
	$(call terraform_exec,plan,03-applications/app-1)
	$(call terraform_exec,plan,03-applications/app-2)

plan-all: plan-applications

# Destroy targets (reverse order)
.PHONY: destroy-all destroy-applications destroy-services destroy-core destroy-governance

destroy-applications:
	$(call terraform_exec,destroy,03-applications/app-2)
	$(call terraform_exec,destroy,03-applications/app-1)

destroy-services: destroy-applications
	$(call terraform_exec,destroy,02-services/03-messaging)
	$(call terraform_exec,destroy,02-services/02-caching)
	$(call terraform_exec,destroy,02-services/01-databases)

destroy-core: destroy-services
	$(call terraform_exec,destroy,01-core/03-routing)
	$(call terraform_exec,destroy,01-core/02-security)
	$(call terraform_exec,destroy,01-core/01-networking)

destroy-governance: destroy-core
	$(call terraform_exec,destroy,00-governance/organization)
	$(call terraform_exec,destroy,00-governance/iam)
	$(call terraform_exec,destroy,00-governance/providers)

destroy-all: destroy-governance

# Parallel execution targets (using make -j)
.PHONY: parallel-governance parallel-core-independent parallel-services parallel-apps

parallel-governance: governance-providers
	$(MAKE) -j2 governance-iam governance-org

parallel-core-independent: core-networking
	$(MAKE) -j2 core-security core-routing

parallel-services: core-security core-routing
	$(MAKE) -j3 services-databases services-caching services-messaging

parallel-apps: services-databases services-caching services-messaging
	$(MAKE) -j2 apps-1 apps-2

# Multi-environment targets
.PHONY: deploy-all-environments plan-all-environments destroy-all-environments validate-environments

deploy-all-environments:
	@echo "🚀 Deploying all environments (dev, stg, prd)"
	./tools/deploy-all-environments.sh apply $(REGION)

deploy-all-environments-parallel:
	@echo "🚀 Deploying all environments in parallel"
	PARALLEL_ENVIRONMENTS=true ./tools/deploy-all-environments.sh apply $(REGION)

plan-all-environments:
	@echo "📋 Planning all environments"
	./tools/deploy-all-environments.sh plan-all $(REGION)

destroy-all-environments:
	@echo "💥 Destroying all environments (sequential for safety)"
	./tools/deploy-all-environments.sh destroy $(REGION)

validate-environments:
	@echo "🔍 Validating all environments"
	./tools/deploy-all-environments.sh validate

# Multi-environment with auto-approve
deploy-all-auto:
	@echo "🚀 Auto-deploying all environments"
	AUTO_APPROVE=true ./tools/deploy-all-environments.sh apply $(REGION)

deploy-all-auto-parallel:
	@echo "🚀 Auto-deploying all environments in parallel"
	AUTO_APPROVE=true PARALLEL_ENVIRONMENTS=true ./tools/deploy-all-environments.sh apply $(REGION)

# Help target
help:
	@echo "Terraform DAG Orchestration"
	@echo ""
	@echo "Single Environment Usage:"
	@echo "  make all ENVIRONMENT=dev REGION=us-east-1"
	@echo "  make governance ENVIRONMENT=stg"
	@echo "  make plan-all ENVIRONMENT=prd"
	@echo "  make destroy-all ENVIRONMENT=dev AUTO_APPROVE=true"
	@echo ""
	@echo "Multi-Environment Usage:"
	@echo "  make deploy-all-environments REGION=us-east-1"
	@echo "  make deploy-all-environments-parallel REGION=us-east-1"
	@echo "  make deploy-all-auto REGION=us-east-1"
	@echo "  make plan-all-environments REGION=us-east-1"
	@echo "  make validate-environments"
	@echo ""
	@echo "Single Environment Targets:"
	@echo "  all                 - Deploy all layers in order"
	@echo "  governance          - Deploy governance layer"
	@echo "  core               - Deploy core layer"
	@echo "  services           - Deploy services layer"
	@echo "  applications       - Deploy applications layer"
	@echo "  plan-all           - Plan all layers"
	@echo "  destroy-all        - Destroy all layers (reverse order)"
	@echo ""
	@echo "Multi-Environment Targets:"
	@echo "  deploy-all-environments        - Deploy all environments sequentially"
	@echo "  deploy-all-environments-parallel - Deploy all environments in parallel"
	@echo "  deploy-all-auto               - Deploy all environments with auto-approve"
	@echo "  deploy-all-auto-parallel      - Deploy all environments parallel + auto-approve"
	@echo "  plan-all-environments         - Plan all environments"
	@echo "  destroy-all-environments      - Destroy all environments"
	@echo "  validate-environments         - Validate environment structure"
	@echo ""
	@echo "Parallel targets:"
	@echo "  parallel-governance - Run governance components in parallel"
	@echo "  parallel-services   - Run services in parallel"
	@echo ""
	@echo "Variables:"
	@echo "  ENVIRONMENT        - Target environment (dev, stg, prd)"
	@echo "  REGION            - AWS region"
	@echo "  AUTO_APPROVE      - Skip confirmations (true/false)"