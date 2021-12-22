#!/bin/bash 

# This is the pipeline script that handles the Google authentication
# using OIDC. 
# Assumes we are using a Debian based pipeline image.
# Assumes scripts are located in ${BITBUCKET_CLONE_DIR}/pipelineScripts
# Refer to getOauthToken.py for details around environment variables.
#
# Author: Cameron Kennedy

# Following variables needed for get_google_credentials
export WORKLOAD_IDENTITY_POOL_ID=bitbucket                       # should already exist in your project
export WORKLOAD_IDENTITY_PROVIDER_ID=${BITBUCKET_REPO_SLUG}
#export BITBUCKET_STEP_OIDC_TOKEN=<Bitbucket sets this for us, because we enabled in yml file>
#export WORKLOAD_IDENTITY_PROJECT_NUMBER=<deployment variable>
#export SERVICE_ACCOUNT_EMAIL=<deployment variable>              # full email of service account we will impersonate
#export TERRAFORM_ACTION=<deployment variable>                   # should be either apply or destroy or plan
#export TERRAFORM_STATE_BUCKET=<deployment variable>             # GCS bucket that has versioning enabled to store out state file


# Update OS Packages.
printf 'Updating Debian packages...\n\n\n'
apt update
apt install -y unzip gettext-base python3 python3-dev python3-venv wget vim



# Configure Python 
printf "Setting up python virtual environment and installing dependancies...\n\n"
export PY_VIRT=/tmp/py-virt
if [ -d ${PY_VIRT} ]; then 
  rm -rf ${PY_VIRT}
fi 

mkdir -p ${PY_VIRT}
cd ${PY_VIRT}

python3 -m venv env
source env/bin/activate



# Now install packages 
pip install -r ${BITBUCKET_CLONE_DIR}/pipelineScripts/requirements.txt



# Make sure we have the correct pipeline variables available
export  PIPELINE_VARIABLES="BITBUCKET_STEP_OIDC_TOKEN
                            SERVICE_ACCOUNT_EMAIL
                            TERRAFORM_ACTION
                            TERRAFORM_STATE_BUCKET
                            WORKLOAD_IDENTITY_POOL_ID
                            WORKLOAD_IDENTITY_PROJECT_NUMBER
                            WORKLOAD_IDENTITY_PROVIDER_ID"

for VARIABLE in $PIPELINE_VARIABLES; do
    if [ $(set |grep ^"$VARIABLE=" |wc -l) -ne 1 ]; then
        echo "ERROR: Have you set the pipeline variable $VARIABLE?"
        echo "These are all the variables we are expecting from Bitbucket:"
        echo $PIPELINE_VARIABLES
        exit 1
    else
        echo "INFO: Found variable $VARIABLE"
        # Expose all these variables to Terraform by re-exporting them as TF_VAR_{variablename}
        export TF_VAR_${VARIABLE}=${!VARIABLE}
    fi
done



# Getting our service account impersonated token.
printf '\n\n\n\nGetting OAuth Token from Google...\n\n'
export SVC_ACCOUNT_TOKEN_FILE=/tmp/svcAccountToken
cd $BITBUCKET_CLONE_DIR/pipelineScripts
python3 ./getOauthToken.py



# Setting our local variable to our temporary service account token
if [ $? -eq 0 ]; then
    printf 'Checking for service account file...\n\n'
    if [ -f $SVC_ACCOUNT_TOKEN_FILE ]; then
        export GOOGLE_OAUTH_ACCESS_TOKEN=$(cat $SVC_ACCOUNT_TOKEN_FILE)
    else
        printf 'cant find file that should have our token in.\n\n'
        exit 1
    fi
else 
    printf 'non-zero return from python trying to get our token. FAIL\n\n'
    exit 1
fi       
