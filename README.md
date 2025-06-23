# Terraform GitHub Repository & Team Automation Module

This module automates the creation and configuration of GitHub repositories, teams, default branches, branch protections, and repository access.

## 📦 Features
- Automatically creates repositories if a list is provided.
- Dynamically creates branches and sets default branches.
- Applies branch protection rules based on team permissions.
- Creates GitHub teams and assigns access to repositories.
- Supports dynamic repo selection (all, list, or filter).

---

## 🔧 Inputs

| Name                       | Description                                                                                         | Type                                                                                             | Required |
|----------------------------|-----------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------|----------|
| `github_token`            | GitHub access token with `admin:org`, `repo`, `read:org` scopes                                     | `string`                                                                                          | ✅ Yes   |
| `github_owner`            | GitHub organization name                                                                             | `string`                                                                                          | ✅ Yes   |
| `company_name`            | Prefix for team names (e.g. `yros`)                                                       | `string`                                                                                          | ✅ Yes   |
| `repository_selection_mode` | One of `all`, `list`, or `filter` – determines how repos are selected for management              | `string`                                                                                          | ✅ Yes   |
| `repositories`            | List of repositories to manage (only required if `repository_selection_mode = "list"`)           | `list(string)`                                                                                    | ❌ No    |
| `repository_filter_keyword` | Substring filter used to match repos (only for `repository_selection_mode = "filter"`)           | `string`                                                                                          | ❌ No    |
| `repositories_to_create`  | Optional list of repositories to be created before applying configuration                          | `list(object)` (see below)                                                                        | ❌ No    |
| `branches`                | List of branches to create per repository                                                           | `list(string)`                                                                                    | ✅ Yes   |
| `default_branch`          | Name of the default branch to set                                                                  | `string`                                                                                          | ✅ Yes   |
| `protected_branches`      | Branch names that should be protected                                                               | `list(string)`                                                                                    | ✅ Yes   |
| `teams_structure`         | Map of teams with structure `{ slug, description, role_default, permissions: {review, push, bypass} }` | `map(object)`    
| `enable_advanced_protection` | Whether to enable strict branch protection even for private repos Github Pro                              | `bool`                                                                                            | ❌ No    |                                                                                 | ✅ Yes   |

### Example `repositories_to_create`:
```hcl
repositories_to_create = [
  {
    name        = "infra-core"
    description = "Infrastructure core repo"
    visibility  = "private"
    auto_init   = true
  },
  {
    name        = "app-backend"
    description = "Backend application"
    visibility  = "internal"
    auto_init   = false
  }
]
```

---

## 📤 Outputs

| Name                    | Description                                      |
|-------------------------|--------------------------------------------------|
| `repository_names`      | List of all repository names used               |
| `github_teams`          | All created GitHub teams with name and metadata |
| `created_branches`      | Branches created per repository                 |
| `default_branches_set`  | Default branch configured per repository        |
| `branch_protection_rules` | Protection applied per branch                  |
| `team_repo_permissions` | Permissions assigned per team/repository        |

---

## 🧠 Notes
- All teams are created with names prefixed by `company_name`, e.g., `tecnologia-pnt-Tech-Leads`.
- Teams receive access to **all selected repositories** based on their `role_default`.
- Protected branches use the `permissions` map from `teams_structure` to apply restrictions.
- Repository creation (via `repositories_to_create`) occurs before any configurations.

---

## 🔐 Required Token Permissions
Ensure your `github_token` includes:
- `admin:org`
- `repo`
- `read:org`

---

## 🧪 Tested With
- Terraform >= 1.3
- GitHub Provider >= 5.0

---

## 🤝 Contributing
Contributions welcome via PRs or issues:
👉 https://github.com/yros-cloud/terraform-github-configuration

---

## 🧾 License
MIT License © [Yros Cloud](https://github.com/yros-cloud)


---

## 💡 Example Usage

```hcl
module "github_setup" {
  source = "yros-cloud/github-configuration/aws"

  github_token  = var.github_token
  github_owner  = "my-org"
  company_name  = "tecnologia-pnt"

  repository_selection_mode = "list"
  repositories = ["app-backend", "app-frontend"]

  repositories_to_create = [
    {
      name        = "app-backend"
      description = "Backend repo"
      visibility  = "private"
      auto_init   = true
    },
    {
      name        = "app-frontend"
      description = "Frontend repo"
      visibility  = "private"
      auto_init   = true
    }
  ]

  branches = ["main", "develop"]
  default_branch = "main"
  protected_branches = ["main"]

  teams_structure = {
    tech_leads = {
      slug         = "tech-leads"
      description  = "Tech Leads team"
      role_default = "maintain"
      permissions = {
        review = true
        push   = true
        bypass = true
      }
    },
    devs = {
      slug         = "developers"
      description  = "Development team"
      role_default = "push"
      permissions = {
        review = false
        push   = false
        bypass = false
      }
    }
  }
}
```
