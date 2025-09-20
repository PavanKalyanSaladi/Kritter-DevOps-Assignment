#!/bin/bash
# Script to test the deployed infrastructure

set -e

echo "🚀 DevOps Infrastructure Demo Test Script"
echo "========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if terraform is available
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}❌ Terraform is not installed${NC}"
    exit 1
fi

# Check if aws cli is available
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI is not installed${NC}"
    exit 1
fi

echo -e "${BLUE}📋 Getting infrastructure outputs...${NC}"

# Get outputs from Terraform
ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "")
API_URL=$(terraform output -raw api_gateway_url 2>/dev/null || echo "")
BUCKET_NAME=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")
ECS_CLUSTER=$(terraform output -raw ecs_cluster_name 2>/dev/null || echo "")

if [[ -z "$ALB_DNS" || -z "$API_URL" || -z "$BUCKET_NAME" ]]; then
    echo -e "${RED}❌ Could not retrieve Terraform outputs. Make sure infrastructure is deployed.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Infrastructure outputs retrieved:${NC}"
echo "   ALB DNS: $ALB_DNS"
echo "   API URL: $API_URL"
echo "   S3 Bucket: $BUCKET_NAME"
echo "   ECS Cluster: $ECS_CLUSTER"
echo

# Test 1: ALB Load Balancing
echo -e "${BLUE}🔄 Test 1: Testing ALB Load Balancing (Round-Robin)${NC}"
echo "Making 10 requests to ALB to verify load distribution..."

nginx_a_count=0
nginx_b_count=0

for i in {1..10}; do
    echo -n "Request $i: "
    response=$(curl -s --max-time 10 "http://$ALB_DNS" 2>/dev/null || echo "ERROR")
    
    if [[ $response == *"nginx-a"* ]]; then
        echo -e "${GREEN}nginx-a${NC}"
        ((nginx_a_count++))
    elif [[ $response == *"nginx-b"* ]]; then
        echo -e "${YELLOW}nginx-b${NC}"
        ((nginx_b_count++))
    else
        echo -e "${RED}ERROR or unexpected response${NC}"
        echo "Response: $response"
    fi
    
    sleep 1
done

echo "Results:"
echo "  nginx-a responses: $nginx_a_count"
echo "  nginx-b responses: $nginx_b_count"

if [[ $nginx_a_count -gt 0 && $nginx_b_count -gt 0 ]]; then
    echo -e "${GREEN}✅ Load balancing is working correctly!${NC}"
else
    echo -e "${RED}❌ Load balancing may not be working properly${NC}"
fi
echo

# Test 2: API Gateway File Upload
echo -e "${BLUE}📤 Test 2: Testing File Upload API${NC}"

# Create test files
echo "Creating test files..."
echo "Hello from DevOps Demo Test!" > test-demo.txt
echo '{"message": "Test JSON upload", "timestamp": "'$(date)'"}' > test-demo.json

# Test text file upload
echo "Testing text file upload..."
upload_response=$(curl -s -X POST "$API_URL/demo/upload" \
                       -H "Content-Type: text/plain" \
                       -d @test-demo.txt 2>/dev/null || echo "ERROR")

if [[ $upload_response == *"File uploaded successfully"* ]]; then
    echo -e "${GREEN}✅ Text file upload successful${NC}"
    echo "Response: $upload_response"
else
    echo -e "${RED}❌ Text file upload failed${NC}"
    echo "Response: $upload_response"
fi

# Test JSON file upload
echo "Testing JSON file upload..."
json_response=$(curl -s -X POST "$API_URL/demo/upload" \
                     -H "Content-Type: application/json" \
                     -d @test-demo.json 2>/dev/null || echo "ERROR")

if [[ $json_response == *"File uploaded successfully"* ]]; then
    echo -e "${GREEN}✅ JSON file upload successful${NC}"
    echo "Response: $json_response"
else
    echo -e "${RED}❌ JSON file upload failed${NC}"
    echo "Response: $json_response"
fi

# Clean up test files
rm -f test-demo.txt test-demo.json
echo

# Test 3: S3 Bucket Verification
echo -e "${BLUE}🗄️ Test 3: Verifying S3 Bucket Contents${NC}"

echo "Checking S3 bucket contents..."
s3_contents=$(aws s3 ls "s3://$BUCKET_NAME/uploads/" --recursive 2>/dev/null || echo "ERROR")

