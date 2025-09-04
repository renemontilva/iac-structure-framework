#!/bin/bash

# Quick Multi-Environment Deployment Script
# Simple wrapper for common deployment scenarios

set -euo pipefail

# Default configuration
REGION=${REGION:-us-east-1}
ACTION=${1:-apply}

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🚀 Quick Multi-Environment Terraform Deployment${NC}"
echo -e "${BLUE}================================================${NC}"

case "$ACTION" in
    "apply")
        echo -e "${GREEN}Deploying all environments (dev -> stg -> prd)${NC}"
        ./tools/deploy-all-environments.sh apply "$REGION"
        ;;
    "apply-parallel")
        echo -e "${GREEN}Deploying all environments in parallel${NC}"
        PARALLEL_ENVIRONMENTS=true ./tools/deploy-all-environments.sh apply "$REGION"
        ;;
    "apply-auto")
        echo -e "${GREEN}Auto-deploying all environments${NC}"
        AUTO_APPROVE=true ./tools/deploy-all-environments.sh apply "$REGION"
        ;;
    "apply-auto-parallel")
        echo -e "${GREEN}Auto-deploying all environments in parallel${NC}"
        AUTO_APPROVE=true PARALLEL_ENVIRONMENTS=true ./tools/deploy-all-environments.sh apply "$REGION"
        ;;
    "plan")
        echo -e "${YELLOW}Planning all environments${NC}"
        ./tools/deploy-all-environments.sh plan-all "$REGION"
        ;;
    "validate")
        echo -e "${BLUE}Validating all environments${NC}"
        ./tools/deploy-all-environments.sh validate
        ;;
    "destroy")
        echo -e "${YELLOW}Destroying all environments${NC}"
        ./tools/deploy-all-environments.sh destroy "$REGION"
        ;;
    "destroy-auto")
        echo -e "${YELLOW}Auto-destroying all environments${NC}"
        AUTO_APPROVE=true ./tools/deploy-all-environments.sh destroy "$REGION"
        ;;
    *)
        echo "Usage: $0 [apply|apply-parallel|apply-auto|apply-auto-parallel|plan|validate|destroy|destroy-auto]"
        echo ""
        echo "Examples:"
        echo "  $0 apply                    # Deploy all environments sequentially"
        echo "  $0 apply-parallel          # Deploy all environments in parallel"
        echo "  $0 apply-auto              # Deploy with auto-approve"
        echo "  $0 apply-auto-parallel     # Deploy parallel with auto-approve"
        echo "  $0 plan                    # Plan all environments"
        echo "  $0 validate                # Validate environment structure"
        echo ""
        echo "Environment Variables:"
        echo "  REGION=us-west-2 $0 apply  # Use different region"
        exit 1
        ;;
esac