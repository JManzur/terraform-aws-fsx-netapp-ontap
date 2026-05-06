data "aws_caller_identity" "current" {}

resource "aws_kms_key" "fsx" {
  description             = "KMS key for FSx ONTAP encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = local.tags
}

locals {
  tags = {
    Environment = "prod"
    Team        = "platform"
  }

  # CIDR of the VPC — tighten per-environment
  vpc_cidr = "10.0.0.0/16"
}

module "fsx_ontap" {
  source = "../.."

  name             = "complete-ontap"
  deployment_type  = "MULTI_AZ_1"
  storage_capacity = 2048

  subnet_ids          = var.subnet_ids
  preferred_subnet_id = var.subnet_ids[0]
  route_table_ids     = var.route_table_ids

  throughput_capacity = 512

  fsx_admin_password = var.fsx_admin_password
  kms_key_id         = aws_kms_key.fsx.arn

  automatic_backup_retention_days   = 7
  daily_automatic_backup_start_time = "02:00"
  weekly_maintenance_start_time     = "1:03:00"

  disk_iops_configuration = {
    mode = "USER_PROVISIONED"
    iops = 5000
  }

  # Security group with ingress rules for NFS and CIFS
  create_security_group      = true
  security_group_description = "FSx ONTAP security group"

  security_group_ingress_rules = {
    nfs_tcp = {
      description = "NFS TCP"
      from_port   = 2049
      to_port     = 2049
      ip_protocol = "tcp"
      cidr_ipv4   = local.vpc_cidr
    }
    nfs_udp = {
      description = "NFS UDP"
      from_port   = 2049
      to_port     = 2049
      ip_protocol = "udp"
      cidr_ipv4   = local.vpc_cidr
    }
    cifs = {
      description = "CIFS/SMB"
      from_port   = 445
      to_port     = 445
      ip_protocol = "tcp"
      cidr_ipv4   = local.vpc_cidr
    }
    iscsi = {
      description = "iSCSI"
      from_port   = 3260
      to_port     = 3260
      ip_protocol = "tcp"
      cidr_ipv4   = local.vpc_cidr
    }
  }

  security_group_egress_rules = {
    all = {
      description = "Allow all outbound"
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  # SVMs with nested volumes
  storage_virtual_machines = {
    svm_one = {
      name               = "svm-one"
      svm_admin_password = var.svm_admin_password

      tags = { Purpose = "nfs-workloads" }

      volumes = {
        data = {
          name                       = "vol_data"
          junction_path              = "/data"
          size_in_megabytes          = 204800 # 200 GiB
          storage_efficiency_enabled = true
          security_style             = "UNIX"
          snapshot_policy            = "default"
          skip_final_backup          = false
          final_backup_tags          = { BackupType = "final", Volume = "data" }

          tiering_policy = {
            name           = "AUTO"
            cooling_period = 31
          }

          tags = { Purpose = "application-data" }
        }

        logs = {
          name                       = "vol_logs"
          junction_path              = "/logs"
          size_in_megabytes          = 51200 # 50 GiB
          storage_efficiency_enabled = true
          security_style             = "UNIX"
          skip_final_backup          = true

          tags = { Purpose = "log-storage" }
        }
      }
    }
  }

  # On-demand backup of the data volume
  volume_backups = {
    data_backup = {
      volume_key = "svm_one_data"
      tags       = { BackupType = "on-demand", Volume = "data" }
    }
  }

  tags = local.tags
}
