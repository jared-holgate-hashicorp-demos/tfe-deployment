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
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-20220606"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

locals {
  bastion_ip        = cidrhost(var.network_public_subnet_cidrs[0], 101)
  tfe_ips           = [for i, subnet in var.network_private_subnet_cidrs : cidrhost(subnet, i + 101)]
  tfe_instance_size = var.ec2_instance_type
}

resource "aws_eip" "bastion" {
  vpc = true

  instance                  = aws_instance.bastion.id
  associate_with_private_ip = local.bastion_ip

  tags = {
    Name = "${var.friendly_name_prefix}-bastion-eip"
  }
}

resource "aws_network_interface" "bastion" {
  subnet_id       = aws_subnet.public[0].id
  private_ips     = [local.bastion_ip]
  security_groups = [aws_security_group.bastion.id]
  depends_on      = [aws_route_table.internet]

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

  user_data_replace_on_change = true
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

resource "aws_network_interface" "tfe" {
  count           = 2
  subnet_id       = aws_subnet.private[count.index].id
  private_ips     = [local.tfe_ips[count.index]]
  security_groups = [aws_security_group.tfe.id]
  depends_on      = [aws_route_table.private]

  tags = {
    Name = "${var.friendly_name_prefix}-tfe-network-interface-${count.index + 1}"
  }
}

resource "aws_instance" "tfe" {
  count                = 2
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = local.tfe_instance_size
  key_name             = aws_key_pair.main.key_name
  availability_zone    = data.aws_availability_zones.available.names[count.index]
  iam_instance_profile = aws_iam_instance_profile.tfe.id

  network_interface {
    network_interface_id = aws_network_interface.tfe[count.index].id
    device_index         = 0
  }

  root_block_device {
    volume_size = 100
    tags = {
      Name = "${var.friendly_name_prefix}-tfe-server-ebs-root-${count.index + 1}"
    }
  }

  user_data_replace_on_change = true
  user_data = format("%s%s", replace(local.final_tfe_script, "127.0.0.1", local.tfe_ips[count.index]), count.index == 0 && var.install_type != "tfe_manual" && var.install_type != "apache_hello_world" ? local.tfe_script_setup_admin_user : "")

  tags = {
    Name = "${var.friendly_name_prefix}-tfe-server-${count.index + 1}"
  }
}

resource "aws_ebs_volume" "tfe" {
  count             = 2
  availability_zone = data.aws_availability_zones.available.names[count.index]
  size              = 200

  tags = {
    Name = "${var.friendly_name_prefix}-tfe-server-ebs-tfe-${count.index + 1}"
  }
}

resource "aws_volume_attachment" "tfe" {
  count       = 2
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.tfe[count.index].id
  instance_id = aws_instance.tfe[count.index].id
}
