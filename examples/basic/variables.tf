variable "github_token" {
  description = "GitHub personal access token with required scopes"
  type        = string
  sensitive   = true
}

variable "github_owner" {
  description = "GitHub organization name"
  type        = string
}
