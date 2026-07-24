# ============================================================
# setup-tfstate.ps1
# Creates the Azure storage account for Terraform remote state.
# Run this ONCE before any terraform init/apply.
#
# Prerequisites:
#   - Azure CLI installed and logged in (az login)
#   - Correct subscription selected
# ============================================================

param(
  [string]$SubscriptionId    = "",              # Leave blank to use current subscription
  [string]$ResourceGroupName = "rg-tfstate-aiml",
  [string]$Location          = "eastus",
  [string]$StorageAccount    = "staimllandingzone",  # Must be globally unique, max 24 chars
  [string]$ContainerName     = "tfstate",
  [string]$PrincipalId       = ""               # Object ID of the SP / Managed Identity that runs Terraform
)

$ErrorActionPreference = "Stop"

# ── Select subscription ──────────────────────────────────────
if ($SubscriptionId) {
  Write-Host "Setting subscription to $SubscriptionId..."
  az account set --subscription $SubscriptionId
}

$currentSub = az account show --query id -o tsv
Write-Host "Using subscription: $currentSub"

# ── Resource Group ───────────────────────────────────────────
Write-Host "Creating resource group '$ResourceGroupName' in '$Location'..."
az group create `
  --name $ResourceGroupName `
  --location $Location `
  --tags "purpose=terraform-state" "managed-by=github-actions" | Out-Null

# ── Storage Account ──────────────────────────────────────────
Write-Host "Creating storage account '$StorageAccount'..."
az storage account create `
  --name $StorageAccount `
  --resource-group $ResourceGroupName `
  --location $Location `
  --sku Standard_LRS `
  --kind StorageV2 `
  --min-tls-version TLS1_2 `
  --allow-blob-public-access false `
  --https-only true `
  --tags "purpose=terraform-state" "managed-by=github-actions" | Out-Null

# Enable versioning for state file recovery
Write-Host "Enabling blob versioning..."
az storage account blob-service-properties update `
  --account-name $StorageAccount `
  --resource-group $ResourceGroupName `
  --enable-versioning true | Out-Null

# ── State Container ──────────────────────────────────────────
Write-Host "Creating blob container '$ContainerName'..."
az storage container create `
  --name $ContainerName `
  --account-name $StorageAccount `
  --auth-mode login | Out-Null

# ── RBAC for Service Principal ───────────────────────────────
if ($PrincipalId) {
  Write-Host "Granting 'Storage Blob Data Contributor' to principal '$PrincipalId'..."
  $scope = "/subscriptions/$currentSub/resourceGroups/$ResourceGroupName/providers/Microsoft.Storage/storageAccounts/$StorageAccount"
  az role assignment create `
    --role "Storage Blob Data Contributor" `
    --assignee-object-id $PrincipalId `
    --assignee-principal-type ServicePrincipal `
    --scope $scope | Out-Null
} else {
  Write-Host "Skipping RBAC assignment (no -PrincipalId provided)."
  Write-Host "  Manually grant 'Storage Blob Data Contributor' to your GitHub Actions service principal."
}

# ── Output summary ───────────────────────────────────────────
Write-Host ""
Write-Host "============================================================"
Write-Host " Terraform State Storage Created"
Write-Host "============================================================"
Write-Host " Resource Group : $ResourceGroupName"
Write-Host " Storage Account: $StorageAccount"
Write-Host " Container      : $ContainerName"
Write-Host ""
Write-Host " Add these as GitHub repository secrets:"
Write-Host "   TF_STATE_RG              = $ResourceGroupName"
Write-Host "   TF_STATE_STORAGE_ACCOUNT = $StorageAccount"
Write-Host ""
Write-Host " Also add OIDC secrets:"
Write-Host "   AZURE_CLIENT_ID      = <service principal app id>"
Write-Host "   AZURE_TENANT_ID      = <tenant id>"
Write-Host "   AZURE_SUBSCRIPTION_ID = $currentSub"
Write-Host "============================================================"
