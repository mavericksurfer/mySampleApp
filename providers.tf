# OIDC / dynamic credentials: HCP Terraform federates into Azure at run time,
# so there is NO client secret stored anywhere. The provider reads the
# HCP-injected values (ARM_OIDC_TOKEN, ARM_CLIENT_ID, ARM_TENANT_ID,
# ARM_SUBSCRIPTION_ID) from the environment — none are Terraform inputs.
provider "azurerm" {
  features {}
  use_oidc = true
}
