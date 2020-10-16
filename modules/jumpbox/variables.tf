variable resource_group {
  type = string
}

variable location {
  type = string
}

variable vnet_id {
  description = "ID of the VNET where jumpbox VM will be installed"
  type        = string
}

variable subnet_id {
  description = "ID of subnet where jumpbox VM will be installed"
  type        = string
}

variable dns_zone_name {
  description = "Private DNS Zone name to link jumpbox's vnet to"
  type        = string
}

variable dns_zone_resource_group {
  description = "Private DNS Zone resource group"
  type        = string
}


variable vm_user {
  description = "Jumpbox VM user name"
  type        = string
  default     = "azureuser"
}

variable public_key{
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC/0nrSYw5v41FAd/I3NUoZ61vJtf5X9Y+RZeWBQDg+V+vO/z+YE9knJ9pGxh4nkRHAFHrxKJY2BRngRJ0NdSRwR3/d7Se9tEhatOQSyWrR9+5g8WZMZD0NmUmFewsCdzYSMiCVDmXpcEZ88uFx+2hufeHN27CbcrG777xlyECXe9tlUmgvsE26Y8zfJbxy3XsXBDQcWQR9SsvavUUjwOT/29rCtqdIBwjqDsgNZTQQR6rU6VWj5RpxsajJyWmoWMOjpDRdsXVtqktyjigo5EhHMP56bYFyiKeloU6KXFpCx79+AxhtiIJaEdrSU4DjAx28oAoeNP0++j5QI2V1rFlp itay@corona-station"
}