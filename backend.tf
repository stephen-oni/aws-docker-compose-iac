terraform {
  cloud {
    # The name of your organization in Terraform Cloud
    organization = "your-organization-name"

    workspaces {
      # The name of the workspace where this state will live
      name = "your-workspace-name"
    }
  }
}

