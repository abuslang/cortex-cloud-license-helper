#!/bin/bash
#
# aws_inventory_no_deps.sh
#
# This script collects asset inventory from an AWS account to be used with the
# Cortex Cloud License Estimator. It is designed to be run in any environment
# with the AWS CLI, including AWS CloudShell, with NO ADDITIONAL DEPENDENCIES.
#
# Prerequisites:
# 1. AWS CLI installed and configured with appropriate read-only credentials.
#    (e.g., attach the ReadOnlyAccess AWS managed policy to the IAM user/role)
#
# Usage:
#    ./aws_inventory.sh

# --- Preamble ---
echo "Starting AWS Asset Inventory Collection..."
echo "NOTE: This script queries all enabled AWS regions and requires no dependencies other than the AWS CLI."
echo "This may take a few minutes."
echo "-----------------------------------------------------"

# --- Global Services (No region loop needed) ---
echo "Querying Global Services..."

# S3 Buckets
S3_BUCKETS=$(aws s3api list-buckets --query "length(Buckets)" 2>/dev/null || echo 0)
echo "Found $S3_BUCKETS S3 Buckets."

# --- Regional Services (Loop through all enabled regions) ---
echo "Querying Regional Services..."

# Initialize counters
TOTAL_EC2_INSTANCES=0
TOTAL_ECS_TASKS=0
TOTAL_LAMBDA_FUNCTIONS=0
TOTAL_ECR_IMAGES=0
TOTAL_RDS_INSTANCES=0
TOTAL_RDS_STORAGE_GB=0

# Get all enabled regions for the account
REGIONS=$(aws ec2 describe-regions --query "Regions[?OptInStatus=='opt-in-not-required' || OptInStatus=='opted-in'].RegionName" --output text)

for region in $REGIONS; do
    echo "Checking region: $region..."

    # EC2 Instances (Running)
    EC2_COUNT=$(aws ec2 describe-instances --region "$region" --filters "Name=instance-state-name,Values=running" --query "length(Reservations[].Instances[])" 2>/dev/null || echo 0)
    TOTAL_EC2_INSTANCES=$((TOTAL_EC2_INSTANCES + EC2_COUNT))

    # ECS Running Tasks
    CLUSTER_ARNS=$(aws ecs list-clusters --region "$region" --query "clusterArns" --output text 2>/dev/null)
    for cluster_arn in $CLUSTER_ARNS; do
        RUNNING_TASKS=$(aws ecs list-tasks --region "$region" --cluster "$cluster_arn" --desired-status RUNNING --query "length(taskArns[])" 2>/dev/null || echo 0)
        TOTAL_ECS_TASKS=$((TOTAL_ECS_TASKS + RUNNING_TASKS))
    done

    # Lambda Functions
    LAMBDA_COUNT=$(aws lambda list-functions --region "$region" --query "length(Functions[])" --output text 2>/dev/null || echo 0)
    TOTAL_LAMBDA_FUNCTIONS=$((TOTAL_LAMBDA_FUNCTIONS + LAMBDA_COUNT))

    # ECR Images
    REPOSITORIES=$(aws ecr describe-repositories --region "$region" --query "repositories[].repositoryName" --output text 2>/dev/null)
    for repo_name in $REPOSITORIES; do
        IMAGE_COUNT=$(aws ecr list-images --region "$region" --repository-name "$repo_name" --query "length(imageIds[])" 2>/dev/null || echo 0)
        TOTAL_ECR_IMAGES=$((TOTAL_ECR_IMAGES + IMAGE_COUNT))
    done

    # RDS DB Instances
    RDS_INSTANCES_INFO=$(aws rds describe-db-instances --region "$region" --query "DBInstances[].[DBInstanceIdentifier, AllocatedStorage]" --output text 2>/dev/null)
    if [ -n "$RDS_INSTANCES_INFO" ]; then
        while read -r line; do
            TOTAL_RDS_INSTANCES=$((TOTAL_RDS_INSTANCES + 1))
            STORAGE_GB=$(echo "$line" | awk '{print $NF}')
            if [[ "$STORAGE_GB" =~ ^[0-9]+$ ]]; then
                TOTAL_RDS_STORAGE_GB=$((TOTAL_RDS_STORAGE_GB + STORAGE_GB))
            fi
        done <<< "$RDS_INSTANCES_INFO"
    fi
done

# --- Final Summary ---
echo ""
echo "-----------------------------------------------------"
echo "           AWS Asset Inventory Summary"
echo "-----------------------------------------------------"
echo "Copy these values into the Cortex Cloud License Estimator:"
echo ""
echo "VMs (Total Running EC2 Instances):             $TOTAL_EC2_INSTANCES"
echo "  => NOTE: Manually split this total between 'VMs (not running containers)' and 'VMs (running containers)'."
echo ""
echo "CaaS (Managed Containers - ECS Tasks):         $TOTAL_ECS_TASKS"
echo "Serverless Functions (Lambda):                 $TOTAL_LAMBDA_FUNCTIONS"
echo "Container Images in Registries (ECR Images):   $TOTAL_ECR_IMAGES"
echo "Cloud Buckets (S3):                            $S3_BUCKETS"
echo "Managed Cloud Database (PaaS - RDS Instances): $TOTAL_RDS_INSTANCES"
echo "DBaaS (Total GB Stored - RDS Allocated Storage): $TOTAL_RDS_STORAGE_GB"
echo "  => NOTE: To get TB, divide this value by 1024."
echo ""
echo "Manual Entry Required For:"
echo " - SaaS Users"
echo " - Cloud ASM - Unmanaged Services"
echo "-----------------------------------------------------"
echo "Script Finished." 