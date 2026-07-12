# Discover platform context instead of receiving it as inputs. The subscription
# and tenant are provided by HCP's dynamic credentials; we read them back rather
# than asking the caller to type them.
data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

locals {
  # Naming convention: <type>-<workload>-<env>-<region>. Every resource name is
  # derived from three true inputs, so names can't drift or be mistyped.
  region_short = {
    australiaeast      = "aue"
    australiasoutheast = "ause"
    eastus             = "eus"
    westeurope         = "weu"
  }
  loc         = lookup(local.region_short, var.config.location, "unk")
  name_prefix = "${var.config.workload}-${var.environment}-${local.loc}"

  # Convention, not a per-call flag: prod stays warm, non-prod idles.
  # An explicit value in YAML still wins.
  always_on = coalesce(var.config.always_on, var.environment == "prod")

  # Tags are computed from context, not hand-maintained per environment.
  common_tags = merge({
    workload     = var.config.workload
    environment  = var.environment
    location     = var.config.location
    managed_by   = "terraform"
    workspace    = terraform.workspace
    subscription = data.azurerm_subscription.current.display_name
  }, var.config.tags)
}

# Web App names must be globally unique across Azure, so add a short suffix.
resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${local.name_prefix}"
  location = var.config.location
  tags     = local.common_tags
}

resource "azurerm_service_plan" "this" {
  name                = "plan-${local.name_prefix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  os_type             = "Linux"
  sku_name            = var.config.sku_name
  worker_count        = var.config.instance_count
  tags                = local.common_tags
}

resource "azurerm_linux_web_app" "this" {
  name                = "app-${local.name_prefix}-${random_string.suffix.result}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  service_plan_id     = azurerm_service_plan.this.id
  https_only          = true
  tags                = local.common_tags

  site_config {
    always_on = local.always_on
    application_stack {
      node_version = "20-lts"
    }
  }

  app_settings = {
    APP_ENVIRONMENT = var.environment
  }

  identity {
    type = "SystemAssigned"
  }
}
