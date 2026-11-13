# AGENTS.md

Terraform for the settings and rulesets of the repositories owned by the `horrell-consulting` organization. See [README.md](README.md) for the
baseline every repository gets and for day-to-day usage.

## Structure

```text
├── repos.yaml                  # Every managed repository and its per-repo options (plain data)
├── main.tf                     # yamldecode(repos.yaml) into local.repos; one module.repository per entry
├── imports.tf                  # for_each import block: adopts existing repositories on apply
├── providers.tf                # integrations/github, GitHub App auth (app_auth) from GITHUB_APP_* on the workspace
├── variables.tf                # owner (defaults to horrell-consulting)
├── versions.tf                 # Terraform >= 1.16, integrations/github ~> 6.13; cloud block, horrell/horrell-consulting-github-settings
├── outputs.tf                  # Managed repositories and their URLs; fails the plan on unknown options
├── modules/repository/         # The baseline: repository settings, security, Actions permissions, ruleset
├── scripts/new_repos.py        # Adds entries to repos.yaml for repositories that aren't managed yet
└── .github/workflows/
    ├── terraform.yml           # Shared terraform-validate (fmt, init, validate, tflint), gated by the `validate` job
    ├── markdownlint.yml        # chorrell/workflows reusable markdownlint
    └── new-repos.yml           # Daily: runs new_repos.py and opens a PR on bot/new-repos (GitHub App auth);
                                # a failed scheduled run opens an issue (chorrell/workflows scheduled-failure-issue)
```

## Rules

- **Generate new entries with `scripts/new_repos.py`, don't write them by hand.** `description`, `homepage_url`,
  `topics`, `has_issues` and `has_discussions` are managed, so leaving one out resets it on the repository. The
  script copies the current values from GitHub and sets only what differs from the defaults in
  `modules/repository/variables.tf`. It can't know about CI, so add `required_status_checks` by hand.
- **Keep `repos.yaml` as plain data.** Quote strings that aren't simple words (the script uses JSON-style double
  quotes, which are valid YAML). A new option needs a variable in the module, a `try()` in `main.tf`, and an entry in
  `local.repo_options` and the script's `OPTIONS`.
- **The `new-repos` workflow proposes new repositories daily** as a PR from `bot/new-repos`. While that PR is open,
  later runs skip, so push edits (such as required checks) straight to its branch.
  The workflow is skipped until the GitHub App variable and secret exist; see the README's "Setup".
- **This repository is public and a portfolio piece.** Keep the history, issues and PRs free of secrets and of
  anything about private repositories. Those are managed separately, by `chorrell/github-settings`.
- **Managed repositories must be public.** The organization is on GitHub Free, which doesn't allow rulesets on private
  repositories, so an apply fails on a private entry.
- **Don't turn on `merge_queue` for this repository.** HCP Terraform doesn't report on merge queue branches, so its required
  check would never report. Use it only where every required check runs in GitHub Actions with a `merge_group` trigger.
- **To keep a repository out, archive it.** The bot skips archived repositories and forks, and proposes anything else
  that isn't in `repos.yaml`, so dropping an entry from its PR only lasts until the next run.
- **Removing an entry never deletes a repository.** `prevent_destroy` makes the PR's plan fail instead. To stop
  managing one, open the PR that drops the entry, then run `terraform state rm 'module.repository["<name>"]'` from a
  laptop (it edits the HCP state) and re-run the PR's plan, which should show no changes. Merge it right away: until
  then, a run on `main` would import the repository again. A `removed` block can't target one `for_each` instance.
- **Archived repositories and forks are not managed.** Archived repositories are read-only, so an apply fails on them.
  Archive a repository only after removing it from `repos.yaml` and the state.
