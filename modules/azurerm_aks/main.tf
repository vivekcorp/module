resource "azurerm_kubernetes_cluster" "todoapp_aks" {
  for_each = var.todoapp_aks
  name                = each.value.name
  location            = each.value.location
  resource_group_name = data.azurerm_resource_group.Datablockrg[each.key].name
  dns_prefix          = each.value.dns_prefix


  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = each.value.vm_size
  }

  identity {
    type = "SystemAssigned"
  }
  api_server_access_profile {
    authorized_ip_ranges = each.value.api_server_authorized_ip_ranges
  }
  tags = {
    Environment = "Production"
  }
}
