package main

import rego.v1

# ---------------------------------------------------------------------------
# Test helpers
# ---------------------------------------------------------------------------

# object.union merges nested objects recursively, so overriding "tags" with a
# partial map would retain keys from the default — defeating tag-absence tests.
# object.get extracts each top-level field individually: if the key is present
# in after_overrides (even with a null value), that value wins; otherwise the
# default is used. This gives per-field override without recursive merge.

mock_fs(address, after_overrides) := {
	"address": address,
	"type": "aws_fsx_ontap_file_system",
	"change": {
		"actions": ["create"],
		"after": {
			"kms_key_id": object.get(after_overrides, "kms_key_id", "arn:aws:kms:us-east-1:123456789012:key/abc123"),
			"automatic_backup_retention_days": object.get(after_overrides, "automatic_backup_retention_days", 7),
			"deployment_type": object.get(after_overrides, "deployment_type", "MULTI_AZ_1"),
			"tags": object.get(after_overrides, "tags", {"Environment": "prod", "Name": "test-ontap"}),
		},
	},
}

mock_sg_ingress(address, after_overrides) := {
	"address": address,
	"type": "aws_vpc_security_group_ingress_rule",
	"change": {
		"actions": ["create"],
		"after": {
			"cidr_ipv4": object.get(after_overrides, "cidr_ipv4", "10.0.0.0/16"),
			"cidr_ipv6": object.get(after_overrides, "cidr_ipv6", null),
			"from_port": object.get(after_overrides, "from_port", 2049),
			"to_port": object.get(after_overrides, "to_port", 2049),
			"ip_protocol": object.get(after_overrides, "ip_protocol", "tcp"),
		},
	},
}

mock_volume(address, after_overrides) := {
	"address": address,
	"type": "aws_fsx_ontap_volume",
	"change": {
		"actions": ["create"],
		"after": {
			"storage_efficiency_enabled": object.get(after_overrides, "storage_efficiency_enabled", true),
			"snapshot_policy": object.get(after_overrides, "snapshot_policy", "default"),
		},
	},
}

plan_with(resources) := {"resource_changes": resources}

msgs_with_code(results, code) := [m | m := results[_]; contains(m, code)]

# ---------------------------------------------------------------------------
# fsx-001: KMS key required
# ---------------------------------------------------------------------------

test_fsx001_deny_null_kms_key if {
	result := deny with input as plan_with([mock_fs("aws_fsx_ontap_file_system.this[0]", {"kms_key_id": null})])
	count(msgs_with_code(result, "fsx-001")) == 1
}

test_fsx001_allow_kms_key_set if {
	result := deny with input as plan_with([mock_fs("aws_fsx_ontap_file_system.this[0]", {})])
	count(msgs_with_code(result, "fsx-001")) == 0
}

# ---------------------------------------------------------------------------
# fsx-002: Automatic backups must not be disabled
# ---------------------------------------------------------------------------

test_fsx002_deny_retention_zero if {
	result := deny with input as plan_with([mock_fs("aws_fsx_ontap_file_system.this[0]", {"automatic_backup_retention_days": 0})])
	count(msgs_with_code(result, "fsx-002")) == 1
}

test_fsx002_allow_retention_positive if {
	result := deny with input as plan_with([mock_fs("aws_fsx_ontap_file_system.this[0]", {"automatic_backup_retention_days": 7})])
	count(msgs_with_code(result, "fsx-002")) == 0
}

# ---------------------------------------------------------------------------
# sg-001: No unrestricted IPv4 ingress
# ---------------------------------------------------------------------------

test_sg001_deny_open_ipv4 if {
	result := deny with input as plan_with([mock_sg_ingress(
		"aws_vpc_security_group_ingress_rule.this[\"nfs\"]",
		{"cidr_ipv4": "0.0.0.0/0"},
	)])
	count(msgs_with_code(result, "sg-001")) == 1
}

test_sg001_allow_restricted_ipv4 if {
	result := deny with input as plan_with([mock_sg_ingress(
		"aws_vpc_security_group_ingress_rule.this[\"nfs\"]",
		{},
	)])
	count(msgs_with_code(result, "sg-001")) == 0
}

# ---------------------------------------------------------------------------
# sg-002: No unrestricted IPv6 ingress
# ---------------------------------------------------------------------------

test_sg002_deny_open_ipv6 if {
	result := deny with input as plan_with([mock_sg_ingress(
		"aws_vpc_security_group_ingress_rule.this[\"nfs6\"]",
		{"cidr_ipv4": null, "cidr_ipv6": "::/0"},
	)])
	count(msgs_with_code(result, "sg-002")) == 1
}

test_sg002_allow_restricted_ipv6 if {
	result := deny with input as plan_with([mock_sg_ingress(
		"aws_vpc_security_group_ingress_rule.this[\"nfs6\"]",
		{"cidr_ipv4": null, "cidr_ipv6": "2001:db8::/32"},
	)])
	count(msgs_with_code(result, "sg-002")) == 0
}