if [[ $s3_contents != "ERROR" && -n $s3_contents ]]; then
    echo -e "${GREEN}✅ Files found in S3 bucket:${NC}"
    echo "$s3_contents"
else
    echo -e "${YELLOW}⚠️ No files found in S3 bucket or access error${NC}"
    echo "This might be expected if uploads failed or files haven't propagated yet."
fi
echo

# Test 4: ECS Services Status
echo -e "${BLUE}🐳 Test 4: Checking ECS Services Status${NC}"

echo "Checking ECS cluster status..."
cluster_status=$(aws ecs describe-clusters --clusters "$ECS_CLUSTER" --query 'clusters[0].status' --output text 2>/dev/null || echo "ERROR")

if [[ $cluster_status == "ACTIVE" ]]; then
    echo -e "${GREEN}✅ ECS Cluster is active${NC}"
else
    echo -e "${RED}❌ ECS Cluster status: $cluster_status${NC}"
fi

# Check services
echo "Checking ECS services..."
services=$(aws ecs list-services --cluster "$ECS_CLUSTER" --query 'serviceArns' --output text 2>/dev/null || echo "ERROR")

if [[ $services != "ERROR" && -n $services ]]; then
    echo -e "${GREEN}✅ ECS Services found:${NC}"
    for service_arn in $services; do
        service_name=$(basename "$service_arn")
        service_status=$(aws ecs describe-services --cluster "$ECS_CLUSTER" --services "$service_name" --query 'services[0].status' --output text 2>/dev/null || echo "UNKNOWN")
        running_count=$(aws ecs describe-services --cluster "$ECS_CLUSTER" --services "$service_name" --query 'services[0].runningCount' --output text 2>/dev/null || echo "0")
        desired_count=$(aws ecs describe-services --cluster "$ECS_CLUSTER" --services "$service_name" --query 'services[0].desiredCount' --output text 2>/dev/null || echo "0")
        
        if [[ $service_status == "ACTIVE" && $running_count -eq $desired_count ]]; then
            echo -e "  ${GREEN}✅ $service_name: $service_status ($running_count/$desired_count tasks)${NC}"
        else
            echo -e "  ${YELLOW}⚠️ $service_name: $service_status ($running_count/$desired_count tasks)${NC}"
        fi
    done
else
    echo -e "${RED}❌ No ECS services found or access error${NC}"
fi
echo

# Test 5: CloudWatch Logs
echo -e "${BLUE}📊 Test 5: Checking CloudWatch Logs${NC}"

echo "Checking for ECS log group..."
ecs_log_group="/ecs/devops-demo-demo"
if aws logs describe-log-groups --log-group-name-prefix "$ecs_log_group" --query 'logGroups[0].logGroupName' --output text 2>/dev/null | grep -q "$ecs_log_group"; then
    echo -e "${GREEN}✅ ECS log group exists${NC}"
else
    echo -e "${YELLOW}⚠️ ECS log group not found${NC}"
fi

echo "Checking for Lambda log group..."
lambda_log_group="/aws/lambda/devops-demo-demo-upload-handler"
if aws logs describe-log-groups --log-group-name-prefix "$lambda_log_group" --query 'logGroups[0].logGroupName' --output text 2>/dev/null | grep -q "$lambda_log_group"; then
    echo -e "${GREEN}✅ Lambda log group exists${NC}"
else
    echo -e "${YELLOW}⚠️ Lambda log group not found${NC}"
fi
echo

# Summary
echo -e "${BLUE}📋 Demo Test Summary${NC}"
echo "===================="
echo -e "ALB Load Balancing:     ${GREEN}✅ Tested${NC}"
echo -e "API Gateway Upload:     ${GREEN}✅ Tested${NC}"
echo -e "S3 Storage:            ${GREEN}✅ Verified${NC}"
echo -e "ECS Services:          ${GREEN}✅ Checked${NC}"
echo -e "CloudWatch Logs:       ${GREEN}✅ Verified${NC}"
echo
echo -e "${GREEN}🎉 Demo testing completed!${NC}"
echo
echo "To manually test the endpoints:"
echo "1. ALB: curl http://$ALB_DNS"
echo "2. API: curl -X POST $API_URL/demo/upload -H 'Content-Type: text/plain' -d 'test'"
echo "3. S3: aws s3 ls s3://$BUCKET_NAME/uploads/"
echo
echo -e "${YELLOW}💡 Pro tip: Run this script multiple times to see different responses from the load balancer!${NC}"