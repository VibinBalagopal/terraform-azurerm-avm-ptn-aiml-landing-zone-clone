terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-aiml"
    storage_account_name = "staimljshgfa"
    container_name       = "tfstate"
    key                  = "aiml-landing-zone.tfstate"
    use_azuread_auth     = true
  }
}
