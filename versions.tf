terraform {
  required_version = ">= 1.16"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.13"
    }
  }

  # Runs on HCP Terraform: a PR gets a speculative plan, and a merge to main
  # applies. The workspace's settings live in chorrell/hcp-terraform-horrell.
  cloud {
    organization = "horrell"
    workspaces {
      name = "horrell-consulting-github-settings"
    }
  }
}
