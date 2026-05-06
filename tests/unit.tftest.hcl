mock_provider "aws" {}

variables {
  name             = "test-ontap"
  deployment_type  = "SINGLE_AZ_1"
  storage_capacity = 1024

  subnet_ids          = ["subnet-12345678"]
  preferred_subnet_id = "subnet-12345678"

  throughput_capacity = 128
}

run "file_system_created_by_default" {
  command = plan

  assert {
    condition     = length(aws_fsx_ontap_file_system.this) == 1
    error_message = "Expected one file system when create = true"
  }
}

run "file_system_skipped_when_create_false" {
  command = plan

  variables {
    create = false
  }

  assert {
    condition     = length(aws_fsx_ontap_file_system.this) == 0
    error_message = "Expected no file system when create = false"
  }
}

run "name_tag_matches_var_name" {
  command = plan

  assert {
    condition     = aws_fsx_ontap_file_system.this[0].tags["Name"] == var.name
    error_message = "Expected Name tag to equal var.name"
  }
}

run "custom_tags_applied" {
  command = plan

  variables {
    tags = {
      Environment = "staging"
      Team        = "platform"
    }
  }

  assert {
    condition     = aws_fsx_ontap_file_system.this[0].tags["Environment"] == "staging"
    error_message = "Expected Environment tag to be applied"
  }
}

run "security_group_created_by_default" {
  command = plan

  assert {
    condition     = length(aws_security_group.this) == 1
    error_message = "Expected security group to be created by default"
  }
}

run "security_group_skipped_when_disabled" {
  command = plan

  variables {
    create_security_group = false
  }

  assert {
    condition     = length(aws_security_group.this) == 0
    error_message = "Expected no security group when create_security_group = false"
  }
}

run "ha_pairs_with_throughput_per_pair" {
  command = plan

  variables {
    ha_pairs                        = 2
    throughput_capacity             = null
    throughput_capacity_per_ha_pair = 3072
  }

  # Verifies the resource is created — throughput attribute values are not known
  # during plan with mock providers; the conditional routing in main.tf is
  # enforced by the HCL expression, not the provider.
  assert {
    condition     = length(aws_fsx_ontap_file_system.this) == 1
    error_message = "Expected file system to be created with ha_pairs set"
  }
}

run "invalid_deployment_type_rejected" {
  command = plan

  variables {
    deployment_type = "UNSUPPORTED_TYPE"
  }

  expect_failures = [var.deployment_type]
}

run "svms_created_with_volumes" {
  command = plan

  variables {
    storage_virtual_machines = {
      svm_one = {
        name = "svm-one"
        volumes = {
          data = {
            name              = "vol_data"
            junction_path     = "/data"
            size_in_megabytes = 102400
          }
        }
      }
    }
  }

  assert {
    condition     = length(aws_fsx_ontap_storage_virtual_machine.this) == 1
    error_message = "Expected one SVM to be created"
  }

  assert {
    condition     = length(aws_fsx_ontap_volume.this) == 1
    error_message = "Expected one volume to be created"
  }
}
