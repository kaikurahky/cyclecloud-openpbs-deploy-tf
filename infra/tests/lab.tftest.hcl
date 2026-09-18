mock_provider "azurerm" {}

variables {
  subscription_id         = "11111111-2222-3333-4444-555555555555"
  storage_account_name    = "testpbslocker123"
  management_source_cidrs = ["10.60.254.0/26"]
  ssh_public_key          = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCTestOnly"
}

run "private_lab_without_anf" {
  command = plan

  variables {
    enable_anf = false
  }

  assert {
    condition     = azurerm_storage_account.locker.public_network_access == "Disabled" && !azurerm_storage_account.locker.shared_access_key_enabled
    error_message = "Locker must remain private and use identity authentication."
  }

  assert {
    condition     = length(azurerm_netapp_volume.data) == 0 && output.anf_mount_ip == ""
    error_message = "ANF must not be created when disabled."
  }

  assert {
    condition     = azurerm_network_interface.cyclecloud.ip_configuration[0].public_ip_address_id == null
    error_message = "CycleCloud must not expose a public IP."
  }

  assert {
    condition     = azurerm_role_assignment.locker_reader.role_definition_name == "Storage Blob Data Reader"
    error_message = "Nodes only need read access to the Locker."
  }

  assert {
    condition     = output.cluster_subnet_cyclecloud == "rg-pbs-lab/vnet-pbs-lab/subnet-cluster"
    error_message = "CycleCloud requires the short subnet path."
  }
}

run "anf_enabled" {
  command = plan

  assert {
    condition     = length(azurerm_netapp_volume.data) == 1 && azurerm_netapp_volume.data[0].protocols == toset(["NFSv4.1"])
    error_message = "The default lab must provide an NFSv4.1 ANF volume."
  }

  assert {
    condition     = azurerm_netapp_volume.data[0].storage_quota_in_gb == 1024
    error_message = "The volume quota must be 1024 GiB, not bytes."
  }
}

run "reject_public_management" {
  command = plan

  variables {
    management_source_cidrs = ["0.0.0.0/0"]
  }

  expect_failures = [var.management_source_cidrs]
}