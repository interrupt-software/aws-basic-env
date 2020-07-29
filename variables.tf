variable "key_name" {
  default = "interrupt-key"
}

variable "ssh_key" {
}

variable "tags" {
  type = map

  default = {
    Organization = "Interrupt Software"
    DoNotDelete  = "True"
    Keep         = "True"
    Owner        = "gilberto@hashicorp.com"
    Region       = "US-EAST"
    Purpose      = "HUG Demo Env"
    TTL          = "168"
    Terraform    = "true"
    TFE          = "false"
    TFE_Worspace = "null"
  }
}
