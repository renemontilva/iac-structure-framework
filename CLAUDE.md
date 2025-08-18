# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Terraform Infrastructure as Code (IaC) framework implementing a layered architecture pattern for cloud infrastructure management. The framework promotes security, maintainability, and scalability through clear separation of concerns across four distinct layers.

## Architecture

### Layer Structure
The framework implements a layered design with two functional categories:

**Implementation Layers:**
1. **Governance Layer** (`governance/`) - Root-level IAM, policies, and cross-account access controls
2. **Core Layer** (`core/`) - Foundational infrastructure (networking, security, routing)
3. **Service Layer** (`services/`) - Reusable services (databases, caching, messaging, CI/CD, ML/AI)
4. **Application Layer** (`applications/`) - Application-specific infrastructure

**Integration Layers:**
- **Core Module** (`modules/core-module/`) - Provides data sources for core layer resources
- **Service Module** (`modules/service-module/`) - Provides data sources for service layer resources

### Environment Structure
Each implementation layer follows environment-specific directory patterns:
- `{layer}/{component}/{env}_{region}/` (e.g., `core/networking/dev_us-east-1/`)
- Supported environments: `dev`, `stg`, `prd`
- Default region: `us-east-1`

## Development Commands

### Task Runner
Uses Taskfile for common operations:
```bash
# Start LocalStack for local development
task up

# Stop LocalStack
task down

# Run core layer tasks (depends on LocalStack)
task core
```

### Docker Development Environment
```bash
# Start LocalStack (AWS local development)
docker-compose up -d

# Stop environment
docker-compose down
```

### Terraform Operations
Standard Terraform commands apply within each layer directory:
```bash
# Navigate to specific layer/environment
cd core/networking/dev_us-east-1/

# Standard Terraform workflow
terraform init
terraform plan
terraform apply
terraform destroy
```

### Testing
Terraform native testing with `.tftest.hcl` files:
```bash
# Run tests from layer directory
terraform test

# Example test locations:
# core/networking/dev_us-east-1/tests/networking.tftest.hcl
# core/routing/dev_us-east-1/tests/routing.tftest.hcl
```

## File Structure Patterns

### Standard Layer Directory Structure
```
{layer}/{component}/{env}_{region}/
├── main.tf                 # Main resource definitions
├── providers.tf            # Provider configurations
├── variables.tf            # Input variables
├── versions.tf             # Terraform and provider version constraints
├── settings.auto.tfvars    # Environment-specific variable values
└── tests/
    └── {component}.tftest.hcl
```

### Module Structure
```
modules/{module-name}/
├── README.md
└── modules/
    ├── networking/
    │   ├── data.tf         # Data sources for integration
    │   ├── outputs.tf      # Module outputs
    │   ├── variables.tf    # Module variables
    │   └── versions.tf     # Version constraints
    └── {other-components}/
```

## Key Conventions

### Terraform Standards
- Terraform version: `>= 1.0`
- AWS provider version: `>= 5.0`
- Use terraform-aws-modules where appropriate (e.g., VPC module v5.8.1)

### Naming Conventions
- Environment tags: `dev`, `stg`, `prd`
- Resource naming: `{purpose}-{component}` (e.g., `main-vpc`)
- Directory naming: `{env}_{region}` (e.g., `dev_us-east-1`)

### Variable Patterns
- Use object variables for related configurations (see `network` object in settings.auto.tfvars)
- Environment-specific values in `settings.auto.tfvars`
- Common patterns: region, network configuration, enable flags

### Testing Approach
- Use Terraform native testing framework
- Test files named `{component}.tftest.hcl`
- Mock providers for unit testing
- Assertion-based validation of resource properties

## Integration Layers Usage

The core-module and service-module provide data sources to access resources created in lower layers:
- Use data sources to reference VPCs, subnets, security groups from core layer
- Filter by tags to identify specific resources
- Example: `data.aws_vpc.main` filtered by `tag:Name = "main-vpc"`

## LocalStack Development

The project includes LocalStack for local AWS service emulation:
- Accessible at `127.0.0.1:4566`
- Volume mounted at `./volume` for persistence
- Use for development and testing without AWS costs