# ---------------------------------------------------------------------------
# tag-001: Required tags
# ---------------------------------------------------------------------------

test_tag001_deny_missing_environment if {
	result := deny with input as plan_with([mock_fs(
		"aws_fsx_ontap_file_system.this[0]",
		{"tags": {"Name": "test-ontap"}},
	)])
	count(msgs_with_code(result, "tag-001")) == 1
}

test_tag001_deny_missing_name if {
	result := deny with input as plan_with([mock_fs(
		"aws_fsx_ontap_file_system.this[0]",
		{"tags": {"Environment": "prod"}},
	)])
	count(msgs_with_code(result, "tag-001")) == 1
}

test_tag001_deny_missing_both if {
	result := deny with input as plan_with([mock_fs(
		"aws_fsx_ontap_file_system.this[0]",
		{"tags": {}},
	)])
	count(msgs_with_code(result, "tag-001")) == 2
}

test_tag001_allow_all_required_tags if {
	result := deny with input as plan_with([mock_fs("aws_fsx_ontap_file_system.this[0]", {})])
	count(msgs_with_code(result, "tag-001")) == 0
}

# ---------------------------------------------------------------------------
# fsx-101: WARN on Single-AZ deployment
# ---------------------------------------------------------------------------

test_fsx101_warn_single_az_1 if {
	result := warn with input as plan_with([mock_fs(
		"aws_fsx_ontap_file_system.this[0]",
		{"deployment_type": "SINGLE_AZ_1"},
	)])
	count(msgs_with_code(result, "fsx-101")) == 1
}

test_fsx101_warn_single_az_2 if {
	result := warn with input as plan_with([mock_fs(
		"aws_fsx_ontap_file_system.this[0]",
		{"deployment_type": "SINGLE_AZ_2"},
	)])
	count(msgs_with_code(result, "fsx-101")) == 1
}

test_fsx101_no_warn_multi_az if {
	result := warn with input as plan_with([mock_fs("aws_fsx_ontap_file_system.this[0]", {})])
	count(msgs_with_code(result, "fsx-101")) == 0
}

# ---------------------------------------------------------------------------
# fsx-102: WARN when retention is set but below 7 days
# ---------------------------------------------------------------------------

test_fsx102_warn_retention_3 if {
	result := warn with input as plan_with([mock_fs(
		"aws_fsx_ontap_file_system.this[0]",
		{"automatic_backup_retention_days": 3},
	)])
	count(msgs_with_code(result, "fsx-102")) == 1
}

test_fsx102_no_warn_retention_7 if {
	result := warn with input as plan_with([mock_fs("aws_fsx_ontap_file_system.this[0]", {})])
	count(msgs_with_code(result, "fsx-102")) == 0
}

test_fsx102_no_warn_retention_zero if {
	# retention = 0 triggers fsx-002 (deny), not fsx-102 (warn)
	result := warn with input as plan_with([mock_fs(
		"aws_fsx_ontap_file_system.this[0]",
		{"automatic_backup_retention_days": 0},
	)])
	count(msgs_with_code(result, "fsx-102")) == 0
}

# ---------------------------------------------------------------------------
# vol-101: WARN when storage efficiency is not enabled
# ---------------------------------------------------------------------------

test_vol101_warn_efficiency_false if {
	result := warn with input as plan_with([mock_volume(
		"aws_fsx_ontap_volume.this[\"svm_one_data\"]",
		{"storage_efficiency_enabled": false},
	)])
	count(msgs_with_code(result, "vol-101")) == 1
}

test_vol101_warn_efficiency_null if {
	result := warn with input as plan_with([mock_volume(
		"aws_fsx_ontap_volume.this[\"svm_one_data\"]",
		{"storage_efficiency_enabled": null},
	)])
	count(msgs_with_code(result, "vol-101")) == 1
}

test_vol101_no_warn_efficiency_enabled if {
	result := warn with input as plan_with([mock_volume(
		"aws_fsx_ontap_volume.this[\"svm_one_data\"]",
		{},
	)])
	count(msgs_with_code(result, "vol-101")) == 0
}

# ---------------------------------------------------------------------------
# vol-102: WARN when snapshot policy is null
# ---------------------------------------------------------------------------

test_vol102_warn_no_snapshot_policy if {
	result := warn with input as plan_with([mock_volume(
		"aws_fsx_ontap_volume.this[\"svm_one_data\"]",
		{"snapshot_policy": null},
	)])
	count(msgs_with_code(result, "vol-102")) == 1
}

test_vol102_no_warn_with_snapshot_policy if {
	result := warn with input as plan_with([mock_volume(
		"aws_fsx_ontap_volume.this[\"svm_one_data\"]",
		{},
	)])
	count(msgs_with_code(result, "vol-102")) == 0
}

test_vol102_no_warn_custom_snapshot_policy if {
	result := warn with input as plan_with([mock_volume(
		"aws_fsx_ontap_volume.this[\"svm_one_data\"]",
		{"snapshot_policy": "custom-hourly"},
	)])
	count(msgs_with_code(result, "vol-102")) == 0
}
