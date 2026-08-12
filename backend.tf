terraform {
  cloud {
    organization = "YOUR_ORGANIZATION_NAME"

    workspaces {
      name = "pulse-dev-workspace"
    }
  }
}