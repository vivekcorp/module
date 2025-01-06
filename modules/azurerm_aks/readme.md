# Azure AKS Module

This Terraform module deploys an Azure Kubernetes Service (AKS) cluster.

## Usage

```hcl
module "aks" {
  source              = "github.com/vivekcorp/modules/azurerm_aks"
  cluster_name        = "my-aks-cluster"
  location            = "eastus"
  resource_group_name = "my-resource-group"
  node_count          = 3
  vm_size             = "Standard_DS2_v2"
  tags = {
    environment = "dev"
    project     = "example"
  }
}


