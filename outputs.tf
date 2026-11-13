output "repositories" {
  description = "Managed repositories and their URLs."
  value       = { for name, repo in module.repository : name => repo.html_url }

  # main.tf reads each option with try(), so a misspelled key in repos.yaml
  # would otherwise be ignored silently. Fail the plan instead.
  precondition {
    condition     = length(local.unknown_repo_options) == 0
    error_message = "Unknown options in repos.yaml: ${join(", ", local.unknown_repo_options)}. See modules/repository/variables.tf."
  }
}
