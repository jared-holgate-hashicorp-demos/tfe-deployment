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

  tfe_script = <<EOF
#!/bin/bash
apt update -y
apt install ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --no-tty --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update
apt install docker-ce docker-ce-cli containerd.io
apt install containerd
curl https://install.terraform.io/ptfe/stable | sudo bash
EOF 
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

  user_data = var.create_hello_world ? format(local.hello_word_script, count.index) : local.tfe_script

  tags = {
    Name = "${var.friendly_name_prefix}-tfe-server-${count.index}"
  }
}

resource "aws_ebs_volume" "tfe" {
  count             = 2
  availability_zone = data.aws_availability_zones.available.names[count.index]
  size              = 200

  tags = {
    Name = "${var.friendly_name_prefix}-tfe-ebs-${count.index}"
  }
}

resource "aws_volume_attachment" "tfe" {
  count       = 2
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.tfe[count.index].id
  instance_id = aws_instance.tfe[count.index].id
}