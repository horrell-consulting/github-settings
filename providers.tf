# Authenticates as a GitHub App, from the sensitive GITHUB_APP_ID,
# GITHUB_APP_INSTALLATION_ID and GITHUB_APP_PEM_FILE environment variables on
# the HCP workspace. Runs only happen on HCP, so there's no token fallback.
provider "github" {
  owner = var.owner

  app_auth {}
}
