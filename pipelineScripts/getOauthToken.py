"""
Purpose:  This will take an OIDC token provided by Bitbucket during
          a pipeline run, and exchange it with Google for a federated
          access token, which it will then exchange with Google for 
          a an access token that can be used as a GOOGLE_OAUTH_ACCESS_TOKEN.

Environment variables required:
- BITBUCKET_STEP_OIDC_TOKEN: generated automatically by Bitbucket when oidc is 
                             enabled in the pipeline.
- WORKLOAD_IDENTITY_PROJECT_NUMBER: gcp project number for the project hosting 
                                    the worklad identity pool to contact.
- WORKLOAD_IDENTITY_POOL_ID: workload identity pool id to contact.
- WORKLOAD_IDENTITY_PROVIDER_ID: workload identity provider id to contact.
- SERVICE_ACCOUNT_EMAIL: gcp service account email to impersonate and get token for.
- SVC_ACCOUNT_TOKEN_FILE: output file where our token will be written to.

Output: Once this completes successfully, you can then set an environment variable 
        in your pipeline like: 
            export GOOGLE_OAUTH_ACCESS_TOKEN=$(cat $SVC_ACCOUNT_TOKEN_FILE)

        Then you can make authenticated calls to GCP, as that service account, using 
        applications that are oauth aware, such as Terraform and Python.

Author: Cameron Kennedy June-19-2021
"""

import sys
import os
import json
import requests

def getFederationToken(payload) :
    URL = "https://sts.googleapis.com/v1/token"
    headers = {'Content-Type': 'application/json'}
    response = requests.post(URL, headers=headers, data=payload)
    response = response.json()
    if type(response) == dict and 'access_token' in response :
        return str(response['access_token'])
    else :
        return "ERROR: Expected response['access_token'], but got: " + str(response)


def getServiceAccountToken(fedToken, serviceAccountEmail, payload) :
    URL = f"https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/{serviceAccountEmail}:generateAccessToken"
    headers = {"Authorization": f"Bearer {fedToken}", 'Content-Type': 'application/json'}
    response = requests.post(URL, headers=headers, data=payload)
    response = response.json()
    if type(response) == dict and 'accessToken' in response :
        return str(response['accessToken'])
    else :
        return "ERROR: Expected response['accessToken'], but got: " + str(response)





def main() :
    """
    Main entry point.
    """
    
    ### Retrieve needed environment variables
    osVariables = ['BITBUCKET_STEP_OIDC_TOKEN', 
                   'WORKLOAD_IDENTITY_PROJECT_NUMBER', 
                   'WORKLOAD_IDENTITY_POOL_ID',
                   'WORKLOAD_IDENTITY_PROVIDER_ID',
                   'SERVICE_ACCOUNT_EMAIL',
                   'SVC_ACCOUNT_TOKEN_FILE']

    osEnv = {}
    osVals = []

    for var in osVariables :
        osEnv[var] = os.environ.get(var, False)
        osVals.append(osEnv[var])

    if not (all(osVals)) :
        print('We dont have all our variables. Any variables showing as FALSE have not been setup. This is what we got: ' + str(osEnv))
        return False


    ### Exchange our Bitbucket OpenID (OIDC) token with Google for a for federation token
    A = osEnv['WORKLOAD_IDENTITY_PROJECT_NUMBER']
    B = osEnv['WORKLOAD_IDENTITY_POOL_ID']
    C = osEnv['WORKLOAD_IDENTITY_PROVIDER_ID']
    D = osEnv['BITBUCKET_STEP_OIDC_TOKEN']
    audience = (f"//iam.googleapis.com/projects/{A}/locations/global/workloadIdentityPools/{B}/providers/{C}")
    scope = "https://www.googleapis.com/auth/cloud-platform"

    payload = {
                "audience": audience,
                "grantType": "urn:ietf:params:oauth:grant-type:token-exchange",
                "requestedTokenType": "urn:ietf:params:oauth:token-type:access_token",
                "scope": scope,
                "subjectTokenType": "urn:ietf:params:oauth:token-type:jwt",
                "subjectToken": D
            }

    payload = json.dumps(payload)
    fedToken = getFederationToken(payload)
    if fedToken.startswith('ERROR:') :
        print(f"Failed to get federation token with error:\n{fedToken}\n")
        print(f"Used the following payload when requesting a federation token:\n{payload}\n")
        return False

    
    ### Exchange our federation token with Google for a for impersonated service account token
    payload = {"scope": [scope]}
    payload = json.dumps(payload)
    
    serviceAccountToken = getServiceAccountToken(fedToken, osEnv['SERVICE_ACCOUNT_EMAIL'], payload)
    if serviceAccountToken.startswith("ERROR:") :
        print(f"We got a federation token but failed to exchange it for a service account impersonation token with error:\n{serviceAccountToken}\n")
        return False

    ### Write the token to a local file
    filename = osEnv['SVC_ACCOUNT_TOKEN_FILE']
    f = open(filename, "w")
    f.write(serviceAccountToken)
    f.close()
    print(f"Wrote oauth token to file: {filename}")

    return True


		
		
if __name__ == '__main__' :
    result = main()
    if not result :
        sys.exit(1)
