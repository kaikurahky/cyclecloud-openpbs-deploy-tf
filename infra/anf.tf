resource "azurerm_subnet" "anf" {
  count = var.enable_anf ? 1 : 0

  name                            = "subnet-anf"
  resource_group_name             = azurerm_resource_group.lab.name
  virtual_network_name            = azurerm_virtual_network.lab.name
  address_prefixes                = [var.anf_subnet_cidr]
  default_outbound_access_enabled = false

  delegation {
    name = "netapp"
    service_delegation {
      name = "Microsoft.Netapp/volumes"
      actions = [
        "Microsoft.Network/networkinterfaces/*",
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

resource "azurerm_netapp_account" "lab" {
  count = var.enable_anf ? 1 : 0

  name                = "anf-${var.name_prefix}"
  location            = var.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
}

resource "azurerm_netapp_pool" "lab" {
  count = var.enable_anf ? 1 : 0

  name                    = "flexible"
  location                = var.location
  resource_group_name     = azurerm_resource_group.lab.name
  account_name            = azurerm_netapp_account.lab[0].name
  service_level           = "Flexible"
  size_in_tb              = var.anf_pool_size_tb
  qos_type                = "Manual"
  custom_throughput_mibps = var.anf_throughput_mibps
  tags                    = local.tags
}

resource "azurerm_netapp_volume" "data" {
  count = var.enable_anf ? 1 : 0

  name                       = "pbs-data"
  location                   = var.location
  resource_group_name        = azurerm_resource_group.lab.name
  account_name               = azurerm_netapp_account.lab[0].name
  pool_name                  = azurerm_netapp_pool.lab[0].name
  volume_path                = "pbs-data"
  service_level              = "Flexible"
  subnet_id                  = azurerm_subnet.anf[0].id
  protocols                  = ["NFSv4.1"]
  security_style             = "unix"
  storage_quota_in_gb        = var.anf_volume_size_gib
  throughput_in_mibps        = var.anf_throughput_mibps
  network_features           = "Standard"
  snapshot_directory_visible = false
  tags                       = local.tags

  export_policy_rule {
    rule_index          = 1
    allowed_clients     = [var.cluster_subnet_cidr]
    protocol            = ["NFSv4.1"]
    root_access_enabled = true
    unix_read_only      = false
    unix_read_write     = true
  }
}