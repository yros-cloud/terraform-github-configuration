module "github_org_configuration" {
  source = "yros-cloud/github-configuration/github"

  github_token = var.github_token
  github_owner = var.github_owner
  company_name = "yros-cloud"

  repositories_to_create = [
    {
      name        = "example"
      description = "Example repo"
      visibility  = "private" # or "public" or "internal"
    }
  ]
  branches        = ["main", "develop"]
  default_branch  = "main"
  protected_branches = ["main"]
  enable_advanced_protection = false # Set to true to enable advanced branch protection rules (Github Pro only or Public repositories)
  repository_selection_mode  = "all" # or "list" or "filter"
  repositories               = []    # optional if using "all"
  repository_filter_keyword  = ""    # optional if using "filter"

  teams_structure = {
    tech_leads = {
      slug         = "Tech-Leads"
      description  = "Tech Leads team"
      role_default = "maintain"
      permissions = {
        review = true
        push   = true
        bypass = true
      }
    }
    admins = {
      slug         = "Admins"
      description  = "Platform administrators"
      role_default = "admin"
      permissions = {
        review = true
        push   = true
        bypass = true
      }
    }
    devops = {
      slug         = "DevOps"
      description  = "DevOps engineers"
      role_default = "push"
      permissions = {
        review = false
        push   = false
        bypass = false
      }
    }
    developers = {
      slug         = "Developers"
      description  = "Application developers"
      role_default = "pull"
      permissions = {
        review = false
        push   = false
        bypass = false
      }
    }
  }
}
