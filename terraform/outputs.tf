output "droplet_id" {
  value = digitalocean_droplet.main.id
}

output "droplet_ipv4" {
  value = digitalocean_droplet.main.ipv4_address
}

output "droplet_urn" {
  value = digitalocean_droplet.main.urn
}

output "firewall_id" {
  value = digitalocean_firewall.web.id
}
