# Adopt existing repositories instead of trying to create them. Importing an
# already-managed repository is a no-op, so this block can stay in place.
import {
  for_each = local.repos
  to       = module.repository[each.key].github_repository.this
  id       = each.key
}
