locals {
  tfe_script_automated_active_active = <<-EOF
   echo "Configuring TFE with Mounted Disk"
    tfeConfigFile=$(cat <<-END
    ${local.tfe_config_automated_mounted_disk_tfe}
    END
    )
    echo "$tfeConfigFile" > /etc/tfe_settings.json

    replicatedConfigFile=$(cat <<-END
    ${local.tfe_config_automated_mounted_disk_replicated}
    END
    )
    echo "$replicatedConfigFile" > /etc/replicated.conf
EOF

  tfe_config_automated_active_active_replicated = <<-EOF
   {
        "DaemonAuthenticationType":     "password",
        "DaemonAuthenticationPassword": "${random_password.replicated.result}",
        "TlsBootstrapType":             "self-signed",
        "BypassPreflightChecks":        true,
        "ImportSettingsFrom":           "/etc/tfe_settings.json",
        "LicenseFileLocation":          "/etc/license.rli"
    }
EOF

  tfe_config_automated_active_active_tfe = <<-EOF
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