locals {
  registry = "https://registry.${var.domains[0]}"

  docker_config_json = jsonencode(
  {
    "\"registry-mirrors\"" = ["\"${local.registry}\""]
  })

  common = values({
    for index, az in var.availability_zones :
    az => {
      name_prefix                              = "on-demand-common-${index}"
      instance_type                            = var.on_demand_common_instance_type
      override_instance_types                  = var.on_demand_common_override_instance_types
      asg_max_size                             = var.on_demand_common_max_cluster_size
      asg_min_size                             = var.on_demand_common_min_cluster_size
      asg_desired_capacity                     = var.on_demand_common_desired_capacity
      asg_recreate_on_change                   = var.on_demand_common_asg_recreate_on_change
      on_demand_allocation_strategy            = var.on_demand_common_allocation_strategy
      on_demand_base_capacity                  = var.on_demand_common_base_capacity
      on_demand_percentage_above_base_capacity = var.on_demand_common_percentage_above_base_capacity
      autoscaling_enabled                      = false
      subnets                                  = [element(var.subnets, index)]
      kubelet_extra_args                       = "--node-labels=node.kubernetes.io/lifecycle=normal,node-type=common"
      suspended_processes                      = ["AZRebalance"]
      tags = [
        {
          "key"                 = "k8s.io/cluster-autoscaler/enabled"
          "propagate_at_launch" = "true"
          "value"               = "true"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/${var.cluster_name}"
          "propagate_at_launch" = "true"
          "value"               = "owned"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/label/node-type"
          "propagate_at_launch" = "true"
          "value"               = "common"
        }
      ]
    }
  })

  customers = values({
    for index, customer in var.customers :
    customer => {
      name_prefix                              = "on-demand-${customer}-${index}"
      instance_type                            = var.on_demand_customer_instance_type
      override_instance_types                  = var.on_demand_customer_override_instance_types
      asg_max_size                             = var.on_demand_customer_max_cluster_size
      asg_min_size                             = var.on_demand_customer_min_cluster_size
      asg_desired_capacity                     = var.on_demand_customer_desired_capacity
      asg_recreate_on_change                   = var.on_demand_customer_asg_recreate_on_change
      on_demand_allocation_strategy            = var.on_demand_customer_allocation_strategy
      on_demand_base_capacity                  = var.on_demand_customer_base_capacity
      on_demand_percentage_above_base_capacity = var.on_demand_customer_percentage_above_base_capacity
      autoscaling_enabled                      = false
      subnets                                  = var.subnets
      kubelet_extra_args                       = join(" ", ["--node-labels=node.kubernetes.io/lifecycle=normal,node-type=${customer}", "--register-with-taints=node-type=${customer}:NoSchedule"])
      suspended_processes                      = ["AZRebalance"]
      tags = [
        {
          "key"                 = "k8s.io/cluster-autoscaler/enabled"
          "propagate_at_launch" = "true"
          "value"               = "true"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/${var.cluster_name}"
          "propagate_at_launch" = "true"
          "value"               = "owned"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/label/node-type"
          "propagate_at_launch" = "true"
          "value"               = "${customer}"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/taint/node-type"
          "propagate_at_launch" = "true"
          "value"               = "${customer}:NoSchedule"
        }
      ]
    }
  })
}
