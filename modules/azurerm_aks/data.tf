data "azurerm_resource_group" "Datablockrg" {
  for_each = var.todoapp_aks
  name = each.value.resource_group_name
}