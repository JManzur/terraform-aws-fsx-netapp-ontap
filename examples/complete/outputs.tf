output "file_system_id" {
  description = "ID of the FSx ONTAP file system"
  value       = module.fsx_ontap.file_system_id
}

output "file_system_arn" {
  description = "ARN of the FSx ONTAP file system"
  value       = module.fsx_ontap.file_system_arn
}

output "file_system_dns_name" {
  description = "DNS name of the FSx ONTAP file system"
  value       = module.fsx_ontap.file_system_dns_name
}

output "file_system_endpoints" {
  description = "Endpoints for CLI, REST API, and SnapMirror access"
  value       = module.fsx_ontap.file_system_endpoints
}

output "file_system_owner_id" {
  description = "AWS account ID that owns the file system"
  value       = module.fsx_ontap.file_system_owner_id
}

output "file_system_vpc_id" {
  description = "VPC ID the file system resides in"
  value       = module.fsx_ontap.file_system_vpc_id
}

output "security_group_id" {
  description = "ID of the security group created for the file system"
  value       = module.fsx_ontap.security_group_id
}

output "storage_virtual_machine_ids" {
  description = "Map of SVM logical key to SVM ID"
  value       = module.fsx_ontap.storage_virtual_machine_ids
}

output "storage_virtual_machine_arns" {
  description = "Map of SVM logical key to SVM ARN"
  value       = module.fsx_ontap.storage_virtual_machine_arns
}

output "storage_virtual_machines" {
  description = "Full SVM attribute map (sensitive)"
  value       = module.fsx_ontap.storage_virtual_machines
  sensitive   = true
}

output "volume_ids" {
  description = "Map of volume logical key to volume ID"
  value       = module.fsx_ontap.volume_ids
}

output "volume_arns" {
  description = "Map of volume logical key to volume ARN"
  value       = module.fsx_ontap.volume_arns
}

output "volumes" {
  description = "Full volume attribute map (sensitive)"
  value       = module.fsx_ontap.volumes
  sensitive   = true
}

output "volume_backups" {
  description = "On-demand backup attributes (arn, id, type)"
  value       = module.fsx_ontap.volume_backups
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for FSx encryption"
  value       = aws_kms_key.fsx.arn
}
