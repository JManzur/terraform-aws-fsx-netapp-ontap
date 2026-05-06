package main

import rego.v1

# ---------------------------------------------------------------------------
# Helpers — collect resources being created or updated in this plan
# ---------------------------------------------------------------------------

fsx_file_systems contains resource if {
	resource := input.resource_changes[_]
	resource.type == "aws_fsx_ontap_file_system"
	resource.change.actions[_] in {"create", "update"}
}

sg_ingress_rules contains resource if {
	resource := input.resource_changes[_]
	resource.type == "aws_vpc_security_group_ingress_rule"
	resource.change.actions[_] in {"create", "update"}
}

fsx_volumes contains resource if {
	resource := input.resource_changes[_]
	resource.type == "aws_fsx_ontap_volume"
	resource.change.actions[_] in {"create", "update"}
}

# ---------------------------------------------------------------------------
# DENY — hard violations that must be fixed before apply
# ---------------------------------------------------------------------------

# [fsx-001] Customer-managed KMS key required for encryption at rest.
# AWS-managed keys cannot be audited per-resource or rotated on your schedule.
deny contains msg if {
	fs := fsx_file_systems[_]
	fs.change.after.kms_key_id == null
	msg := sprintf(
		"[fsx-001] '%s': kms_key_id is null — a customer-managed KMS key is required for encryption at rest",
		[fs.address],
	)
}

# [fsx-002] Automatic backups must be enabled.
deny contains msg if {
	fs := fsx_file_systems[_]
	fs.change.after.automatic_backup_retention_days == 0
	msg := sprintf(
		"[fsx-002] '%s': automatic_backup_retention_days = 0 disables backups; set to >= 7",
		[fs.address],
	)
}

# [sg-001] No unrestricted IPv4 ingress.
deny contains msg if {
	rule := sg_ingress_rules[_]
	rule.change.after.cidr_ipv4 == "0.0.0.0/0"
	msg := sprintf(
		"[sg-001] '%s': ingress allows 0.0.0.0/0 — restrict to a specific CIDR",
		[rule.address],
	)
}

# [sg-002] No unrestricted IPv6 ingress.
deny contains msg if {
	rule := sg_ingress_rules[_]
	rule.change.after.cidr_ipv6 == "::/0"
	msg := sprintf(
		"[sg-002] '%s': ingress allows ::/0 — restrict to a specific CIDR",
		[rule.address],
	)
}

# [tag-001] Required tags must be present on the file system.
required_tags := {"Environment", "Name"}

deny contains msg if {
	fs := fsx_file_systems[_]
	tag := required_tags[_]
	not fs.change.after.tags[tag]
	msg := sprintf(
		"[tag-001] '%s': missing required tag '%s'",
		[fs.address, tag],
	)
}

# ---------------------------------------------------------------------------
# WARN — advisories that should be reviewed but do not block apply
# ---------------------------------------------------------------------------

# [fsx-101] Single-AZ deployments have lower availability than Multi-AZ.
warn contains msg if {
	fs := fsx_file_systems[_]
	contains(fs.change.after.deployment_type, "SINGLE_AZ")
	msg := sprintf(
		"[fsx-101] '%s': deployment_type is '%s' — consider MULTI_AZ for production workloads",
		[fs.address, fs.change.after.deployment_type],
	)
}

# [fsx-102] Backup retention below the recommended minimum of 7 days.
warn contains msg if {
	fs := fsx_file_systems[_]
	retention := fs.change.after.automatic_backup_retention_days
	retention != null
	retention > 0
	retention < 7
	msg := sprintf(
		"[fsx-102] '%s': automatic_backup_retention_days = %d — recommend >= 7 days",
		[fs.address, retention],
	)
}

# [vol-101] Storage efficiency reduces capacity usage and should be enabled.
warn contains msg if {
	vol := fsx_volumes[_]
	vol.change.after.storage_efficiency_enabled != true
	msg := sprintf(
		"[vol-101] '%s': storage_efficiency_enabled is not true — consider enabling to reduce storage costs",
		[vol.address],
	)
}

# [vol-102] Snapshot policy protects against accidental data loss.
warn contains msg if {
	vol := fsx_volumes[_]
	vol.change.after.snapshot_policy == null
	msg := sprintf(
		"[vol-102] '%s': snapshot_policy is null — consider setting 'default' or a custom policy",
		[vol.address],
	)
}
