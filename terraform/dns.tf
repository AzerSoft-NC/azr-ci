# Optional: manage DNS when the domain uses DigitalOcean nameservers.
# Skip or remove if DNS is managed elsewhere.

data "digitalocean_domain" "main" {
  count = var.manage_dns ? 1 : 0
  name  = var.domain
}

resource "digitalocean_record" "root" {
  count  = var.manage_dns ? 1 : 0
  domain = data.digitalocean_domain.main[0].name
  type   = "A"
  name   = "@"
  value  = digitalocean_droplet.main.ipv4_address
  ttl    = 300
}

resource "digitalocean_record" "www" {
  count  = var.manage_dns ? 1 : 0
  domain = data.digitalocean_domain.main[0].name
  type   = "A"
  name   = "www"
  value  = digitalocean_droplet.main.ipv4_address
  ttl    = 300
}

resource "digitalocean_record" "apps" {
  count  = var.manage_dns ? 1 : 0
  domain = data.digitalocean_domain.main[0].name
  type   = "A"
  name   = "apps"
  value  = digitalocean_droplet.main.ipv4_address
  ttl    = 300
}
