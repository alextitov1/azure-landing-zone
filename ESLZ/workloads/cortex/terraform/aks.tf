# AKS cluster, configured by `aks` in ../config/dev.yaml: Entra ID sign-in with Kubernetes RBAC, Azure CNI Overlay
# in the cortex spoke, a system pool and user pools on Azure Linux.

locals {
  aks      = local.config.aks
  aks_name = module.naming[local.config.workload].names.container_service_managed_cluster.name

  # Nodes in their own subnet; Kubernetes services in a range IPAM reserved for them, so no VNet overlaps it
  aks_subnet_id    = local.connectivity.subnets[local.aks.network.subnet]
  aks_service_cidr = local.connectivity.reservations[local.aks.network.service_cidr]

  # Node pools of the YAML (system pool first) => agent pools of the module
  aks_node_pools = {
    for name, p in merge({ (local.aks.system_pool.name) = local.aks.system_pool }, try(local.aks.user_pools, {})) : name => {
      name                      = name
      vm_size                   = p.vm_size
      os_sku                    = p.os_sku
      os_disk_type              = try(p.os_disk_type, null)
      os_disk_size_gb           = try(p.os_disk_size_gb, null)
      enable_auto_scaling       = true
      min_count                 = p.min_count
      max_count                 = p.max_count
      max_pods                  = try(p.max_pods, null)
      availability_zones        = try(length(p.zones) > 0 ? p.zones : null, null)
      enable_encryption_at_host = try(p.encryption_at_host, false)
      node_labels               = try(length(p.node_labels) > 0 ? p.node_labels : null, null)
      # null when the pool has no taints
      node_taints = try(coalescelist(concat(
        try(p.node_taints, []),
        try(p.only_critical_addons, false) ? ["CriticalAddonsOnly=true:NoSchedule"] : [],
      )), null)
      vnet_subnet_id = local.aks_subnet_id
    }
  }

  # Planned maintenance for the auto-upgrade channels that are on
  aks_maintenance = {
    for name, enabled in {
      aksManagedAutoUpgradeSchedule   = local.aks.auto_upgrade.channel != "none"
      aksManagedNodeOSUpgradeSchedule = !contains(["None", "Unmanaged"], local.aks.auto_upgrade.node_os_channel)
      } : name => {
      name = name
      maintenance_window = {
        duration_hours = local.aks.maintenance_window.duration_hours
        start_time     = local.aks.maintenance_window.start_time
        utc_offset     = local.aks.maintenance_window.utc_offset
        schedule       = { weekly = { day_of_week = local.aks.maintenance_window.day_of_week, interval_weeks = 1 } }
      }
    } if enabled && try(local.aks.maintenance_window, null) != null
  }

  # Advanced Container Networking Services: network observability and network security (cilium)
  aks_acns = local.aks.monitoring.network_observability || local.aks.security.network_security
}

# Control plane and kubelet identities, created by ESLZ/subscriptions with their role assignments, because this
# pipeline cannot assign roles: Network Contributor on the node subnet and Managed Identity Operator on the kubelet
# identity (control plane), AcrPull on the resource group (kubelet).
data "azapi_resource" "identity" {
  for_each = local.aks.identities

  type      = "Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31"
  name      = each.value
  parent_id = local.resource_group_id
}

module "aks" {
  source  = "Azure/avm-res-containerservice-managedcluster/azurerm"
  version = "0.8.5"

  name             = local.aks_name
  parent_id        = local.resource_group_id
  location         = local.config.location
  tags             = local.tags
  enable_telemetry = false

  # Basics
  sku                = { name = "Base", tier = local.aks.sku_tier }
  support_plan       = local.aks.support_plan
  kubernetes_version = local.aks.kubernetes_version
  auto_upgrade_profile = {
    upgrade_channel         = local.aks.auto_upgrade.channel
    node_os_upgrade_channel = local.aks.auto_upgrade.node_os_channel
  }
  maintenanceconfiguration = local.aks_maintenance
  dns_prefix               = try(local.aks.network.dns_prefix, local.aks_name)
  node_resource_group      = module.naming["${local.config.workload}-aksnodes"].names.resource_group.name
  node_resource_group_profile = {
    restriction_level = local.aks.security.node_resource_group_lockdown ? "ReadOnly" : "Unrestricted"
  }

