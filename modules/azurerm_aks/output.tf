output "aks_cluster_names" {
  description = "Names of the AKS clusters created"
  value       = [for cluster in azurerm_kubernetes_cluster.todoapp_aks : cluster.name]
}

output "aks_kubeconfigs" {
  description = "Kubeconfigs for the AKS clusters"
  value       = {
    for key, cluster in azurerm_kubernetes_cluster.todoapp_aks :
    key => cluster.kube_config_raw
  }
  sensitive = true
}

output "aks_fqdns" {
  description = "FQDNs (API server endpoints) of the AKS clusters"
  value       = [for cluster in azurerm_kubernetes_cluster.todoapp_aks : cluster.fqdn]
}
