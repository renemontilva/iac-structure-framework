#!/bin/bash

# Multi-Environment Terraform Deployment Script
# Executes terraform apply across all environments in dependency order

set -euo pipefail

# Configuration
ACTION=${1:-apply}
REGION=${2:-us-east-1}
AUTO_APPROVE=${AUTO_APPROVE:-false}
PARALLEL_ENVIRONMENTS=${PARALLEL_ENVIRONMENTS:-false}

# Available environments
ENVIRONMENTS=("dev" "stg" "prd")

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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

log_env() {
    echo -e "${CYAN}[ENV: $1]${NC} $2"
}

# Function to execute terraform for a specific environment
execute_environment() {
    local environment=$1
    local log_prefix="[ENV: $environment]"
    
    log_env "$environment" "Starting deployment for environment: $environment"
    
    # Use the existing deploy-ordered.sh script for each environment
    if [[ "$AUTO_APPROVE" == "true" ]]; then
        AUTO_APPROVE=true ./tools/deploy-ordered.sh "$environment" "$REGION" "$ACTION"
    else
        ./tools/deploy-ordered.sh "$environment" "$REGION" "$ACTION"
    fi
    
    if [[ $? -eq 0 ]]; then
        log_env "$environment" "✅ Successfully completed deployment for environment: $environment"
        return 0
    else
        log_env "$environment" "❌ Failed deployment for environment: $environment"
        return 1
    fi
}

# Function to execute environments in parallel
execute_parallel() {
    local pids=()
    local failed_envs=()
    
    log_info "🚀 Starting parallel deployment across all environments"
    
    # Start all environments in parallel
    for env in "${ENVIRONMENTS[@]}"; do
        log_env "$env" "Starting parallel deployment..."
        (
            execute_environment "$env" 2>&1 | sed "s/^/[$env] /"
        ) &
        pids+=($!)
    done
    
    # Wait for all environments to complete
    local i=0
    for pid in "${pids[@]}"; do
        local env="${ENVIRONMENTS[$i]}"
        if wait $pid; then
            log_env "$env" "✅ Parallel deployment completed successfully"
        else
            log_env "$env" "❌ Parallel deployment failed"
            failed_envs+=("$env")
        fi
        ((i++))
    done
    
    # Report results
    if [[ ${#failed_envs[@]} -eq 0 ]]; then
        log_success "🎉 All environments deployed successfully!"
        return 0
    else
        log_error "❌ Failed environments: ${failed_envs[*]}"
        return 1
    fi
}

# Function to execute environments sequentially
execute_sequential() {
    local failed_envs=()
    
    log_info "🚀 Starting sequential deployment across all environments"
    
    for env in "${ENVIRONMENTS[@]}"; do
        log_info "📋 Processing environment: $env"
        
        if execute_environment "$env"; then
            log_success "✅ Environment $env completed successfully"
        else
            log_error "❌ Environment $env failed"
            failed_envs+=("$env")
            
            # Ask user if they want to continue with remaining environments
            if [[ "$AUTO_APPROVE" != "true" ]]; then
                read -p "Continue with remaining environments? (y/N): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    log_warning "Stopping deployment at user request"
                    break
                fi
            else
                log_warning "Auto-approve enabled, continuing with remaining environments"
            fi
        fi
    done
    
    # Report results
    if [[ ${#failed_envs[@]} -eq 0 ]]; then
        log_success "🎉 All environments deployed successfully!"
        return 0
    else
        log_error "❌ Failed environments: ${failed_envs[*]}"
        return 1
    fi
}

# Function to show deployment plan for all environments
show_plan_all() {
    log_info "📋 Showing deployment plan for all environments"
    
    for env in "${ENVIRONMENTS[@]}"; do
        log_env "$env" "Planning deployment for environment: $env"
        echo "----------------------------------------"
        ./tools/deploy-ordered.sh "$env" "$REGION" "plan"
        echo "----------------------------------------"
    done
}

# Function to validate environments
validate_environments() {
    log_info "🔍 Validating environments and dependencies"
    
    local validation_failed=false
    
    for env in "${ENVIRONMENTS[@]}"; do
        # Check if environment-specific directories exist
        local env_dirs=(
            "core/networking/${env}_${REGION}"
            "core/security/${env}_${REGION}"
            "core/routing/${env}_${REGION}"
        )
        
        for dir in "${env_dirs[@]}"; do
            if [[ ! -d "$dir" ]]; then
                log_warning "Environment directory missing: $dir"
                validation_failed=true
            fi
        done
    done
    
    if [[ "$validation_failed" == "true" ]]; then
        log_error "Validation failed. Please check missing directories."
        return 1
    fi
    
    log_success "✅ All environments validated successfully"
    return 0
}

# Function to show help
show_help() {
    cat << EOF
Multi-Environment Terraform Deployment Script

Usage: $0 [ACTION] [REGION]

Arguments:
    ACTION         Terraform action (plan, apply, destroy) [default: apply]
    REGION         AWS region [default: us-east-1]

Environment Variables:
    AUTO_APPROVE           Skip confirmation prompts (true/false) [default: false]
    PARALLEL_ENVIRONMENTS  Deploy environments in parallel (true/false) [default: false]

Examples:
    # Deploy all environments sequentially
    $0 apply us-east-1

    # Deploy all environments in parallel with auto-approve
    AUTO_APPROVE=true PARALLEL_ENVIRONMENTS=true $0 apply us-east-1

    # Plan all environments
    $0 plan us-east-1

    # Destroy all environments (sequential for safety)
    AUTO_APPROVE=true $0 destroy us-east-1

Special Commands:
    $0 plan-all    - Show plan for all environments
    $0 validate    - Validate environment structure

Environments processed: ${ENVIRONMENTS[*]}

EOF
}

# Main execution function
main() {
    # Handle special commands
    case "${ACTION:-}" in
        "plan-all")
            show_plan_all
            exit 0
            ;;
        "validate")
            validate_environments
            exit $?
            ;;
        "-h"|"--help"|"help")
            show_help
            exit 0
            ;;
    esac
    
    log_info "🚀 Multi-Environment Terraform Deployment"
    log_info "Action: $ACTION"
    log_info "Region: $REGION"
    log_info "Environments: ${ENVIRONMENTS[*]}"
    log_info "Auto-approve: $AUTO_APPROVE"
    log_info "Parallel execution: $PARALLEL_ENVIRONMENTS"
    
    # Validate environments first
    if ! validate_environments; then
        exit 1
    fi
    
    # Confirm execution unless auto-approve is enabled
    if [[ "$AUTO_APPROVE" != "true" && "$ACTION" != "plan" ]]; then
        echo
        log_warning "This will execute '$ACTION' on ALL environments: ${ENVIRONMENTS[*]}"
        read -p "Are you sure you want to continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Deployment cancelled by user"
            exit 0
        fi
    fi
    
    # Execute based on parallel flag
    if [[ "$PARALLEL_ENVIRONMENTS" == "true" && "$ACTION" != "destroy" ]]; then
        execute_parallel
    else
        if [[ "$ACTION" == "destroy" ]]; then
            log_warning "Destroy operations are always executed sequentially for safety"
        fi
        execute_sequential
    fi
    
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "🎉 Multi-environment deployment completed successfully!"
    else
        log_error "❌ Multi-environment deployment completed with errors"
    fi
    
    exit $exit_code
}

# Handle command line arguments
if [[ $# -gt 0 && ($1 == "-h" || $1 == "--help" || $1 == "help") ]]; then
    show_help
    exit 0
fi

# Execute main function
main