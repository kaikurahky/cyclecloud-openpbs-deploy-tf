locals {
  image_parts = split(":", var.cyclecloud_image_urn)
  tags        = merge({ workload = "cyclecloud-openpbs", managed_by = "terraform" }, var.tags)
  subnets = {
    management = var.management_subnet_cidr
    cluster    = var.cluster_subnet_cidr
  }
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-${var.name_prefix}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_user_assigned_identity" "orchestrator" {
  name                = "id-${var.name_prefix}-cyclecloud"
  location            = var.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
}

resource "azurerm_user_assigned_identity" "locker" {
  name                = "id-${var.name_prefix}-locker"
  location            = var.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
}

resource "azurerm_role_assignment" "orchestration" {
  scope                            = "/subscriptions/${var.subscription_id}"
  role_definition_name             = "Contributor"
  principal_id                     = azurerm_user_assigned_identity.orchestrator.principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "locker_writer" {
  scope                            = azurerm_storage_account.locker.id
  role_definition_name             = "Storage Blob Data Contributor"
  principal_id                     = azurerm_user_assigned_identity.orchestrator.principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "locker_reader" {
  scope                            = azurerm_storage_account.locker.id
  role_definition_name             = "Storage Blob Data Reader"
  principal_id                     = azurerm_user_assigned_identity.locker.principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_virtual_network" "lab" {
  name                = "vnet-${var.name_prefix}"
  location            = var.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = [var.vnet_cidr]
  tags                = local.tags
}

resource "azurerm_subnet" "lab" {
  for_each = local.subnets

  name                              = "subnet-${each.key}"
  resource_group_name               = azurerm_resource_group.lab.name
  virtual_network_name              = azurerm_virtual_network.lab.name
  address_prefixes                  = [each.value]
  default_outbound_access_enabled   = false
  private_endpoint_network_policies = "Disabled"
}

resource "azurerm_network_security_group" "lab" {
  for_each = local.subnets

  name                = "nsg-${var.name_prefix}-${each.key}"
  location            = var.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
}

resource "azurerm_network_security_rule" "management" {
  name                        = "allow-private-management"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["22", "9443"]
  source_address_prefixes     = var.management_source_cidrs
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.lab.name
  network_security_group_name = azurerm_network_security_group.lab["management"].name
}

resource "azurerm_subnet_network_security_group_association" "lab" {
  for_each = local.subnets

  subnet_id                 = azurerm_subnet.lab[each.key].id
  network_security_group_id = azurerm_network_security_group.lab[each.key].id
}

resource "azurerm_public_ip" "nat" {
  name                = "pip-${var.name_prefix}-nat"
  location            = var.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_nat_gateway" "lab" {
  name                    = "nat-${var.name_prefix}"
  location                = var.location
  resource_group_name     = azurerm_resource_group.lab.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  tags                    = local.tags
}

resource "azurerm_nat_gateway_public_ip_association" "lab" {
  nat_gateway_id       = azurerm_nat_gateway.lab.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "lab" {
  for_each = local.subnets

  subnet_id      = azurerm_subnet.lab[each.key].id
  nat_gateway_id = azurerm_nat_gateway.lab.id
}

resource "azurerm_storage_account" "locker" {
  name                              = var.storage_account_name
  resource_group_name               = azurerm_resource_group.lab.name
  location                          = var.location
  account_tier                      = "Standard"
  account_replication_type          = "LRS"
  account_kind                      = "StorageV2"
  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  public_network_access             = "Disabled"
  allow_nested_items_to_be_public   = false
  shared_access_key_enabled         = false
  default_to_oauth_authentication   = true
  infrastructure_encryption_enabled = true
  local_user_enabled                = false
  tags                              = local.tags
}

resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                 = "link-${var.name_prefix}"
  private_dns_zone_id  = azurerm_private_dns_zone.blob.id
  virtual_network_id   = azurerm_virtual_network.lab.id
  registration_enabled = false
  tags                 = local.tags
}

resource "azurerm_private_endpoint" "blob" {
  name                = "pe-${var.name_prefix}-blob"
  location            = var.location
  resource_group_name = azurerm_resource_group.lab.name
  subnet_id           = azurerm_subnet.lab["management"].id
  tags                = local.tags

  private_service_connection {
    name                           = "locker-blob"
    private_connection_resource_id = azurerm_storage_account.locker.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "blob"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }
}

resource "azurerm_network_interface" "cyclecloud" {
  name                = "nic-${var.name_prefix}-cc"
  location            = var.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.lab["management"].id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(var.management_subnet_cidr, 10)
  }
}

resource "azurerm_resource_group_template_deployment" "cyclecloud" {
  name                = "cyclecloud-vm"
  resource_group_name = azurerm_resource_group.lab.name
  deployment_mode     = "Incremental"

  template_content = jsonencode({
    "$schema"      = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
    contentVersion = "1.0.0.0"
    resources = [{
      type       = "Microsoft.Compute/virtualMachines"
      apiVersion = "2025-04-01"
      name       = "${var.name_prefix}-cc"
      location   = var.location
      tags       = local.tags
      plan = {
        publisher = local.image_parts[0]
        product   = local.image_parts[1]
        name      = local.image_parts[2]
      }
      identity = {
        type = "UserAssigned"
        userAssignedIdentities = {
          (azurerm_user_assigned_identity.orchestrator.id) = {}
        }
      }
      properties = {
        hardwareProfile = { vmSize = var.cyclecloud_vm_size }
        storageProfile = {
          imageReference = {
            publisher = local.image_parts[0]
            offer     = local.image_parts[1]
            sku       = local.image_parts[2]
            version   = local.image_parts[3]
          }
          osDisk = {
            name         = "${var.name_prefix}-cc-os"
            createOption = "FromImage"
            deleteOption = "Delete"
            caching      = "ReadWrite"
            diskSizeGB   = 128
            managedDisk  = { storageAccountType = "Premium_LRS" }
          }
          dataDisks = [for lun in var.image_data_disk_luns : {
            name         = "${var.name_prefix}-cc-data${lun}"
            lun          = lun
            createOption = "FromImage"
            deleteOption = "Delete"
            caching      = "ReadWrite"
            managedDisk  = { storageAccountType = "Premium_LRS" }
          }]
        }
        networkProfile = {
          networkInterfaces = [{ id = azurerm_network_interface.cyclecloud.id }]
        }
        osProfile = {
          computerName  = "${var.name_prefix}-cc"
          adminUsername = var.admin_username
          linuxConfiguration = {
            disablePasswordAuthentication = true
            ssh = {
              publicKeys = [{
                path    = "/home/${var.admin_username}/.ssh/authorized_keys"
                keyData = trimspace(var.ssh_public_key)
              }]
            }
          }
        }
      }
    }]
  })

  depends_on = [
    azurerm_subnet_network_security_group_association.lab,
    azurerm_subnet_nat_gateway_association.lab,
    azurerm_nat_gateway_public_ip_association.lab,
    azurerm_role_assignment.orchestration,
    azurerm_role_assignment.locker_writer,
  ]
}