variable "environment" {
  type        = string
  description = "Environment name, derived from the workspace (e.g. dev, prod)."

  # Which environments exist is data (apps/<name>.yaml), not code. The module
  # only enforces that the name is a safe token for resource naming, so adding
  # an environment never requires editing this module.
  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,11}$", var.environment))
    error_message = "environment must be 2-12 lowercase alphanumeric chars starting with a letter."
  }
}

# The entire per-environment config arrives as one object. Callers only need
# to set what actually differs; everything else falls back to a convention
# default. optional() attributes make the YAML files tiny and hard to get wrong.
variable "config" {
  description = "Per-environment configuration, loaded from environments/<env>.yaml."

  type = object({
    workload       = string
    location       = optional(string, "australiaeast")
    sku_name       = optional(string, "B1")
    instance_count = optional(number, 1)
    always_on      = optional(bool) # null => derived from environment
    tags           = optional(map(string), {})
  })

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,10}$", var.config.workload))
    error_message = "workload must be 2-11 lowercase alphanumeric chars starting with a letter."
  }

  validation {
    condition     = can(regex("^(B[1-3]|S[1-3]|P[0-9]v[0-9])$", var.config.sku_name))
    error_message = "sku_name must be a valid App Service plan SKU (e.g. B1, B2, P1v3)."
  }
}
