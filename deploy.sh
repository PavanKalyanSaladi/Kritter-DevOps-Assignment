#!/bin/bash
set -e

echo "🚀 Starting DevOps Infrastructure Deployment"
echo "============================================"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Check prerequisites
echo -e "${BLUE}📋 Checking prerequisites...${NC}"

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}❌ Terraform is not installed${NC}"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI is not installed${NC}"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ AWS credentials not configured${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"

# Initialize Terraform
echo -e "${BLUE}🔧 Initializing Terraform...${NC}"
terraform init

# Format check
echo -e "${BLUE}📝 Checking Terraform formatting...${NC}"
terraform fmt -check=true

# Validate configuration
echo -e "${BLUE}✅ Validating Terraform configuration...${NC}"
terraform validate

# Plan deployment
echo -e "${BLUE}📋 Planning deployment...${NC}"
terraform plan -out=tfplan

# Ask for confirmation
echo -e "${BLUE}❓ Do you want to apply this plan? (yes/no):${NC}"
read -r response

if [[ "$response" != "yes" ]]; then
    echo -e "${RED}❌ Deployment cancelled${NC}"
    rm -f tfplan
    exit 0
fi

# Apply configuration
echo -e "${BLUE}🚀 Applying Terraform configuration...${NC}"
terraform apply tfplan

# Clean up plan file
rm -f tfplan

echo -e "${GREEN}✅ Deployment completed successfully!${NC}"
echo
echo -e "${BLUE}📊 Infrastructure Outputs:${NC}"
terraform output

echo
echo -e "${GREEN}🎉 Your DevOps infrastructure is ready!${NC}"
echo
echo "Next steps:"
echo "1. Run './demo-test.sh' to test your infrastructure"
echo "2. Check the ALB endpoint: http://$(terraform output -raw alb_dns_name)"
echo "3. Test the upload API: $(terraform output -raw api_gateway_url)/demo/upload"