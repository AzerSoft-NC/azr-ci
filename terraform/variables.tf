variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "droplet_id" {
  description = "Existing droplet ID to import (ubuntu-azr-1)"
  type        = number
}

variable "droplet_name" {
  description = "Droplet name in DigitalOcean"
  type        = string
  default     = "ubuntu-azr-1"
}

variable "region" {
  type    = string
  default = "sgp1"
}

variable "droplet_size" {
  description = "Droplet size slug (from existing droplet)"
  type        = string
  default     = "s-1vcpu-2gb"
}

variable "droplet_image" {
  description = "Droplet image slug or id"
  type        = string
  default     = "ubuntu-24-04-x64"
}

variable "manage_dns" {
  description = "Set true only if azersoft.nc uses DO nameservers"
  type        = bool
  default     = false
}

variable "domain" {
  type    = string
  default = "azersoft.nc"
}

variable "apps_subdomain" {
  type    = string
  default = "apps.azersoft.nc"
}

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed to SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
