# terraform-github-configuration

📦 Terraform module to manage GitHub repositories, teams, branches, and protections dynamically across an organization.

---

## 🔧 Inputs

| Name                        | Description                                                                 | Type                                                                                       | Required |
|-----------------------------|-----------------------------------------------------------------------------|--------------------------------------------------------------------------------------------|----------|
| `github_token`              | GitHub access token with `admin:org`, `repo`, `read:org` scopes             | `string`                                                                                   | ✅ Yes   |
| `github_owner`              | GitHub organization name                                                    | `string`                                                                                   | ✅ Yes   |
| `company_name`              | Prefix for all created team names (e.g., `tecnologia-pnt`)                 | `string`                                                                                   | ✅ Yes   |
| `branches`                  | List of branches to create on each repository                               | `list(string)`                                                                             | ✅ Yes   |
| `default_branch`            | The default branch to set for all repositories                              | `string`                                                                                   | ✅ Yes   |
| `protected_branches`        | List of branches that must have protection rules applied                    | `list(string)`                                                                             | ✅ Yes   |
| `teams_structure`           | Map of team definitions and branch permissions                              | `map(object)` (with `slug`, `description`, `role_default`, `permissions`)                 | ✅ Yes   |
| `repository_selection_mode` | How to select repositories: `all`, `list`, or `filter`                      | `string` (`all` \| `list` \| `filter`)                                                     | ✅ Yes   |
| `repositories`              | List of repositories to use when `repository_selection_mode = "list"`       | `list(string)`                                                                             | ❌ No    |
| `repository_filter_keyword`| Keyword to filter repo names if `repository_selection_mode = "filter"`       | `string`                                                                                   | ❌ No    |

---

## 📤 Outputs

| Name                    | Description                                                |
|-------------------------|------------------------------------------------------------|
| `repository_names`      | List of all selected repository names                      |
| `github_teams`          | All created GitHub teams with metadata                    |
| `created_branches`      | Branches created per repository                           |
| `default_branches_set`  | Default branch set for each repository                    |
| `branch_protection_rules` | Protection rules configured for branches                  |
| `team_repo_permissions` | Team access granted to each repository                    |

---

## 🧠 Notes

- All teams are created with names prefixed by `company_name`, e.g., `tecnologia-pnt-Tech-Leads`.
- Teams receive access to all selected repositories using their `role_default`.
- The `teams_structure` object also defines which teams can:
  - Dismiss PR reviews (`review`)
  - Push to protected branches (`push`)
  - Bypass branch protection rules (`bypass`)
- You can select repositories using:
  - `"all"` – all repositories in the organization
  - `"list"` – a static list of repository names via `repositories`
  - `"filter"` – repositories whose names contain a keyword via `repository_filter_keyword`

---

## 🔐 Required Token Scopes

Your `github_token` must include the following GitHub scopes:

- `admin:org`
- `repo`
- `read:org`

---

## 🧪 Tested With

- Terraform `>= 1.3`
- GitHub Provider `>= 5.0`

---

## 🤝 Contributing

Feel free to open issues or pull requests at [github.com/yros-cloud](https://github.com/yros-cloud)

---

## 🧾 License

MIT License © [Yros Cloud](https://yros.cloud)