  # Identities
  managed_identities = { user_assigned_resource_ids = [data.azapi_resource.identity["control_plane"].id] }
  identity_profile   = { kubeletidentity = { resource_id = data.azapi_resource.identity["kubelet"].id } }

  # Authentication and authorization
  aad_profile = {
    managed                = true
    enable_azure_rbac      = local.aks.entra.azure_rbac
    admin_group_object_ids = local.aks.entra.admin_group_object_ids
  }
  enable_rbac            = true
  disable_local_accounts = local.aks.entra.disable_local_accounts

  # Node pools
  default_agent_pool = local.aks_node_pools[local.aks.system_pool.name]
  agent_pools = {
    for name, p in local.aks_node_pools : name => merge(p, { mode = "User", os_type = "Linux" })
    if name != local.aks.system_pool.name
  }
  auto_scaler_profile = try(local.aks.autoscaler_profile, null)

  # Networking
  api_server_access_profile = {
    enable_private_cluster = local.aks.network.private_cluster
    authorized_ip_ranges   = length(local.aks.network.authorized_ip_ranges) > 0 ? local.aks.network.authorized_ip_ranges : null
    disable_run_command    = local.aks.security.disable_run_command
  }
  network_profile = {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_dataplane   = local.aks.network.dataplane
    network_policy      = local.aks.network.network_policy
    pod_cidr            = local.aks.network.pod_cidr
    service_cidr        = local.aks_service_cidr
    dns_service_ip      = cidrhost(local.aks_service_cidr, local.aks.network.dns_service_ip_host)
    outbound_type       = local.aks.network.outbound_type
    load_balancer_sku   = "standard"
    advanced_networking = local.aks_acns ? {
      enabled       = true
      observability = { enabled = local.aks.monitoring.network_observability }
      security      = { enabled = local.aks.security.network_security }
    } : null
  }

  # Integrations and add-ons
  addon_profile_azure_policy = { enabled = local.aks.features.azure_policy }
  ingress_profile            = local.aks.features.app_routing ? { web_app_routing = { enabled = true } } : null
  workload_auto_scaler_profile = {
    keda                    = { enabled = local.aks.features.keda }
    vertical_pod_autoscaler = { enabled = local.aks.features.vertical_pod_autoscaler }
  }
  metrics_profile = { cost_analysis = { enabled = local.aks.features.cost_analysis } }
  storage_profile = {
    disk_csi_driver     = { enabled = local.aks.storage.disk_csi_driver }
    file_csi_driver     = { enabled = local.aks.storage.file_csi_driver }
    blob_csi_driver     = { enabled = local.aks.storage.blob_csi_driver }
    snapshot_controller = { enabled = local.aks.storage.snapshot_controller }
  }

  # Monitoring: container logs and managed Prometheus, with their data collection rules
  onboard_monitoring = local.aks.monitoring.enabled
  addon_profile_oms_agent = local.aks.monitoring.enabled ? {
    enabled = true
    config = {
      log_analytics_workspace_resource_id = try(local.aks.monitoring.log_analytics_workspace_id, null)
      use_aad_auth                        = true
    }
  } : null
  azure_monitor_profile   = local.aks.monitoring.enabled ? { metrics = { enabled = true, kube_state_metrics = {} } } : null
  prometheus_workspace_id = local.aks.monitoring.enabled ? try(local.aks.monitoring.azure_monitor_workspace_id, null) : null
  onboard_alerts          = try(local.aks.monitoring.alert_email, null) != null
  alert_email             = try(local.aks.monitoring.alert_email, null)

  # Security
  oidc_issuer_profile = { enabled = local.aks.security.oidc_issuer }
  security_profile = {
    workload_identity = { enabled = local.aks.security.workload_identity }
    image_cleaner = {
      enabled        = local.aks.security.image_cleaner
      interval_hours = local.aks.security.image_cleaner_interval_hours
    }
  }
  # The module enables the add-on whenever this is set
  addon_profile_key_vault_secrets_provider = local.aks.security.secret_store_csi_driver ? {
    enabled = true
    config  = { enable_secret_rotation = true }
  } : null
}
