variable "location" {
  description = "Azure region to deploy the resources"
  type        = string
  default     = "West Europe"
}

variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
  default     = "Thomas-Mou"
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}