- **To make a private repository public, flip it first, then merge.** The provider sends `visibility` and
  `security_and_analysis` in one PATCH, and GitHub rejects it with `422 Secret scanning is not available for this
  repository` while the repository is still private. Open the `visibility: public` PR and check its plan, then run
  `gh repo edit horrell-consulting/<name> --visibility public --accept-visibility-change-consequences` and merge the PR right
  away. The merge's apply then only turns on secret scanning and push protection. Until the PR merges, any apply here
  makes the repository private again, so don't flip it while another PR is about to merge.
  - If the PR was merged first, its apply fails with that 422. Flip the repository, then re-run the apply (a manual
    run needs a confirm in HCP).
- **Every repository gets exactly one ruleset, `default-branch`, owned by Terraform.** Don't add rulesets or branch
  protection in the GitHub UI; put required checks in `required_status_checks` instead.
- **`zizmor / zizmor` is required on every repository** (`local.baseline_status_checks` in `main.tf`). Don't list it in
  `repos.yaml`. Before applying a new entry, make sure the repository has the zizmor stub from `chorrell/template-repo`,
  or its pull requests can't merge.
- **Read every PR's HCP speculative plan before merging.** Merging applies it. Expect only the intended changes. A
  diff on `description`, `topics` or other per-repository fields means an entry is missing a value.
- **Never apply from a laptop.** State is in HCP; `terraform plan` from a laptop runs remotely as a speculative plan,
  and `terraform apply` fails because the workspace is VCS-connected. See "Auto-apply workflow" below.
- This repository is managed by itself, so every change goes through a pull request and is squash-merged.
- Run `prek run --all-files` before pushing. It covers `terraform fmt`/`validate`/`tflint`, ruff (check and format)
  for `scripts/`, zizmor, gitleaks and markdownlint.
  zizmor is the workflow linter; actionlint isn't used because it rejects GitHub's `$/` self-repository `uses:`
  syntax ([rhysd/actionlint#711](https://github.com/rhysd/actionlint/issues/711)).
- Commits and PR titles use conventional commits (`feat: ...`, `chore(deps): ...`). Keep PR bodies short and focused
  on intent.

## Auto-apply workflow

State and runs live in the HCP Terraform workspace `horrell/horrell-consulting-github-settings`, whose settings are managed in
[chorrell/hcp-terraform-horrell](https://github.com/chorrell/hcp-terraform-horrell). A merge to `main` is the deploy:
it queues a run that applies without a confirm. The PR is where review happens.

- **Every PR gets a speculative plan,** reported as `Terraform Cloud/horrell/horrell-consulting-github-settings` with its
  add/change/destroy counts, and a policy check, `sentinel/horrell/horrell-consulting-github-settings`. Both are required, with
  `validate` and `markdownlint / Markdown Lint`, so a PR can't merge until the plan passes.
- **The provider authenticates as a GitHub App** (separate from the new-repos bot), from the sensitive
  `GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION_ID` and `GITHUB_APP_PEM_FILE` env vars on the workspace, set by hand in
  the HCP UI. `app_auth {}` makes them required arguments, so CI and pre-commit pass placeholders to `validate`.
- **Deletion guards:**
  - `prevent_destroy` is on every resource in `modules/repository`, so a removed entry or a change that forces a
    replacement fails the plan. Replacing a ruleset would leave the branch unprotected for a moment and change its ID.
  - `prevent_destroy` only covers resources still in config. A PR that removes the guard, or renames a resource
    without a `moved` block, plans a plain destroy. The `no-deletes` Sentinel policy (soft-mandatory, in
    hcp-terraform-horrell's `deletion-guard` set) fails any plan that deletes or replaces a resource, and with it the
    required `sentinel/horrell/horrell-consulting-github-settings` check.
  - **Allow destroy plans** is off on the workspace, so nobody can queue a whole-workspace destroy run.
- **To unmanage a repository,** use `terraform state rm` as in the rules above, not a delete.
- **To delete or replace something on purpose,** remove the `prevent_destroy` in the PR, merge it with the admin
  bypass (the policy check fails on the speculative plan, which can't be overridden), then override the soft-failed
  policy check on the apply run in the HCP UI. Restore the guard in a follow-up PR.
- The workspace emails the owner when a run starts applying, waits for approval or errors, since nobody watches the
  runs.
