resource "tls_private_key" "main" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "main" {
  key_name   = "main"
  public_key = tls_private_key.main.public_key_openssh
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_eip" "bastion" {
  vpc = true

  instance                  = aws_instance.bastion.id
  associate_with_private_ip = "10.0.0.101"
  depends_on                = [aws_internet_gateway.main]

  tags = {
    Name = "${var.friendly_name_prefix}-bastion-eip"
  }
}

resource "aws_network_interface" "bastion" {
  subnet_id       = aws_subnet.public[0].id
  private_ips     = ["10.0.0.101"]
  security_groups = [aws_security_group.bastion.id]

  tags = {
    Name = "${var.friendly_name_prefix}-bastion-network-interface"
  }
}

resource "aws_instance" "bastion" {
  ami               = data.aws_ami.ubuntu.id
  instance_type     = "t2.micro"
  availability_zone = data.aws_availability_zones.available.names[0]

  network_interface {
    network_interface_id = aws_network_interface.bastion.id
    device_index         = 0
  }

  user_data = <<EOF
#!/bin/bash

privateKey="${tls_private_key.main.private_key_pem}"
echo "$privateKey" > tfe.pem
chmod 400 tfe.pem
EOF

  tags = {
    Name = "${var.friendly_name_prefix}-bastion-server"
  }
}

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
  hello_word_script = <<EOF
#!/bin/bash
apt update -y
apt install apache2 -y
systemctl start apache2.service
cd /var/www/html
echo "<html><body><h1>Hello World - Server %s</h1></body></html>" > index.html 
EOF 

  tfe_script_base = <<-EOF
#!/bin/bash
apt update -y

echo "Mount TFE Volume"
mountId=$(blkid | grep '/dev/nvme1n1*' | cut -f 2 -d '"')
until [ ! -z "$mountId" ]; do
  sleep 5
  mountId=$(blkid | grep '/dev/nvme1n1*' | cut -f 2 -d '"')
done
mkdir /tfe
mount /dev/nvme1n1 /tfe
echo "UUID=$mountId  /tfe  xfs  defaults,nofail  0  2" >> /etc/fstab
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
tar -xvf /etc/license.tar.gz
EOF 

  tfe_script_automated_mounted_disk = <<-EOF
echo "Configuring TFE with Mounted Disk"
$tfeConfigFile="${local.tfe_config_automated_mounted_disk_tfe}"
echo "$tfeConfigFile" > /etc/tfe_settings.json
$replicatedConfigFile="${local.tfe_config_automated_mounted_disk_replicated}"
echo "$replicatedConfigFile" > /etc/replicated.conf
${local.tfe_script_install}
while ! curl -ksfS --connect-timeout 5 https://${var.tfe_sub_domain}.${var.root_domain}/_health_check; do
    sleep 5
done
initial_token=$(replicated admin retrieve-iact | tr -d '\r')
curl \
  --header "Content-Type: application/json" \
  --request POST \
  --data '{ "username": "admin", "email": "demo@hashicorp.com", "password": "${random_password.tfe.result}"
}' \
  "https://tfe.company.com/admin/initial-admin-user?token=$initial_token"
EOF

  tfe_config_automated_mounted_disk_replicated = <<-EOF
{
    "DaemonAuthenticationType":     "password",
    "DaemonAuthenticationPassword": "${random_password.replicated.result}",
    "TlsBootstrapType":             "self-signed",
    "BypassPreflightChecks":        true,
    "ImportSettingsFrom":           "/etc/settings.json",
    "LicenseFileLocation":          "/etc/license.rli"
}
EOF

  tfe_config_automated_mounted_disk_tfe = <<-EOF
{
    "disk_path": {
        "value": "/tfe"
    },
    "enc_password": {
        "value": "${random_password.replicated.result}"
    },
    "hostname": {
        "value": "tfe.hashicorpdemo.net"
    },
    "installation_type": {
        "value": "production"
    },
    "production_type": {
        "value": "disk"
    }
}
EOF

  tfe_script_automated_external_services = <<-EOF
echo "Configuring TFE with External Services"


EOF

  tfe_script_automated_active_active = <<-EOF
echo "Configuring TFE with Active/Active" 


EOF

  final_tfe_script = (var.install_type == "apache_hello_world" ? local.hello_word_script :
    (var.install_type == "tfe_manual" ? "${local.tfe_script_base}${local.tfe_script_install}" :
      (var.install_type == "tfe_automated_mounted_disk" ? "${local.tfe_script_base}${local.tfe_script_get_license}${local.tfe_script_automated_mounted_disk}${local.tfe_script_install}" :
        (var.install_type == "tfe_automated_external_services" ? "${local.tfe_script_base}${local.tfe_script_get_license}${local.tfe_script_automated_external_services}${local.tfe_script_install}" :
  (var.install_type == "tfe_automated_active_active" ? "${local.tfe_script_base}${local.tfe_script_get_license}${local.tfe_script_automated_active_active}${local.tfe_script_install}" : "")))))
}

resource "aws_network_interface" "tfe" {
  count           = 2
  subnet_id       = aws_subnet.private[count.index].id
  private_ips     = ["10.0.${count.index + 100}.10${count.index}"]
  security_groups = [aws_security_group.tfe.id]

  tags = {
    Name = "${var.friendly_name_prefix}-tfe-network-interface-${count.index}"
  }
}

resource "aws_instance" "tfe" {
  count             = 2
  ami               = data.aws_ami.ubuntu.id
  instance_type     = "m5.xlarge"
  key_name          = aws_key_pair.main.key_name
  availability_zone = data.aws_availability_zones.available.names[count.index]

  network_interface {
    network_interface_id = aws_network_interface.tfe[count.index].id
    device_index         = 0
  }

  root_block_device {
    volume_size = 100
    tags = {
      Name = "${var.friendly_name_prefix}-tfe-server-ebs-root-${count.index}"
    }
  }

  user_data = local.final_tfe_script

  tags = {
    Name = "${var.friendly_name_prefix}-tfe-server-${count.index}"
  }
}

resource "aws_ebs_volume" "tfe" {
  count             = 2
  availability_zone = data.aws_availability_zones.available.names[count.index]
  size              = 200

  tags = {
    Name = "${var.friendly_name_prefix}-tfe-server-ebs-tfe-${count.index}"
  }
}

resource "aws_volume_attachment" "tfe" {
  count       = 2
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.tfe[count.index].id
  instance_id = aws_instance.tfe[count.index].id
}