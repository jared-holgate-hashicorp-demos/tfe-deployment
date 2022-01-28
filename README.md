## License File
Run these command to compress and base64 your license file before storing in the `tfe_license` variable in Terraform Cloud;

1. `tar -zcvf license.tar.gz license.rli` - IMPORTANT! The code expects the license file to be called license.rli!
2. `cat license.tar.gz | base64 > base64.txt`
3. Now store the contents of base64.txt in your variable.
