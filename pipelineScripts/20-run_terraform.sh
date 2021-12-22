#!/bin/bash 

# Any other exports expected by Terraform, do them here
# export TF_VAR_FOO=BAR




# This is the version of Terraform we will use
export TERRAFORM_VERSION=0.14.5 

# set Cloud Function Bucket
echo "INFO: The Terraform bucket is set to:  gs://${TERRAFORM_STATE_BUCKET}/terraform/state/${BITBUCKET_REPO_SLUG}"

# Setup Terraform.
echo "INFO: Setting up Terraform environment..."
cd ~
rm -rf terrafor*
wget -q https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip
export PATH=$PATH:$(pwd)

# Provision Terraform resources.
cd ${BITBUCKET_CLONE_DIR}/terraform

# Download plugins needed for Terraform 
terraform init \
         -backend-config="bucket=${TERRAFORM_STATE_BUCKET}" \
         -backend-config="prefix=terraform/state/${BITBUCKET_REPO_SLUG}"

# Ensure Terraform syntax is valid before proceeding.
terraform validate

# Run Terraform plan to determine what will be changed 
terraform plan

# Apply Terraform configuration changes
if [ ! -z ${TERRAFORM_ACTION+1} ]; then
    echo "TERRAFORM_ACTION passed as repository variable."
else
    echo "didnt find Bitbucket repo variable called TERRAFORM_ACTION. Exiting as I dont know whether to apply or destroy"
    exit 1
fi
echo "INFO: running a ${TERRAFORM_ACTION} action."
terraform ${TERRAFORM_ACTION} -auto-approve
