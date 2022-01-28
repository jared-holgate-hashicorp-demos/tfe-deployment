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
echo "$tfeLicense" > license.txt
cat license.txt | base64 --decode > license.tar.gz
tar -xvf license.tar.gz
EOF 

  tfe_script_automated_mounted_disk = <<-EOF
echo "Configuring TFE with Mounted Disk"


EOF

  tfe_script_automated_external_services = <<-EOF
echo "Configuring TFE with External Services"


EOF

  tfe_script_automated_active_active = <<-EOF
echo "Configuring TFE with Active/Active" 


EOF

  final_tfe_script = var.install_type == ("apache_hello_world" ? local.hello_word_script :
    (var.install_type == "tfe_manual" ? "${local.tfe_script_base}${local.tfe_script_install}" :
      (var.install_type == "tfe_automated_mounted_disk" ? "${local.tfe_script_base}${local.tfe_script_install}${local.tfe_script_get_license}${local.tfe_script_automated_mounted_disk}" :
        (var.install_type == "tfe_automated_external_services" ? "${local.tfe_script_base}${local.tfe_script_install}${local.tfe_script_get_license}${local.tfe_script_automated_external_services}" :
  (var.install_type == "tfe_automated_active_active" ? "${local.tfe_script_base}${local.tfe_script_install}${local.tfe_script_get_license}${local.tfe_script_automated_active_active}" : "")))))
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