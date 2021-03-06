resource "random_password" "replicated" {
  length      = 20
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
  numeric     = true
  lower       = true
  upper       = true
  special     = false
}

resource "random_password" "tfe" {
  length      = 20
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
  numeric     = true
  lower       = true
  upper       = true
  special     = false
}

locals {
  tfe_volume_name = local.tfe_instance_size == "t2.large" ? "xvdh" : "nvme1n1"
  tfe_script_base = <<-EOF
    #!/bin/bash
    apt update -y

    echo "Mount TFE Volume"

    volumeData=$(lsblk | grep ${local.tfe_volume_name})
    until [ ! -z "$volumeData" ]; do
      echo "Looking for volume..."
      sleep 5
      volumeData=$(lsblk | grep ${local.tfe_volume_name})
    done

    echo "Found the volume, formatting it"
    mkfs -t xfs -f /dev/${local.tfe_volume_name}

    mountId=$(blkid | grep '/dev/${local.tfe_volume_name}*' | cut -f 2 -d '"')
    until [ ! -z "$mountId" ]; do
      echo "Looking for mount id..."
      sleep 5
      mountId=$(blkid | grep '/dev/${local.tfe_volume_name}*' | cut -f 2 -d '"')
    done

    echo "Found mount id, mounting it and adding to fstab"

    mkdir /tfe
    mount /dev/${local.tfe_volume_name} /tfe
    echo "UUID=$mountId  /tfe  xfs  defaults,nofail  0  2" >> /etc/fstab

    echo "Finished mounting tfe volume"
EOF 

  tfe_script_install = <<-EOF
    echo "Installing TFE"
    curl https://install.terraform.io/ptfe/stable | sudo bash -s no-proxy private-address=127.0.0.1 public-address=127.0.0.1${var.install_type == "tfe_automated_active_active" ? " disable-replicated-ui" : ""}
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

  tfe_script_setup_admin_user = <<-EOF
    echo "Creating default TFE login"

    while ! curl -ksfS --connect-timeout 5 https://localhost/_health_check; do
        currentDate=`date +"%Y-%m-%d %T"`
        echo "$currentDate - Waiting for TFE to be ready"
        sleep 5
    done

    initialToken=$(replicated admin --tty=0 retrieve-iact | tr -d '\r')
    
    while ! curl -v -k -L --post301 --header "Content-Type: application/json" --request POST --data '{ "username": "admin", "email": "demo@hashicorp.com", "password": "${random_password.tfe.result}" }' https://localhost/admin/initial-admin-user?token=$initialToken; do
        currentDate=`date +"%Y-%m-%d %T"`
        echo "$currentDate - Attempting to create initial admin user"
        sleep 5
    done
EOF

  final_tfe_script = (var.install_type == "apache_hello_world" ? local.hello_word_script :
    (var.install_type == "tfe_manual" ? "${local.tfe_script_base}${local.tfe_script_install}" :
      (var.install_type == "tfe_automated_mounted_disk" ? "${local.tfe_script_base}${local.tfe_script_get_license}${local.tfe_script_automated_mounted_disk}${local.tfe_script_install}" :
        (var.install_type == "tfe_automated_external_services" ? "${local.tfe_script_base}${local.tfe_script_get_license}${local.tfe_script_automated_external_services}${local.tfe_script_install}" :
          (var.install_type == "tfe_automated_active_active" ? "${local.tfe_script_base}${local.tfe_script_get_license}${local.tfe_script_automated_active_active}${local.tfe_script_install}" :
  "")))))
}
