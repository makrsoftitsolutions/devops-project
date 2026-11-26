output "id" { value = azurerm_kubernetes_cluster.this.id }
output "name" { value = azurerm_kubernetes_cluster.this.name }
output "kubelet_identity_object_id" { value = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id }
output "user_node_pool_name" {
  value = var.enable_user_node_pool ? azurerm_kubernetes_cluster_node_pool.user[0].name : null
}
