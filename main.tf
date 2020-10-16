provider "azurerm" {
  # The "feature" block is required for AzureRM provider 2.x. 
  # If you are using version 1.x, the "features" block is not allowed.
  version = ">=2.13.0"
  features {}
  
  skip_provider_registration = true
}


#######-----------Declaring Data for the process -----------------------------------------#

# resource "azurerm_resource_group" "rg" {
#     name     = var.resource_group_name
#     location = var.location
# }
##Hub Network for Jumpbox
module "hub_network" {
  source              = "./modules/aks_network"
  resource_group_name = var.resource_group_name
  location            = var.location
  vnet_name           = "HubNetwork"
  address_space       = ["10.0.0.0/22"]
  subnets = [
    {
      name : "AzureFirewallSubnet"
      address_prefixes : ["10.0.1.0/24"]
    },
    {
      name : "jumpbox-subnet"
      address_prefixes : ["10.0.2.0/24"]
    }
  ]
}

module "aks_network" {
  source              = "./modules/aks_network"
  resource_group_name = var.resource_group_name
  location            = var.location
  vnet_name           = var.aks_vnet_name
  address_space       = var.aks_address_space
  subnets = [
    {
      name : "AKS_Subnet"
      address_prefixes : ["10.0.5.0/24"]
    }
  ]
}


module "VirtualNetworkPeering" {
  source              = "./modules/VirtualNetworkPeering"
  vnet_1_name         = "HubNetwork"
  vnet_1_id           = module.hub_network.vnet_id
  vnet_1_rg           = var.resource_group_name
  vnet_2_name         = var.aks_vnet_name
  vnet_2_id           = module.aks_network.vnet_id
  vnet_2_rg           = var.resource_group_name
  peering_name_1_to_2 = "HubToSpoke"
  peering_name_2_to_1 = "SpokeToHub"
  depends_on = [module.aks_network]
}

module "firewall" {
  source         = "./modules/firewall"
  resource_group = var.resource_group_name
  location       = var.location
  pip_name       = "azureFirewalls-ip"
  fw_name        = "kubenetfw"
  subnet_id      = module.hub_network.subnet_ids["AzureFirewallSubnet"]
  depends_on     = [module.hub_network]
}

module "routetable" {
  source             = "./modules/route_table"
  resource_group     = var.resource_group_name
  location           = var.location
  rt_name            = "kubenetfw_fw_rt"
  r_name             = "kubenetfw_fw_r"
  firewal_private_ip = module.firewall.fw_private_ip
  subnet_id          = module.aks_network.subnet_ids["AKS_Subnet"]
  depends_on = [module.aks_network]
}

resource "azurerm_kubernetes_cluster" "k8s" {
  name                = var.aks_cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.aks_dns_prefix
  kubernetes_version  = "1.19.0"
  private_cluster_enabled = true
  linux_profile {
    admin_username = var.aks_admin_username
    ssh_key {
      key_data = var.aks_ssh_public_key
    }
  }
  default_node_pool {
    name                = var.aks_node_pool_name
    enable_auto_scaling = true
    node_count          = var.aks_agent_count
    min_count           = var.aks_min_agent_count
    max_count           = var.aks_max_agent_count
    vm_size             = var.aks_node_pool_vm_size
    vnet_subnet_id      = module.aks_network.subnet_ids["AKS_Subnet"]
  }
  service_principal {
    client_id     = var.client_id
    client_secret = var.client_secret
  }

  network_profile {
    docker_bridge_cidr = var.network_docker_bridge_cidr
    dns_service_ip     = var.network_dns_service_ip
    network_plugin     = "azure"
    outbound_type      = "userDefinedRouting"
    service_cidr       = var.network_service_cidr
  }
  depends_on = [module.routetable]
}



# #######-----------Using helm charts for deploying AKS -----------------------------------------#
output "kube_config" {
  value = azurerm_kubernetes_cluster.k8s.kube_config_raw
}

provider "helm" {
  version = "1.2.2"
  kubernetes {
    host = azurerm_kubernetes_cluster.k8s.kube_config[0].host
    client_key             = base64decode(azurerm_kubernetes_cluster.k8s.kube_config[0].client_key)
    client_certificate     = base64decode(azurerm_kubernetes_cluster.k8s.kube_config[0].client_certificate)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.k8s.kube_config[0].cluster_ca_certificate)
    load_config_file       = false
  }
}

#Jumpbox
# module "jumpbox" {
#   source                  = "./modules/jumpbox"
#   location                = var.location
#   resource_group          = var.resource_group_name
#   vnet_id                 = module.hub_network.vnet_id
#   subnet_id               = module.hub_network.subnet_ids["jumpbox-subnet"]
#   dns_zone_name           = join(".", slice(split(".", azurerm_kubernetes_cluster.k8s.private_fqdn), 1, length(split(".", azurerm_kubernetes_cluster.k8s.private_fqdn))))
#   dns_zone_resource_group = azurerm_kubernetes_cluster.k8s.node_resource_group
#   depends_on = [module.hub_network]
# }

##Working
# resource "helm_release" "ingress" {
#   name  = "ingress"
#   chart = "stable/nginx-ingress"
#   set {
#     name  = "rbac.create"
#     value = "true"
#   }
# }

# resource "helm_release" "nginx-ingress" {
#   name        = "nginx-ingress-internal"
#   repository  = "https://kubernetes-charts.storage.googleapis.com/"
#   chart       = "nginx-ingress"
#   version     = "1.41.3"
#   set {
#     name  = "rbac.create"
#     value = "true"
#   }
# }

# resource "helm_release" "mysql-release" {
#   name        = "mysql-internal"
#   repository  = "https://kubernetes-charts.storage.googleapis.com"
#   chart       = "mysql"
#   set {
#     name  = "rbac.create"
#     value = "true"
#   }
# }

# resource "helm_release" "clc" {
#   name = "clc-helm-release"
#   repository = "https://kubernetes-charts.storage.googleapis.com/"
#   chart = "clc-helm"
#   version = "1.1.71"
#   dependency_update = true
#   wait = false
#   timeout = 1800
# }
# resource "helm_release" "clc-parser-cef-release" {
#   name        = "clc-parser-cef"
#   repository  = "http://helm.cyberproof.io:8080"
#   version     = "1.0.49"
#   chart       = "clc-parser-cef"
# }