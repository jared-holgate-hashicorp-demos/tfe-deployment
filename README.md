## License File
Run these command to compress and base64 your license file before storing in the `tfe_license` variable in Terraform Cloud;

1. `tar -zcvf license.tar.gz license.rli` - IMPORTANT! The code expects the license file to be called license.rli!
2. `cat license.tar.gz | base64 > base64.txt`
3. Now store the contents of base64.txt in your variable.

## Connecting via SSH

A bastion server is deployed into the public subnet. You'll need to connect to that and then connect to the TFE VM's.

1. Use  EC2 Instance Connect to connect to the bastion server.
2. Once connected, run this command to connect to one of the TFE VM's `sudo ssh ubuntu@#.#.#.# -i /tfe.pem`. The tfe.pem file is created for you as part of the deployment.
