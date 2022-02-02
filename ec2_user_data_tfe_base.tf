resource "random_password" "replicated" {
  length      = 20
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
  number      = true
  lower       = true
  upper       = true
  special     = false
}

resource "random_password" "tfe" {
  length      = 20
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
  number      = true
  lower       = true
  upper       = true
  special     = false
}

locals {
  tfe_script_base = <<-EOF
#!/bin/bash
apt update -y

echo "Mount TFE Volume"

volumeData=$(lsblk | grep nvme1n1)
until [ ! -z "$volumeData" ]; do
  echo "Looking for volume..."
  sleep 5
  volumeData=$(lsblk | grep nvme1n1)
done

echo "Found the volume, formatting it"
mkfs -t xfs -f /dev/nvme1n1

mountId=$(blkid | grep '/dev/nvme1n1*' | cut -f 2 -d '"')
until [ ! -z "$mountId" ]; do
  echo "Looking for mount id..."
  sleep 5
  mountId=$(blkid | grep '/dev/nvme1n1*' | cut -f 2 -d '"')
done

echo "Found mount id, mounting it and adding to fstab"

mkdir /tfe
mount /dev/nvme1n1 /tfe
echo "UUID=$mountId  /tfe  xfs  defaults,nofail  0  2" >> /etc/fstab

eacho "Finished mounting tfe volume"
EOF 

  tfe_script_install = <<-EOF
echo "Installing TFE"
curl https://install.terraform.io/ptfe/stable | sudo bash
EOF

  tfe_script_get_license = <<-EOF
echo "Get TFE Licnese"
tfeLicense="${var.tfe_license}"
echo "$tfeLicense" > /etc/license.txt
cat /etc/license.txt | base64 --decode > /etc/license.tar.gz
tar -xvf /etc/license.tar.gz -C /etc
rm /etc/license.txt
rm /etc/license.tar.gz
EOF 

  final_tfe_script = (var.install_type == "apache_hello_world" ? local.hello_word_script :
    (var.install_type == "tfe_manual" ? "${local.tfe_script_base}${local.tfe_script_install}" :
      (var.install_type == "tfe_automated_mounted_disk" ? "${local.tfe_script_base}${local.tfe_script_get_license}${local.tfe_script_automated_mounted_disk}" :
        (var.install_type == "tfe_automated_external_services" ? "${local.tfe_script_base}${local.tfe_script_get_license}${local.tfe_script_automated_external_services}" :
          (var.install_type == "tfe_automated_active_active" ? "${local.tfe_script_base}${local.tfe_script_get_license}${local.tfe_script_automated_active_active}" :
  "")))))
}