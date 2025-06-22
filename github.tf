# GitHub provider configuration
provider "github" {
  token = var.github_token         # GitHub token with proper scopes
  owner = var.github_owner         # GitHub organization name
}

# Fetch all repositories from the GitHub organization
data "github_repositories" "all" {
  query = "org:${var.github_owner}"
}

# Dynamic repository selection logic
locals {
  selected_repositories = (
    var.repository_selection_mode == "all" ? data.github_repositories.all.names :
    var.repository_selection_mode == "list" ? var.repositories :
    var.repository_selection_mode == "filter" ? [
      for name in data.github_repositories.all.names : name
      if contains(name, var.repository_filter_keyword)
    ] : []
  )

  repo_map = { for repo in local.selected_repositories : repo => repo }

  branch_matrix = {
    for repo in local.selected_repositories :
    repo => [
      for branch in var.branches : {
        repo   = repo
        branch = branch
      }
    ]
  }

  flat_branch_matrix = flatten([for pairs in local.branch_matrix : pairs])

  branch_map = {
    for item in local.flat_branch_matrix : "${item.repo}-${item.branch}" => item
  }

  protected_branch_map = {
    for item in local.flat_branch_matrix :
    "${item.repo}-${item.branch}" => item
    if contains(var.protected_branches, item.branch)
  }

  reviewers = [
    for t in values(var.teams_structure) :
    t.slug if t.permissions.review
  ]

  pushers = [
    for t in values(var.teams_structure) :
    t.slug if t.permissions.push
  ]

  bypassers = [
    for t in values(var.teams_structure) :
    t.slug if t.permissions.bypass
  ]
}


# Create GitHub teams based on the input structure
resource "github_team" "teams" {
  for_each = var.teams_structure

  name        = "${var.company_name}-${each.value.slug}" # Prefixed team name
  description = each.value.description
  privacy     = "closed" # Team is private (not visible to non-members)
}

# Grant each team access to every repository based on role_default
resource "github_team_repository" "team_repo_access" {
  for_each = {
    for pair in setproduct(keys(var.teams_structure), local.selected_repositories) :
    "${pair[0]}::${pair[1]}" => {
      team_key    = pair[0]
      repository  = pair[1]
      slug        = var.teams_structure[pair[0]].slug
      permission  = var.teams_structure[pair[0]].role_default
    }
  }

  team_id    = github_team.teams[each.value.team_key].id
  repository = each.value.repository
  permission = each.value.permission
}

# Create branches (e.g., main, staging, develop) per repository
resource "github_branch" "branches" {
  for_each   = local.branch_map
  repository = each.value.repo
  branch     = each.value.branch
}

# Set default branch per repository (e.g., "main" or "develop")
resource "github_branch_default" "default" {
  for_each   = local.repo_map
  repository = each.value
  branch     = var.default_branch

  # Ensure branches are created before setting default
  depends_on = [github_branch.branches]
}

# Map slugs to team keys to resolve references later
locals {
  slug_to_team_key = {
    for team_key, team_data in var.teams_structure :
    team_data.slug => team_key
  }
}

# Apply branch protection rules for defined protected branches
resource "github_branch_protection" "protected" {
  for_each = local.protected_branch_map

  repository_id       = each.value.repo
  pattern             = each.value.branch
  enforce_admins      = false
  allows_deletions    = true
  allows_force_pushes = false

  # Pull request review rules
  required_pull_request_reviews {
    dismiss_stale_reviews  = true
    restrict_dismissals    = true

    # Teams allowed to dismiss reviews
    dismissal_restrictions = [
      for slug in local.reviewers :
      github_team.teams[local.slug_to_team_key[slug]].node_id
    ]
  }

  # Teams allowed to push to the protected branch
  restrict_pushes {
    push_allowances = [
      for slug in local.pushers :
      github_team.teams[local.slug_to_team_key[slug]].node_id
    ]
  }

  # Teams allowed to bypass branch protection rules
  force_push_bypassers = [
    for slug in local.bypassers :
    github_team.teams[local.slug_to_team_key[slug]].node_id
  ]

  # Prevent Terraform from recreating resource on minor permission changes
  lifecycle {
    ignore_changes = [
      force_push_bypassers,
      restrict_pushes,
      required_pull_request_reviews
    ]
  }
}

# OUTPUTS

# Output: list of repository names discovered in the organization
output "repository_names" {
  description = "List of all repository names found"
  value       = local.selected_repositories
}

# Output: all created GitHub teams and their metadata
output "github_teams" {
  description = "All created GitHub teams with name and ID"
  value = {
    for k, team in github_team.teams : k => {
      id           = team.id
      name         = team.name
      node_id      = team.node_id
      slug         = var.teams_structure[k].slug
      description  = var.teams_structure[k].description
      role_default = var.teams_structure[k].role_default
    }
  }
}

# Output: all branches created per repository
output "created_branches" {
  description = "Branches created per repository"
  value = {
    for k, branch in github_branch.branches : k => {
      repo   = branch.repository
      branch = branch.branch
    }
  }
}

# Output: default branch set for each repository
output "default_branches_set" {
  description = "Default branch configured per repository"
  value = {
    for k, def in github_branch_default.default : k => {
      repository = def.repository
      branch     = def.branch
    }
  }
}

# Output: protection rules configured for each branch
output "branch_protection_rules" {
  description = "Branch protection applied per repository"
  value = {
    for k, bp in github_branch_protection.protected : k => {
      repository = bp.repository_id
      pattern    = bp.pattern
      id         = bp.id
    }
  }
}

# Output: permissions granted to each team per repository
output "team_repo_permissions" {
  description = "Team permissions assigned to each repository"
  value = try({
    for k, tr in github_team_repository.team_repo_access : k => {
      team_id    = tr.team_id
      repository = tr.repository
      permission = tr.permission
    }
  }, {})
}
