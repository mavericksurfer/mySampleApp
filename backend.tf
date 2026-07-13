terraform {
  required_version = ">= 1.9.0"

  # HCP Terraform (Terraform Cloud) — CLI-driven workflow.
  # Using `tags` (instead of a fixed `name`) lets ONE config target
  # multiple workspaces: app-dev, app-prod.
  # The specific workspace is chosen at runtime via the TF_WORKSPACE
  # environment variable (set per-environment in the GitHub workflow).
  cloud {
    organization = "AzureArchitectAU" # <-- change to your HCP Terraform org

    workspaces {
      tags = ["demoapp", "azure"]
    }
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.80.0" # patch-flexible pin (no lock file committed)
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9.0"
    }
  }
}
