locals {
  hello_word_script = <<EOF
#!/bin/bash
apt update -y
apt install apache2 -y
systemctl start apache2.service
cd /var/www/html
echo "<html><body><h1>Hello World - Server %s</h1></body></html>" > index.html 
EOF 
}