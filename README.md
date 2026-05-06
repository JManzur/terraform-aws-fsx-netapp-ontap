# terraform-aws-fsx-netapp-ontap

Terraform module for [Amazon FSx for NetApp ONTAP](https://aws.amazon.com/fsx/netapp-ontap/). Creates and manages an ONTAP file system, storage virtual machines (SVMs), volumes, a managed security group, and on-demand volume backups.

## Features

- ONTAP file system with all deployment types (`MULTI_AZ_1`, `MULTI_AZ_2`, `SINGLE_AZ_1`, `SINGLE_AZ_2`)
- Multiple SVMs with optional Active Directory (self-managed) integration
- Volumes nested under SVM definitions — a single input surface for the full hierarchy
- Full SnapLock, tiering policy, aggregate, and snapshot policy support on volumes
- On-demand volume backups (`aws_fsx_backup`) with per-backup tag control
- Managed security group using separate ingress/egress rule resources (AWS provider v5+)
- Create-or-lookup mode: set `create = false` to reference existing file systems and SVMs via data sources instead of creating new resources

## Usage

### Minimal - Single-AZ

```hcl
module "fsx_ontap" {
  source = "github.com/jmanzur/terraform-aws-fsx-netapp-ontap"

  name             = "my-ontap"
  deployment_type  = "SINGLE_AZ_1"
  storage_capacity = 1024

  subnet_ids          = ["subnet-12345678"]
  preferred_subnet_id = "subnet-12345678"

  throughput_capacity = 128

  tags = {
    Environment = "dev"
  }
}
```

### Complete - Multi-AZ with SVMs, volumes, and backups

```hcl
module "fsx_ontap" {
  source = "github.com/jmanzur/terraform-aws-fsx-netapp-ontap"

  name             = "prod-ontap"
  deployment_type  = "MULTI_AZ_1"
  storage_capacity = 2048

  subnet_ids          = ["subnet-aaa111", "subnet-bbb222"]
  preferred_subnet_id = "subnet-aaa111"
  route_table_ids     = ["rtb-12345678"]

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

  # Security group with NFS, CIFS, and iSCSI ingress
  create_security_group      = true
  security_group_description = "FSx ONTAP access"

  security_group_ingress_rules = {
    nfs = {
      description = "NFS"
      from_port   = 2049
      to_port     = 2049
      ip_protocol = "tcp"
      cidr_ipv4   = "10.0.0.0/16"
    }
    cifs = {
      description = "CIFS/SMB"
      from_port   = 445
      to_port     = 445
      ip_protocol = "tcp"
      cidr_ipv4   = "10.0.0.0/16"
    }
    iscsi = {
      description = "iSCSI"
      from_port   = 3260
      to_port     = 3260
      ip_protocol = "tcp"
      cidr_ipv4   = "10.0.0.0/16"
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

      volumes = {
        data = {
          name                       = "vol_data"
          junction_path              = "/data"
          size_in_megabytes          = 204800
          storage_efficiency_enabled = true
          security_style             = "UNIX"
          snapshot_policy            = "default"
          skip_final_backup          = false
          final_backup_tags          = { BackupType = "final" }

          tiering_policy = {
            name           = "AUTO"
            cooling_period = 31
          }
        }
      }
    }
  }

  # On-demand backup of the data volume
  volume_backups = {
    data_backup = {
      volume_key = "svm_one_data"
      tags       = { BackupType = "on-demand" }
    }
  }

  tags = {
    Environment = "prod"
    Team        = "platform"
  }
}
```

### Referencing existing resources (`create = false`)

Use this pattern to look up a file system or SVMs that already exist and are not managed by this module:

```hcl
module "fsx_ontap" {
  source = "github.com/jmanzur/terraform-aws-fsx-netapp-ontap"

  create = false

  # Look up the existing file system
  file_system_id = "fs-0123456789abcdef0"

  # Look up existing SVMs by logical key → SVM ID
  storage_virtual_machine_ids = {
    svm_one = "svm-0123456789abcdef0"
  }
}

# Outputs work identically whether resources were created or looked up
output "file_system_dns_name" {
  value = module.fsx_ontap.file_system_dns_name
}
```

## Storage Virtual Machines and Volumes

SVMs and their volumes are defined together under `storage_virtual_machines`. The module flattens volumes into individual `aws_fsx_ontap_volume` resources using a composite key of `machine_key_volume_key`.

```hcl
storage_virtual_machines = {
  # machine_key = "app"
  app = {
    name               = "svm-app"
    svm_admin_password = var.svm_password

    # Optional: Active Directory integration
    active_directory_configuration = {
      netbios_name = "SVM-APP"
      self_managed_active_directory_configuration = {
        dns_ips     = ["10.0.0.10", "10.0.0.11"]
        domain_name = "corp.example.com"
        username    = "SvcAccount"
        password    = var.ad_password
        organizational_unit_distinguished_name = "OU=FSx,DC=corp,DC=example,DC=com"
      }
    }

    tags = { Purpose = "application" }

    volumes = {
      # volume_key = "data" → resource key becomes "app_data"
      data = {
        name                       = "vol_data"
        junction_path              = "/data"
        size_in_megabytes          = 102400
        storage_efficiency_enabled = true
        security_style             = "UNIX"       # UNIX | NTFS | MIXED
        ontap_volume_type          = "RW"          # RW | DP
        snapshot_policy            = "default"
        skip_final_backup          = false
        final_backup_tags          = { BackupType = "final" }

        tiering_policy = {
          name           = "AUTO"   # NONE | SNAPSHOT_ONLY | AUTO | ALL
          cooling_period = 31
        }

        # FlexGroup volumes (MULTI_AZ_2 / SINGLE_AZ_2 only)
        volume_style = "FLEXGROUP"
        aggregate_configuration = {
          aggregates                 = ["aggr1", "aggr2"]
          constituents_per_aggregate = 4
        }

        # SnapLock (optional)
        snaplock_configuration = {
          snaplock_type = "COMPLIANCE"  # COMPLIANCE | ENTERPRISE
          retention_period = {
            default_retention = { type = "DAYS", value = 30 }
            minimum_retention = { type = "DAYS", value = 1  }
            maximum_retention = { type = "YEARS", value = 7  }
          }
        }

        tags = { Purpose = "app-data" }
      }
    }
  }
}
```

### On-demand backups

Reference a module-managed volume by its composite key (`machine_key_volume_key`), or pass an explicit `volume_id` for externally-managed volumes:

```hcl
volume_backups = {
  nightly = {
    volume_key = "app_data"
    tags       = { Schedule = "nightly" }
  }
  external = {
    volume_id = "fsvol-0123456789abcdef0"
    tags      = { Schedule = "weekly" }
  }
}
```

## Examples

| Example | Description |
|---------|-------------|
| [minimal](examples/minimal/) | Single-AZ file system with default security group and no SVMs |
| [complete](examples/complete/) | Multi-AZ with KMS encryption, SVMs, volumes, security group rules, and on-demand backup |

## Testing

The module ships with a native `terraform test` suite using mock providers — no AWS credentials or real infrastructure required.

```bash
# From the module root
terraform test
```

All tests use `command = plan` with `mock_provider "aws"` and cover:

| Test | What it checks |
|------|---------------|
| `file_system_created_by_default` | One file system is planned when `create = true` |
| `file_system_skipped_when_create_false` | No file system when `create = false` |
| `name_tag_matches_var_name` | `Name` tag equals `var.name` |
| `custom_tags_applied` | Arbitrary tags flow through to resources |
| `security_group_created_by_default` | Security group is planned by default |
| `security_group_skipped_when_disabled` | No SG when `create_security_group = false` |
| `ha_pairs_with_throughput_per_pair` | File system created with `ha_pairs` set |
| `invalid_deployment_type_rejected` | Bad `deployment_type` triggers validation error |
| `svms_created_with_volumes` | SVM and nested volume both planned |

To run the examples as integration tests (real AWS credentials required):

```bash
cd examples/minimal
terraform init
terraform plan -var='subnet_ids=["subnet-xxxxx"]'

cd examples/complete
terraform init
terraform plan \
  -var='subnet_ids=["subnet-aaaaa","subnet-bbbbb"]' \
  -var='fsx_admin_password=changeme' \
  -var='svm_admin_password=changeme'
```

---

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.10.0 |
| aws | >= 6.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 6.0 |

## Resources

| Name | Type |
|------|------|
| [aws_fsx_backup.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/fsx_backup) | resource |
| [aws_fsx_ontap_file_system.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/fsx_ontap_file_system) | resource |
| [aws_fsx_ontap_storage_virtual_machine.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/fsx_ontap_storage_virtual_machine) | resource |
| [aws_fsx_ontap_volume.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/fsx_ontap_volume) | resource |
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [data.aws_fsx_ontap_file_system.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/fsx_ontap_file_system) | data source |
| [data.aws_fsx_ontap_storage_virtual_machine.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/fsx_ontap_storage_virtual_machine) | data source |
| [data.aws_subnet.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| automatic\_backup\_retention\_days | The number of days to retain automatic backups. Setting this to 0 disables automatic backups. Maximum 90 days. | `number` | `null` | no |
| create | Determines whether resources will be created (affects all resources). | `bool` | `true` | no |
| create\_security\_group | Determines if a security group is created. | `bool` | `true` | no |
| daily\_automatic\_backup\_start\_time | A recurring daily time in `HH:MM` format (UTC) to start automatic backups. Requires `automatic_backup_retention_days`. | `string` | `null` | no |
| deployment\_type | The filesystem deployment type. One of: `MULTI_AZ_1`, `MULTI_AZ_2`, `SINGLE_AZ_1`, `SINGLE_AZ_2`. | `string` | `"MULTI_AZ_1"` | no |
| disk\_iops\_configuration | SSD IOPS configuration. `mode` is `AUTOMATIC` or `USER_PROVISIONED`; `iops` required when mode is `USER_PROVISIONED`. | `object({ iops = optional(number), mode = optional(string) })` | `null` | no |
| endpoint\_ip\_address\_range | IP address range for file system endpoints. Defaults to an unused range from `198.19.0.0/16`. | `string` | `null` | no |
| file\_system\_id | ID of an existing FSx ONTAP file system to look up when `create = false`. | `string` | `null` | no |
| fsx\_admin\_password | ONTAP administrative password for the `fsxadmin` user. **Sensitive** — stored in state; ensure state is encrypted. | `string` | `null` | no |
| ha\_pairs | Number of HA pairs to deploy (1–6). When set, use `throughput_capacity_per_ha_pair` instead of `throughput_capacity`. | `number` | `null` | no |
| kms\_key\_id | ARN of the KMS key used to encrypt the file system at rest. Defaults to the AWS managed key. | `string` | `null` | no |
| name | Name tag applied to the file system and used as the default security group name. | `string` | `""` | no |
| preferred\_subnet\_id | ID of the preferred subnet for the file system's primary endpoint. | `string` | `""` | no |
| route\_table\_ids | VPC route table IDs in which file system endpoints will be created. | `list(string)` | `[]` | no |
| security\_group\_description | Description of the managed security group. | `string` | `null` | no |
| security\_group\_egress\_rules | Map of egress rule definitions for the managed security group. Each value supports: `cidr_ipv4`, `cidr_ipv6`, `prefix_list_id`, `referenced_security_group_id`, `from_port`, `to_port`, `ip_protocol`, `description`, `tags`. | `any` | `{}` | no |
| security\_group\_ids | Additional security group IDs to attach to the file system network interfaces. | `list(string)` | `[]` | no |
| security\_group\_ingress\_rules | Map of ingress rule definitions for the managed security group. Same fields as `security_group_egress_rules`. | `any` | `{}` | no |
| security\_group\_name | Name for the managed security group. Defaults to `var.name`. | `string` | `null` | no |
| security\_group\_tags | Additional tags to add to the managed security group. | `map(string)` | `{}` | no |
| security\_group\_use\_name\_prefix | When `true`, the security group name is used as a prefix and AWS generates the unique suffix. | `bool` | `true` | no |
| storage\_capacity | Storage capacity of the file system in GiB. | `number` | `null` | no |
| storage\_type | Storage type. Defaults to `SSD`. | `string` | `null` | no |
| storage\_virtual\_machine\_ids | Map of logical key to SVM ID for existing SVMs to look up when `create = false`. Keys should match those used in `storage_virtual_machines`. | `map(string)` | `{}` | no |
| storage\_virtual\_machines | Map of SVM definitions. Each entry may include a `volumes` map whose entries are created as `aws_fsx_ontap_volume` resources keyed as `{machine_key}_{volume_key}`. | `any` | `{}` | no |
| storage\_virtual\_machines\_timeouts | Create, update, and delete timeouts for storage virtual machines. | `map(string)` | `{}` | no |
| subnet\_ids | Subnet IDs the file system will be accessible from. Provide two subnets in different AZs for Multi-AZ deployments. | `list(string)` | `[]` | no |
| tags | Tags to apply to all resources created by this module. | `map(string)` | `{}` | no |
| throughput\_capacity | Throughput capacity in MBps. Valid values: `128`, `256`, `512`, `1024`, `2048`, `4096`. Required when `ha_pairs` is not set. | `number` | `null` | no |
| throughput\_capacity\_per\_ha\_pair | Throughput capacity per HA pair in MBps. Valid values: `3072`, `6144`. Required when `ha_pairs` is set. | `number` | `null` | no |
| timeouts | Create, update, and delete timeouts for the file system. | `map(string)` | `{}` | no |
| volume\_backups | Map of on-demand backup definitions. Specify `volume_key` (composite `machine_key_volume_key` for a module-managed volume) or `volume_id` (for an externally-managed volume). | `map(object({ volume_key = optional(string), volume_id = optional(string), tags = optional(map(string), {}) }))` | `{}` | no |
| volume\_backups\_timeouts | Create and delete timeouts for volume backups. | `map(string)` | `{}` | no |
| volumes\_timeouts | Create, update, and delete timeouts for volumes. | `map(string)` | `{}` | no |
| weekly\_maintenance\_start\_time | Preferred weekly maintenance window in `d:HH:MM` format (UTC). `d` is 1=Monday through 7=Sunday. | `string` | `null` | no |

## Outputs

| Name | Description | Sensitive |
|------|-------------|-----------|
| file\_system\_arn | Amazon Resource Name of the file system. | no |
| file\_system\_dns\_name | DNS name of the file system, e.g. `fs-12345678.fsx.us-east-1.amazonaws.com`. | no |
| file\_system\_endpoints | Endpoints for ONTAP CLI, REST API, and SnapMirror access. | no |
| file\_system\_id | Identifier of the file system, e.g. `fs-12345678`. | no |
| file\_system\_network\_interface\_ids | Set of Elastic Network Interface IDs from which the file system is accessible. | no |
| file\_system\_owner\_id | AWS account ID that owns the file system. | no |
| file\_system\_vpc\_id | ID of the VPC the file system resides in. | no |
| security\_group\_arn | ARN of the managed security group. | no |
| security\_group\_id | ID of the managed security group. | no |
| storage\_virtual\_machine\_arns | Map of SVM logical key to SVM ARN. | no |
| storage\_virtual\_machine\_ids | Map of SVM logical key to SVM ID. | no |
| storage\_virtual\_machines | Full SVM attribute map including endpoint IPs and credential fields. | **yes** |
| volume\_arns | Map of volume logical key to volume ARN. | no |
| volume\_backups | Map of backup logical key to backup attributes (`arn`, `id`, `kms_key_id`, `owner_id`, `type`). | no |
| volume\_ids | Map of volume logical key to volume ID. | no |
| volumes | Full volume attribute map. | **yes** |
<!-- END_TF_DOCS -->

## License

Apache 2.0 — see [LICENSE](LICENSE).
