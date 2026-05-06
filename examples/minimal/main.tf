module "fsx_ontap" {
  source = "../.."

  name             = "minimal-ontap"
  deployment_type  = "SINGLE_AZ_1"
  storage_capacity = 1024

  subnet_ids          = var.subnet_ids
  preferred_subnet_id = var.subnet_ids[0]

  throughput_capacity = 128

  tags = {
    Environment = "dev"
  }
}
