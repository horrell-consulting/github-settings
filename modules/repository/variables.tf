variable "name" {
  description = "Repository name."
  type        = string
}

variable "visibility" {
  description = "Repository visibility: public or private."
  type        = string

  validation {
    condition     = contains(["public", "private"], var.visibility)
    error_message = "visibility must be \"public\" or \"private\"."
  }
}

variable "description" {
  description = "Repository description. Leaving it null clears any existing description."
  type        = string
  default     = null
}

variable "homepage_url" {
  description = "Repository homepage URL. Leaving it null clears any existing URL."
  type        = string
  default     = null
}

variable "topics" {
  description = "Repository topics."
  type        = list(string)
  default     = []
}

variable "is_template" {
  description = "Whether the repository is a template repository."
  type        = bool
  default     = false
}

variable "has_issues" {
  description = "Whether issues are enabled."
  type        = bool
  default     = true
}

variable "has_discussions" {
  description = "Whether discussions are enabled."
  type        = bool
  default     = false
}

variable "required_status_checks" {
  description = "Status check names that must pass before merging into the default branch."
  type        = list(string)
  default     = []
}

variable "merge_queue" {
  description = "Require a merge queue on the default branch. Only works for public repositories owned by an organization."
  type        = bool
  default     = false
}
