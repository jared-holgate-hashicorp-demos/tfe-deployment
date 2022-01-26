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

resource "aws_network_interface" "bastion" {
   subnet_id   = aws_subnet.public[0].id
   private_ips = ["10.0.0.101"]
   security_groups = [ aws_security_group.bastion.id ]
   
  tags = {
    Name = "${var.friendly_name_prefix}-bastion-network-interface"
  }
}

resource "aws_instance" "bastion" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  network_interface {
    network_interface_id = aws_network_interface.bastion.id
    device_index         = 0
  }

  provisioner "local-exec" { 
    command = "echo '${tls_private_key.main.private_key_pem}' > ./tfe.pem"
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

resource "aws_network_interface" "tfe" {
  count = 2
  subnet_id   = aws_subnet.private.id
  private_ips = ["10.0.2.10${count.index}"]
  security_groups = [ aws_security_group.tfe.id ] 

  tags = {
    Name = "${var.friendly_name_prefix}-tfe-network-interface-${count.index}"
  }
}

resource "aws_instance" "tfe" {
  count = 2
  ami           = data.aws_ami.ubuntu.id
  instance_type = "m5.xlarge"
  key_name      = aws_key_pair.main.key_name

  network_interface {
    network_interface_id = aws_network_interface.tfe[count.index].id
    device_index         = 0
  }

  tags = {
    Name = "${var.friendly_name_prefix}-tfe-server-${count.index}"
  }
}