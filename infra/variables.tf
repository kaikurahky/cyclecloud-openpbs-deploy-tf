variable "subscription_id" {
  type        = string
  description = "Azure subscription used for this isolated lab."

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.subscription_id)) && var.subscription_id != "00000000-0000-0000-0000-000000000000"
    error_message = "Set a real subscription UUID."
  }
}

variable "location" {
  type        = string
  description = "Azure region with the selected VM sizes and ANF service level."
  default     = "japaneast"
}

variable "name_prefix" {
  type        = string
  description = "Unique prefix for resources in this new lab."
  default     = "pbs-lab"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,19}$", var.name_prefix))
    error_message = "Use 3-20 lowercase letters, digits or hyphens, beginning with a letter."
  }
}

variable "storage_account_name" {
  type        = string
  description = "Globally unique locker storage account name."

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "Use 3-24 lowercase letters and digits."
  }
}

variable "vnet_cidr" {
  type        = string
  description = "Non-overlapping VNet IPv4 CIDR."
  default     = "10.60.0.0/16"
}

variable "management_subnet_cidr" {
  type        = string
  description = "Management subnet IPv4 CIDR within the VNet."
  default     = "10.60.0.0/24"
}

variable "cluster_subnet_cidr" {
  type        = string
  description = "OpenPBS subnet IPv4 CIDR within the VNet."
  default     = "10.60.1.0/24"
}

variable "anf_subnet_cidr" {
  type        = string
  description = "Dedicated ANF subnet IPv4 CIDR within the VNet."
  default     = "10.60.50.0/24"
}

variable "management_source_cidrs" {
  type        = list(string)
  description = "Private client or Bastion subnet CIDRs allowed to reach SSH and CycleCloud HTTPS."

  validation {
    condition     = length(var.management_source_cidrs) > 0 && alltrue([for cidr in var.management_source_cidrs : can(cidrnetmask(cidr)) && cidr != "0.0.0.0/0"])
    error_message = "Provide specific IPv4 CIDRs; 0.0.0.0/0 is not allowed."
  }
}

variable "cyclecloud_image_urn" {
  type        = string
  description = "Marketplace image URN. Pin a version after checking it in your region."
  default     = "azurecyclecloud:azure-cyclecloud:cyclecloud8-gen2:latest"

  validation {
    condition     = can(regex("^azurecyclecloud:azure-cyclecloud:cyclecloud8-gen2:[^:]+$", var.cyclecloud_image_urn))
    error_message = "Use a CycleCloud 8 Gen2 Marketplace URN."
  }
}

variable "cyclecloud_vm_size" {
  type        = string
  description = "CycleCloud management VM size."
  default     = "Standard_D4as_v5"
}

variable "admin_username" {
  type        = string
  description = "Linux VM administrator, independent of the CycleCloud web account."
  default     = "azureuser"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key only. Never supply a private key."

  validation {
    condition     = can(regex("^ssh-(rsa|ed25519) [A-Za-z0-9+/=]+", trimspace(var.ssh_public_key)))
    error_message = "Supply an RSA or Ed25519 SSH public key."
  }
}

variable "image_data_disk_luns" {
  type        = list(number)
  description = "Data disk LUNs from az vm image show; preserve every disk in the Marketplace image."
  default     = [0]

  validation {
    condition     = alltrue([for lun in var.image_data_disk_luns : lun >= 0 && lun <= 63 && floor(lun) == lun]) && length(distinct(var.image_data_disk_luns)) == length(var.image_data_disk_luns)
    error_message = "Use unique integer LUNs from 0 to 63."
  }
}

variable "enable_anf" {
  type        = bool
  description = "Create an ANF Flexible pool and NFSv4.1 data volume; otherwise use built-in NFS only."
  default     = true
}

variable "anf_pool_size_tb" {
  type        = number
  description = "ANF Flexible pool capacity in TiB."
  default     = 1

  validation {
    condition     = var.anf_pool_size_tb >= 1 && floor(var.anf_pool_size_tb) == var.anf_pool_size_tb
    error_message = "Pool capacity must be a positive whole number of TiB."
  }
}

variable "anf_volume_size_gib" {
  type        = number
  description = "ANF volume capacity in GiB, not bytes."
  default     = 1024

  validation {
    condition     = var.anf_volume_size_gib >= 50 && var.anf_volume_size_gib <= var.anf_pool_size_tb * 1024
    error_message = "Volume capacity must be at least 50 GiB and fit within the pool."
  }
}

variable "anf_throughput_mibps" {
  type        = number
  description = "Flexible pool and volume throughput in MiB/s."
  default     = 128

  validation {
    condition     = var.anf_throughput_mibps >= 128
    error_message = "Flexible pool throughput must be at least 128 MiB/s."
  }
}

variable "tags" {
  type        = map(string)
  description = "Additional resource tags."
  default     = {}
}