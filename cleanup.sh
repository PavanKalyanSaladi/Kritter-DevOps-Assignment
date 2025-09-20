#!/bin/bash
set -e

echo "🧹 DevOps Infrastructure Cleanup"
echo "================================"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}⚠️ This will destroy ALL infrastructure created by this project!${NC}"
echo -e "${YELLOW}⚠️ This action cannot be undone!${NC}"
echo
echo -e "${BLUE}❓ Are you sure you want to destroy the infrastructure? (type 'destroy' to confirm):${NC}"
read -r response

if [[ "$response" != "destroy" ]]; then
    echo -e "${GREEN}✅ Cleanup cancelled${NC}"
    exit 0
fi

# Get S3 bucket name before destroying
BUCKET_NAME=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")

if [[ -n "$BUCKET_NAME" ]]; then
    echo -e "${BLUE}🗑️ Emptying S3 bucket: $BUCKET_NAME${NC}"
    aws s3 rm "s3://$BUCKET_NAME" --recursive 2>/dev/null || true
fi

# Destroy infrastructure
echo -e "${BLUE}💥 Destroying Terraform infrastructure...${NC}"
terraform destroy -auto-approve

echo -e "${GREEN}✅ Infrastructure destroyed successfully!${NC}"

# Optional: Clean up Terraform files
echo -e "${BLUE}❓ Do you want to clean up Terraform state files? (yes/no):${NC}"
read -r cleanup_response

if [[ "$cleanup_response" == "yes" ]]; then
    echo -e "${BLUE}🧹 Cleaning up Terraform files...${NC}"
    rm -rf .terraform/
    rm -f .terraform.lock.hcl
    rm -f terraform.tfstate*
    rm -f tfplan
    echo -e "${GREEN}✅ Terraform files cleaned up${NC}"
fi

echo -e "${GREEN}🎉 Cleanup completed!${NC}"