variable "todoapp_aks" {
    type = map(object({
    name                = string
    resource_group_name = string
    location            = string
    dns_prefix          = string
    tags                = map(string)
    node_count = number
    vm_size = string
    api_server_authorized_ip_ranges = optional(list(string), [])
  }))
}
