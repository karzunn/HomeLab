terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.69.1"
    }
  }
}

provider "proxmox" {
  endpoint = "https://192.168.1.2:8006"
  insecure = true

  ssh {
    agent = true
  }
}