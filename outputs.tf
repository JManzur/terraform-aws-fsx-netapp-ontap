################################################################################
# File System
################################################################################

output "file_system_arn" {
  description = "Amazon Resource Name of the file system"
  value       = try(local.file_system_output.arn, null)
}

output "file_system_dns_name" {
  description = "DNS name for the file system, e.g., `fs-12345678.fsx.us-west-2.amazonaws.com`"
  value       = try(local.file_system_output.dns_name, null)
}

output "file_system_endpoints" {
  description = "The endpoints that are used to access data or to manage the file system using the NetApp ONTAP CLI, REST API, or NetApp SnapMirror"
  value       = try(local.file_system_output.endpoints, [])
}

output "file_system_id" {
  description = "Identifier of the file system, e.g., `fs-12345678`"
  value       = try(local.file_system_output.id, null)
}

output "file_system_network_interface_ids" {
  description = "Set of Elastic Network Interface identifiers from which the file system is accessible"
  value       = try(local.file_system_output.network_interface_ids, [])
}

output "file_system_owner_id" {
  description = "AWS account ID that owns the file system"
  value       = try(local.file_system_output.owner_id, null)
}

output "file_system_vpc_id" {
  description = "ID of the VPC the file system resides in"
  value       = try(local.file_system_output.vpc_id, null)
}

################################################################################
# ONTAP Storage Virtual Machine(s)
################################################################################

output "storage_virtual_machines" {
  description = "A map of ONTAP storage virtual machines and their full attributes (sensitive — contains endpoint IPs and credential fields)"
  value       = local.storage_virtual_machines_output
  sensitive   = true
}

output "storage_virtual_machine_ids" {
  description = "Map of SVM logical key to SVM ID"
  value       = { for k, v in local.storage_virtual_machines_output : k => v.id }
}

output "storage_virtual_machine_arns" {
  description = "Map of SVM logical key to SVM ARN"
  value       = { for k, v in local.storage_virtual_machines_output : k => v.arn }
}

################################################################################
# ONTAP Volume(s)
################################################################################

output "volumes" {
  description = "A map of ONTAP volumes and their full attributes (sensitive — contains credential fields)"
  value       = aws_fsx_ontap_volume.this
  sensitive   = true
}

output "volume_ids" {
  description = "Map of volume logical key to volume ID"
  value       = { for k, v in aws_fsx_ontap_volume.this : k => v.id }
}

output "volume_arns" {
  description = "Map of volume logical key to volume ARN"
  value       = { for k, v in aws_fsx_ontap_volume.this : k => v.arn }
}

################################################################################
# Security Group
################################################################################

output "security_group_arn" {
  description = "Amazon Resource Name (ARN) of the security group"
  value       = try(aws_security_group.this[0].arn, null)
}

output "security_group_id" {
  description = "ID of the security group"
  value       = try(aws_security_group.this[0].id, null)
}

################################################################################
# Volume Backups
################################################################################

output "volume_backups" {
  description = "Map of backup logical key to backup attributes (arn, id, kms_key_id, owner_id, type)"
  value       = aws_fsx_backup.this
}
