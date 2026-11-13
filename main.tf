locals {
  # Managed repositories and their options. Kept as YAML so values are plain
  # data: `${` in a description is text, not a Terraform template.
  repos = yamldecode(file("${path.module}/repos.yaml"))

  repo_options = [
    "visibility", "description", "homepage_url", "topics", "is_template",
    "has_issues", "has_discussions", "required_status_checks", "merge_queue",
  ]
  # Checks every repository must pass, on top of its own required_status_checks.
  # Repositories get the zizmor stub from chorrell/template-repo.
  baseline_status_checks = ["zizmor / zizmor"]

  unknown_repo_options = sort(flatten([
    for name, repo in local.repos : [
      for key in keys(repo) : "${name}.${key}" if !contains(local.repo_options, key)
    ]
  ]))
}

module "repository" {
  source   = "./modules/repository"
  for_each = local.repos

  name                   = each.key
  visibility             = each.value.visibility
  description            = try(each.value.description, null)
  homepage_url           = try(each.value.homepage_url, null)
  topics                 = try(each.value.topics, [])
  is_template            = try(each.value.is_template, false)
  has_issues             = try(each.value.has_issues, true)
  has_discussions        = try(each.value.has_discussions, false)
  required_status_checks = distinct(concat(local.baseline_status_checks, try(each.value.required_status_checks, [])))
  merge_queue            = try(each.value.merge_queue, false)
}
