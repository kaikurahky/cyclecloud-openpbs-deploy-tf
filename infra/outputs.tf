output "resource_group_name" {
  description = "Terraform-owned infrastructure resource group."
  value       = azurerm_resource_group.lab.name
}

output "cyclecloud_vm_name" {
  description = "CycleCloud management VM name."
  value       = "${var.name_prefix}-cc"
}

output "cyclecloud_vm_id" {
  description = "VM resource ID for Bastion tunnels."
  value       = "${azurerm_resource_group.lab.id}/providers/Microsoft.Compute/virtualMachines/${var.name_prefix}-cc"
}

output "cyclecloud_private_ip" {
  description = "Private IP; requires your own private access path."
  value       = azurerm_network_interface.cyclecloud.private_ip_address
}

output "cyclecloud_portal_url" {
  description = "Private CycleCloud management URL."
  value       = "https://${azurerm_network_interface.cyclecloud.private_ip_address}:9443"
}

output "managed_identity_client_id" {
  description = "Client ID for CycleCloud's Azure orchestration credentials."
  value       = azurerm_user_assigned_identity.orchestrator.client_id
}

output "locker_identity_id" {
  description = "Read-only identity for Storage Locker and cluster nodes."
  value       = azurerm_user_assigned_identity.locker.id
}

output "storage_account_name" {
  description = "Private Blob account used by the CycleCloud Locker."
  value       = azurerm_storage_account.locker.name
}

output "cluster_subnet_id" {
  description = "ARM subnet ID."
  value       = azurerm_subnet.lab["cluster"].id
}

output "cluster_subnet_cyclecloud" {
  description = "CycleCloud SubnetId parameter (not an ARM resource ID)."
  value       = "${azurerm_resource_group.lab.name}/${azurerm_virtual_network.lab.name}/${azurerm_subnet.lab["cluster"].name}"
}

output "anf_mount_ip" {
  description = "Optional ANF NFS mount target."
  value       = var.enable_anf ? azurerm_netapp_volume.data[0].mount_target[0].ip_address : ""
}

output "anf_export_path" {
  description = "Optional ANF exported path; mount at /data on PBS nodes."
  value       = var.enable_anf ? "/${azurerm_netapp_volume.data[0].volume_path}" : ""
}