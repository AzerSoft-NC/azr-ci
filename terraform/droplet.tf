# Import: terraform import digitalocean_droplet.main <droplet_id>
# Fill droplet_size and droplet_image from the DO console or `doctl compute droplet get`.

resource "digitalocean_droplet" "main" {
  name   = var.droplet_name
  region = var.region
  size   = var.droplet_size
  image  = var.droplet_image

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [size, image, region]
  }
}
