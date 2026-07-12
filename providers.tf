# OIDC / dynamic credentials: HCP Terraform federates into Azure at run time,
# so there is NO client secret stored anywhere. The provider reads the
# HCP-injected values (ARM_OIDC_TOKEN, ARM_CLIENT_ID, ARM_TENANT_ID,
# ARM_SUBSCRIPTION_ID) from the environment — none are Terraform inputs.
provider "azurerm" {
  features {}
  use_oidc = true

  # Only register the small "core" set of resource providers (includes
  # Microsoft.Web) instead of azurerm's full legacy list. This avoids trying to
  # register providers this app never uses (e.g. Microsoft.HDInsight), which on
  # a fresh subscription can 409 against Azure's own background registration.
  resource_provider_registrations = "core"
}
