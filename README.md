# pipeline-bitbucket-gcp-oidc-and-terraform
Basic Bitbucket pipeline configuration that authenticates to GCP via OpenID Connect (OIDC),
gets federation token, exchanges for oauth token impersonating a service account and 
then runs Terraform job.

* expects your terraform configuration to be in ./terraform

# contributors
* cameron kennedy
