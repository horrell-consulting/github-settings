# Adopt existing repositories instead of trying to create them. Importing an
# already-managed repository is a no-op, so this block can stay in place.
import {
  for_each = local.repos
  to       = module.repository[each.key].github_repository.this
  id       = each.key
}

# doks-runners moved here from chorrell with its default-branch ruleset, which
# chorrell/github-settings created. Remove this block once it's applied.
import {
  to = module.repository["doks-runners"].github_repository_ruleset.default_branch
  id = "doks-runners:27052035"
}
