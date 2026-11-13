# github-settings

[![terraform](https://github.com/horrell-consulting/github-settings/actions/workflows/terraform.yml/badge.svg)](https://github.com/horrell-consulting/github-settings/actions/workflows/terraform.yml)
[![zizmor](https://github.com/horrell-consulting/github-settings/actions/workflows/zizmor.yml/badge.svg)](https://github.com/horrell-consulting/github-settings/actions/workflows/zizmor.yml)

Every repository in the `horrell-consulting` organization, including this one,
is configured by the Terraform in this repository. Settings, branch rulesets,
required checks and security features are code, reviewed in a pull request and
applied on merge by HCP Terraform. New repositories are onboarded by a bot.

## What every repository gets

Each repository listed in [`repos.yaml`](repos.yaml) gets the baseline in
[`modules/repository`](modules/repository):

- **Merging:** squash merges only, with the pull request title and description
  as the commit message. Auto-merge and "update branch" are on, and head
  branches are deleted after merging.
- **Default branch ruleset:** changes go through a pull request, with linear
  history, no force-pushes and no deletion. Review threads must be resolved.
  Repository admins can bypass it in an emergency.
- **Required checks:** `zizmor / zizmor` (GitHub Actions security audit) on
  every repository, plus each repository's own CI checks.
- **Security:** Dependabot alerts and security updates, and secret scanning
  with push protection.
- **Actions:** the default `GITHUB_TOKEN` is read-only and can't approve pull
  requests.
- **Housekeeping:** wikis and projects are off.

## How it works

```text
pull request ──► HCP speculative plan + Sentinel policy check + CI ──► review ──► merge ──► apply
                                                                                     ▲
daily new-repos bot ──► pull request adding unmanaged repositories ───────────────────┘
```

1. A pull request gets a speculative plan from HCP Terraform, reported as the
   `Terraform Cloud/horrell/horrell-consulting-github-settings` check, and a
   policy check, `sentinel/horrell/horrell-consulting-github-settings`. Both
   are required, along with `validate`, markdownlint and pre-commit.
2. Merging to `main` applies the plan without a confirm. The pull request is
   where review happens.
3. The [`new-repos`](.github/workflows/new-repos.yml) workflow runs daily and
   opens a pull request adding any repository that isn't archived, isn't a
   fork, and isn't in `repos.yaml` yet. Each entry copies the repository's
   current description, topics and settings, so the first apply changes only
   the baseline. Existing repositories are adopted with `import` blocks, not
   recreated.

## Design decisions

- **Nothing can be deleted by accident.** Merges apply unattended, so there
  are three independent guards: `prevent_destroy` on every resource, a
  [Sentinel policy](https://github.com/chorrell/hcp-terraform-horrell/blob/main/policies/no-deletes.sentinel)
  that fails any plan deleting or replacing a resource, and destroy plans
  turned off on the workspace. Removing a repository from `repos.yaml` fails
  the plan instead of deleting it.
- **The repository list is data, not HCL.** `repos.yaml` is read with
  `yamldecode`, so a bot can edit it safely and a `${` in a description is just
  text. A misspelled option fails the plan rather than being silently ignored.
- **GitHub Apps, not personal access tokens.** Terraform authenticates as an
  organization-owned GitHub App with only the permissions it needs. The bot
  uses a second, smaller app, and mints two short-lived tokens per run: one
  that can only read metadata across the organization, and one that can write
  to this repository only. Pull requests opened with an app token run CI,
  which `GITHUB_TOKEN` pull requests don't.
- **Public, but safe to be public.** No secrets are in the repository or its
  state: credentials are sensitive variables on the HCP workspace. HCP
  Terraform doesn't run speculative plans for pull requests from forks, so an
  outside contribution can't run provider code with the app's key.
- **No merge queue here.** The module supports one (`merge_queue: true`), but
  HCP Terraform plans pull requests, not merge queue branches, so its required
  check would never report and every queued pull request would wait forever.
  Merge queues suit repositories whose required checks all come from GitHub
  Actions with a `merge_group` trigger.
- **Separate from my personal repositories.** My personal account has its own
  copy of this setup for private repositories. Keeping them apart gives each
  owner its own GitHub App, workspace and state, so a mistake in one can't
  reach the other.

## Usage

- **Change a setting:** edit `repos.yaml` or the module, open a pull request,
  read the HCP plan, and merge.
- **Add a repository:** create it from
  [chorrell/template-repo](https://github.com/chorrell/template-repo), which
  provides the zizmor stub every repository requires. The bot proposes it
  within a day, or run the workflow from the Actions tab. Add its CI checks to
  `required_status_checks` in the bot's pull request before merging.
- **Keep a repository out:** archive it.
- **Stop managing a repository:** open the pull request that removes its
  entry, run `terraform state rm 'module.repository["<name>"]'` from a laptop,
  re-run the pull request's plan, and merge it right away.

`terraform plan` from a laptop runs a remote speculative plan after
`terraform login`. `terraform apply` from a laptop fails, because the
workspace is VCS-connected: merging is the only way to apply.

Run `prek run --all-files` before pushing. It covers `terraform fmt`,
`validate` and tflint, ruff for `scripts/`, zizmor, gitleaks and markdownlint.

## Setup

Done once; kept here so the setup can be reproduced.

1. **Terraform's GitHub App.** Create a GitHub App owned by the organization,
   with no webhook and these repository permissions: **Administration** read
   and write, **Dependabot alerts** read and write, **Contents** read,
   **Pages** read. Install it on all repositories.
2. **HCP Terraform workspace.** Install the HCP Terraform GitHub App on the
   organization, then create the workspace `horrell-consulting-github-settings`
   in the `horrell` HCP organization, connected to this repository. Add
   `GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION_ID` and `GITHUB_APP_PEM_FILE` as
   sensitive environment variables. The key goes on one line, with `\n` for
   each line break:

   ```sh
   awk 'NF {printf "%s\\n", $0}' key.pem | pbcopy
   ```

   The workspace's run settings, notifications and Sentinel policy are managed
   in [chorrell/hcp-terraform-horrell](https://github.com/chorrell/hcp-terraform-horrell).
3. **Bot app.** Create a second organization-owned GitHub App with no webhook
   and **Contents** and **Pull requests** read and write. Install it on all
   repositories. Add its client ID as the Actions variable
   `NEW_REPOS_APP_CLIENT_ID` and a private key as the Actions secret
   `NEW_REPOS_APP_PRIVATE_KEY`. If a scheduled run fails, it opens an issue,
   which the next successful run closes.

## License

[MPL-2.0](LICENSE)
