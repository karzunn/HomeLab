data "proxmox_virtual_environment_vms" "existing_vms" {}

data "http" "ssh_keys" {
  url = "https://github.com/karzunn.keys"
}

resource "proxmox_virtual_environment_file" "cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "pve"

  source_raw {
    # Doing it this way because we need to install qemu-guest-agent, 
    data      = <<EOF
#cloud-config
chpasswd:
  list: |
    carson:carson
  expire: false
hostname: debian
packages:
  - qemu-guest-agent
users:
  - name: carson
    groups: wheel
    shell: /bin/bash
    ssh_authorized_keys:
      ${yamlencode([trimspace(data.http.ssh_keys.response_body)])}
    sudo: ALL=(ALL) NOPASSWD:ALL
runcmd:
  - ["/usr/sbin/reboot"]
EOF
    file_name = "debian.cloud-config.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "debian_server" {
  initialization {

    user_data_file_id = proxmox_virtual_environment_file.cloud_config.id

    dns {
      servers = ["192.168.1.254"]
    }
    ip_config {
      ipv4 {
        address = "192.168.1.3/24"
        gateway = "192.168.1.254"
      }
    }
  }
  agent {
    enabled = true # this will cause terraform operations to hang if the Qemu agent doesn't install correctly!
  }
  name      = "debian"
  tags      = ["debian", "tofu"]
  bios      = "ovmf"
  node_name = "pve"
  machine   = "q35"
  memory {
    dedicated = 2048
  }

  cpu {
    type  = "host"
    cores = "2"
  }

  disk {
    interface = "scsi0"
    size      = 20
  }
  # Volume for Ceph
  disk {
    interface   = "scsi1"
    size        = 100
    file_format = "raw"
  }
  efi_disk {
    type        = "4m"
    file_format = "raw"
  }
  clone {
    vm_id = lookup(
      zipmap(
        data.proxmox_virtual_environment_vms.existing_vms.vms[*].name,
        data.proxmox_virtual_environment_vms.existing_vms.vms[*].vm_id
      ),
      "debian-latest"
    )
    full = true
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }

  tpm_state {
    version = "v2.0"
  }
  vga {
    memory = 16
    type   = "std"
  }
  # serial_device {}
}