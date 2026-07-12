# Root: one YAML file describes the whole app. We derive the environment from
# the workspace name, resolve this environment's config (shared defaults
# overlaid with per-env overrides), and hand it to the reusable app module.
# There are no CLI vars to pass at deploy time.
locals {
  # Single app in this repo. To manage another app, add apps/<name>.yaml and
  # point a separate root/workspace set at it.
  app_name = "demoapp"
  app_file = "${path.module}/apps/${local.app_name}.yaml"

  # HCP workspace is "app-dev" / "app-prod" -> environment is "dev" / "prod".
  environment = trimprefix(terraform.workspace, "app-")

  # Config as data: parse the app file, then resolve this environment's slice.
  app = yamldecode(file(local.app_file))

  # workload + shared defaults + this environment's overrides.
  # try(...) keeps resolution safe when the env is missing so the precondition
  # below can report a clear error instead of a cryptic index failure.
  config = merge(
    { workload = local.app.workload },
    try(local.app.defaults, {}),
    try(local.app.environments[local.environment], {}),
  )
}

# Fail clearly if the workspace maps to an environment not defined in the file.
resource "terraform_data" "validate_environment" {
  lifecycle {
    precondition {
      condition = contains(keys(local.app.environments), local.environment)
      error_message = format(
        "Environment %q (from workspace %q) is not defined in %s. Defined environments: %s.",
        local.environment,
        terraform.workspace,
        basename(local.app_file),
        join(", ", keys(local.app.environments)),
      )
    }
  }
}

module "app" {
  source      = "./modules/app"
  environment = local.environment
  config      = local.config
}
