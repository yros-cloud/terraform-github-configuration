# ─── GitHub Provider ────────────────────────────────────────────────────────────
provider "github" {
  token = var.github_token         # GitHub token with proper scopes
  owner = var.github_owner         # GitHub organization name
}

# ─── Optional Repository Creation ───────────────────────────────────────────────
resource "github_repository" "repos" {
  for_each = { for r in var.repositories_to_create : r.name => r }

  name        = each.value.name
  description = each.value.description
  visibility  = each.value.visibility
  auto_init   = true
}

# ─── Data Source: Existing GitHub Repositories ──────────────────────────────────
data "github_repositories" "all" {
  count = length(var.repositories_to_create) > 0 ? 0 : 1
  query = "org:${var.github_owner}"
}

# this local is used to determine the visibility of repositories
# based on the repositories created by this module and the existing ones
locals {
  repo_visibility_map = merge(
    {
      for repo in local.selected_repositories :
      repo => "private"
    },
    {
      for repo, conf in github_repository.repos :
      repo => conf.visibility
    }
  )
}


# ─── Dynamic Repository Selection Logic ─────────────────────────────────────────
locals {
  selected_repositories = (
    var.repository_selection_mode == "all" ? (
      length(var.repositories_to_create) > 0
        ? keys(github_repository.repos)
        : data.github_repositories.all[0].names
    ) :
    var.repository_selection_mode == "list" ? distinct(concat(
      var.repositories,
      [for r in github_repository.repos : r.name]
    )) :
    var.repository_selection_mode == "filter" ? distinct(concat(
      [for name in data.github_repositories.all[0].names : name if contains(name, var.repository_filter_keyword)],
      [for r in github_repository.repos : r.name if contains(r.name, var.repository_filter_keyword)]
    )) : []
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

  slug_to_team_key = {
    for team_key, team_data in var.teams_structure :
    team_data.slug => team_key
  }
}

# ─── GitHub Teams ───────────────────────────────────────────────────────────────
resource "github_team" "teams" {
  for_each = var.teams_structure

  name        = "${var.company_name}-${each.value.slug}"
  description = each.value.description
  privacy     = "closed"
}

# ─── Team Access to Repositories ────────────────────────────────────────────────
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

# ─── Branch Creation ────────────────────────────────────────────────────────────
resource "github_branch" "branches" {
  for_each   = local.branch_map
  repository = each.value.repo
  branch     = each.value.branch

  lifecycle {
    prevent_destroy = true # Prevents accidental deletion of important branches
  }
}

# ─── Default Branch ─────────────────────────────────────────────────────────────
resource "github_branch_default" "default" {
  for_each   = local.repo_map
  repository = each.value
  branch     = var.default_branch

  depends_on = [github_branch.branches]
}

# ─── Branch Protection ──────────────────────────────────────────────────────────
resource "github_branch_protection" "protected" {
  for_each = {
    for k, v in local.protected_branch_map :
    k => v
    if (
      var.enable_advanced_protection ||
      try(local.repo_visibility_map[v.repo], "private") == "public"
    )
  }

  repository_id       = each.value.repo
  pattern             = each.value.branch
  enforce_admins      = false
  allows_deletions    = true
  allows_force_pushes = false

  required_pull_request_reviews {
    dismiss_stale_reviews = true
    restrict_dismissals   = var.enable_advanced_protection

    dismissal_restrictions = var.enable_advanced_protection ? [
      for slug in local.reviewers :
      github_team.teams[local.slug_to_team_key[slug]].node_id
    ] : null
  }

  restrict_pushes {
    push_allowances = var.enable_advanced_protection ? [
      for slug in local.pushers :
      github_team.teams[local.slug_to_team_key[slug]].node_id
    ] : null
  }

  force_push_bypassers = var.enable_advanced_protection ? [
    for slug in local.bypassers :
    github_team.teams[local.slug_to_team_key[slug]].node_id
  ] : null

  lifecycle {
    ignore_changes = [
      force_push_bypassers,
      restrict_pushes,
      required_pull_request_reviews
    ]
  }
}



# ─── Outputs ────────────────────────────────────────────────────────────────────
output "repository_names" {
  description = "List of all repository names handled by this module"
  value       = local.selected_repositories
}

output "github_teams" {
  description = "All created GitHub teams with their details"
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

output "created_branches" {
  description = "Branches created per repository"
  value = {
    for k, branch in github_branch.branches : k => {
      repo   = branch.repository
      branch = branch.branch
    }
  }
}

output "default_branches_set" {
  description = "Default branch configured per repository"
  value = {
    for k, def in github_branch_default.default : k => {
      repository = def.repository
      branch     = def.branch
    }
  }
}

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
