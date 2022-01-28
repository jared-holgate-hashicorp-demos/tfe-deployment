locals {
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
}