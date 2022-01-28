locals {
  tfe_script_automated_external_services = <<-EOF
echo "Configuring TFE with Mounted Disk"
$tfeConfigFile="${local.tfe_config_automated_external_services_tfe}"
echo "$tfeConfigFile" > /etc/tfe_settings.json
$replicatedConfigFile="${local.tfe_config_automated_external_services_replicated}"
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
  "https://${var.tfe_sub_domain}.${var.root_domain}/admin/initial-admin-user?token=$initial_token"
EOF

  tfe_config_automated_external_services_replicated = <<-EOF
{
    "DaemonAuthenticationType":     "password",
    "DaemonAuthenticationPassword": "${random_password.replicated.result}",
    "TlsBootstrapType":             "self-signed",
    "BypassPreflightChecks":        true,
    "ImportSettingsFrom":           "/etc/settings.json",
    "LicenseFileLocation":          "/etc/license.rli"
}
EOF

  tfe_config_automated_external_services_tfe = <<-EOF
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
}