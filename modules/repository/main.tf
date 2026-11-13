resource "github_repository" "this" {
  name         = var.name
  visibility   = var.visibility
  description  = var.description
  homepage_url = var.homepage_url
  topics       = var.topics
  is_template  = var.is_template

  has_issues      = var.has_issues
  has_discussions = var.has_discussions
  has_projects    = false
  has_wiki        = false

  # Squash merging only, using the pull request title and description.
  allow_merge_commit          = false
  allow_rebase_merge          = false
  allow_squash_merge          = true
  squash_merge_commit_title   = "PR_TITLE"
  squash_merge_commit_message = "PR_BODY"

  allow_auto_merge       = true
  allow_update_branch    = true
  delete_branch_on_merge = true

  # Secret scanning is free for public repositories only; private ones need
  # GitHub Secret Protection.
  dynamic "security_and_analysis" {
    for_each = var.visibility == "public" ? [1] : []
    content {
      secret_scanning {
        status = "enabled"
      }
      secret_scanning_push_protection {
        status = "enabled"
      }
    }
  }

  lifecycle {
    # Removing a repository from repos.yaml must never delete it on GitHub.
    prevent_destroy = true

    # Records which template a repository was created from; it can't be
    # changed afterwards, so don't try to reconcile it.
    ignore_changes = [template]
  }
}

resource "github_repository_vulnerability_alerts" "this" {
  repository = github_repository.this.name
  enabled    = true

  # A forced replacement fails the plan instead; see the ruleset below.
  lifecycle {
    prevent_destroy = true
  }
}

resource "github_repository_dependabot_security_updates" "this" {
  repository = github_repository.this.name
  enabled    = true

  depends_on = [github_repository_vulnerability_alerts.this]

  # A forced replacement fails the plan instead; see the ruleset below.
  lifecycle {
    prevent_destroy = true
  }
}

resource "github_workflow_repository_permissions" "this" {
  repository                       = github_repository.this.name
  default_workflow_permissions     = "read"
  can_approve_pull_request_reviews = false

  # A forced replacement fails the plan instead; see the ruleset below.
  lifecycle {
    prevent_destroy = true
  }
}

resource "github_repository_ruleset" "default_branch" {
  name        = "default-branch"
  repository  = github_repository.this.name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  # Repository admins (you) can bypass the rules in an emergency.
  bypass_actors {
    actor_id    = 5 # Built-in "admin" repository role
    actor_type  = "RepositoryRole"
    bypass_mode = "always"
  }

  rules {
    deletion                = true
    non_fast_forward        = true
    required_linear_history = true

    pull_request {
      allowed_merge_methods             = ["squash"]
      required_approving_review_count   = 0
      required_review_thread_resolution = true
      dismiss_stale_reviews_on_push     = true
    }

    dynamic "required_status_checks" {
      for_each = length(var.required_status_checks) > 0 ? [1] : []
      content {
        strict_required_status_checks_policy = false

        dynamic "required_check" {
          for_each = var.required_status_checks
          content {
            context = required_check.value
          }
        }
      }
    }

    dynamic "merge_queue" {
      for_each = var.merge_queue ? [1] : []
      content {
        merge_method = "SQUASH"
      }
    }
  }

  # Merges apply without a confirm, so a change that would destroy or replace
  # any of these resources fails the plan instead. Replacing the ruleset would
  # leave the branch unprotected for a moment and change the ruleset's ID.
  lifecycle {
    prevent_destroy = true
  }
}
