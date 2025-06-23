variable "github_token" {
  type        = string
  description = "GitHub token"
}

variable "github_owner" {
  type        = string
  description = "GitHub organization owner"
}

variable "company_name" {
  type        = string
  description = "Prefix name for teams"
}

variable "teams_structure" {
  description = "Map of teams and their roles and permissions"
  type = map(object({
    slug         = string
    description  = string
    role_default = string
    permissions = object({
      review = bool
      push   = bool
      bypass = bool
    })
  }))
}

variable "repositories_to_create" {
  description = <<-EOT
    Optional list of repositories to create before applying configuration.
    If this list is not empty, these repositories will be created using `github_repository`.

    Each item must be an object with:
      - name: Name of the repository
      - description: Optional repository description
      - visibility: "public", "private" or "internal" (default: "private")
      - auto_init: Whether to create an initial commit with a README (default: false)
  EOT

  type = list(object({
    name        = string
    description = optional(string)
    visibility  = optional(string, "private")
    auto_init   = optional(bool, false)
  }))

  default = []
}


variable "repository_selection_mode" {
  description = <<EOT
Defines how to select which repositories to manage:
- "all": use all repositories in the org (default)
- "list": only use repositories listed in var.repositories
- "filter": only use repositories with names matching repository_filter_keyword
EOT
  type    = string
  default = "all"
}

variable "repositories" {
  description = "List of repository names to manage (used when mode is 'list')"
  type        = list(string)
  default     = []
}

variable "repository_filter_keyword" {
  description = "Keyword used to filter repository names (used when mode is 'filter')"
  type        = string
  default     = ""
}

variable "branches" {
  type        = list(string)
  description = "List of branches to create"
}

variable "default_branch" {
  type        = string
  description = "Default branch"
}

variable "protected_branches" {
  type        = list(string)
  description = "Branches to protect"
}

