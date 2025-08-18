#!/bin/bash

# Terraform DAG Execution Orchestrator
# Executes Terraform layers in dependency order

set -euo pipefail

# Configuration
ENVIRONMENT=${1:-dev}
REGION=${2:-us-east-1}
ACTION=${3:-apply}
AUTO_APPROVE=${AUTO_APPROVE:-false}

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Execution order definition (DAG layers)
EXECUTION_ORDER=(
    "00-governance/providers"
    "00-governance/iam"
    "00-governance/organization"
    "01-core/01-networking"
    "01-core/02-security"
    "01-core/03-routing"
    "02-services/01-databases"
    "02-services/02-caching"
    "02-services/03-messaging"
    "02-services/04-ci-cd"
    "03-applications/app-1"
    "03-applications/app-2"
)

# Parallel execution groups (layers that can run simultaneously)
PARALLEL_GROUPS=(
    "00-governance/providers"
    "00-governance/iam,00-governance/organization"  # These can run in parallel after providers
    "01-core/01-networking"
    "01-core/02-security,01-core/03-routing"        # These can run in parallel after networking
    "02-services/01-databases,02-services/02-caching,02-services/03-messaging,02-services/04-ci-cd"
    "03-applications/app-1,03-applications/app-2"
)

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if directory exists and has Terraform files
check_layer_exists() {
    local layer_path=$1
    if [[ ! -d "$layer_path" ]]; then
        log_warning "Layer directory does not exist: $layer_path"
        return 1
    fi
    
    if [[ ! -f "$layer_path/main.tf" && ! -f "$layer_path/versions.tf" ]]; then
        log_warning "No Terraform files found in: $layer_path"
        return 1
    fi
    
    return 0
}

# Execute Terraform command in a specific layer
execute_terraform() {
    local layer_path=$1
    local tfvars_file="$layer_path/environments/${ENVIRONMENT}.tfvars"
    local legacy_tfvars_file="$layer_path/settings.auto.tfvars"
    
    log_info "Executing Terraform $ACTION in: $layer_path"
    
    cd "$layer_path"
    
    # Initialize if needed
    if [[ ! -d ".terraform" ]]; then
        log_info "Initializing Terraform..."
        terraform init
    fi
    
    # Determine tfvars file to use
    local tfvars_args=""
    if [[ -f "$tfvars_file" ]]; then
        tfvars_args="-var-file=environments/${ENVIRONMENT}.tfvars"
    elif [[ -f "$legacy_tfvars_file" ]]; then
        tfvars_args="-var-file=settings.auto.tfvars"
    fi
    
    # Set common variables
    terraform_vars=(
        "-var=environment=$ENVIRONMENT"
        "-var=region=$REGION"
    )
    
    case $ACTION in
        plan)
            terraform plan $tfvars_args "${terraform_vars[@]}"
            ;;
        apply)
            if [[ "$AUTO_APPROVE" == "true" ]]; then
                terraform apply -auto-approve $tfvars_args "${terraform_vars[@]}"
            else
                terraform apply $tfvars_args "${terraform_vars[@]}"
            fi
            ;;
        destroy)
            if [[ "$AUTO_APPROVE" == "true" ]]; then
                terraform destroy -auto-approve $tfvars_args "${terraform_vars[@]}"
            else
                terraform destroy $tfvars_args "${terraform_vars[@]}"
            fi
            ;;
        *)
            log_error "Unknown action: $ACTION"
            exit 1
            ;;
    esac
    
    cd - > /dev/null
}

# Execute layers in parallel within a group
execute_parallel_group() {
    local group=$1
    local pids=()
    
    IFS=',' read -ra LAYERS <<< "$group"
    
    for layer in "${LAYERS[@]}"; do
        if check_layer_exists "$layer"; then
            log_info "Starting parallel execution: $layer"
            (
                execute_terraform "$layer"
                log_success "Completed: $layer"
            ) &
            pids+=($!)
        fi
    done
    
    # Wait for all parallel executions to complete
    for pid in "${pids[@]}"; do
        if wait $pid; then
            log_success "Parallel execution completed successfully"
        else
            log_error "Parallel execution failed with PID: $pid"
            return 1
        fi
    done
}

# Sequential execution (fallback)
execute_sequential() {
    for layer in "${EXECUTION_ORDER[@]}"; do
        if check_layer_exists "$layer"; then
            execute_terraform "$layer"
            log_success "Completed layer: $layer"
        else
            log_warning "Skipping non-existent layer: $layer"
        fi
    done
}

# Parallel execution with dependency groups
execute_parallel() {
    for group in "${PARALLEL_GROUPS[@]}"; do
        log_info "Executing parallel group: $group"
        execute_parallel_group "$group"
        log_success "Completed parallel group: $group"
    done
}

# Validation function
validate_dependencies() {
    log_info "Validating layer dependencies..."
    
    # Check that required remote state files exist
    for layer in "${EXECUTION_ORDER[@]}"; do
        if check_layer_exists "$layer"; then
            # Check for data sources that reference other layers
            if grep -q "terraform_remote_state" "$layer"/*.tf 2>/dev/null; then
                log_info "Layer $layer has remote state dependencies"
                # Additional validation logic can be added here
            fi
        fi
    done
}

# Rollback function
rollback_layer() {
    local layer=$1
    log_warning "Rolling back layer: $layer"
    cd "$layer"
    terraform destroy -auto-approve -var-file="environments/${ENVIRONMENT}.tfvars" || true
    cd - > /dev/null
}

# Main execution function
main() {
    log_info "Starting Terraform DAG execution"
    log_info "Environment: $ENVIRONMENT"
    log_info "Region: $REGION"
    log_info "Action: $ACTION"
    
    # Validate dependencies
    validate_dependencies
    
    # Choose execution strategy
    if [[ "${PARALLEL:-false}" == "true" ]]; then
        log_info "Using parallel execution strategy"
        execute_parallel
    else
        log_info "Using sequential execution strategy"
        execute_sequential
    fi
    
    log_success "All layers completed successfully!"
}

# Help function
show_help() {
    cat << EOF
Terraform DAG Execution Orchestrator

Usage: $0 [ENVIRONMENT] [REGION] [ACTION]

Arguments:
    ENVIRONMENT    Target environment (dev, stg, prd) [default: dev]
    REGION         AWS region [default: us-east-1]
    ACTION         Terraform action (plan, apply, destroy) [default: apply]

Environment Variables:
    AUTO_APPROVE   Skip confirmation prompts (true/false) [default: false]
    PARALLEL       Use parallel execution strategy (true/false) [default: false]

Examples:
    $0 dev us-east-1 plan
    AUTO_APPROVE=true $0 dev us-east-1 apply
    PARALLEL=true $0 stg us-west-2 apply

EOF
}

# Handle command line arguments
if [[ $# -gt 0 && ($1 == "-h" || $1 == "--help") ]]; then
    show_help
    exit 0
fi

# Execute main function
main