locals {
  tfe_script_automated_external_services = <<-EOF
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

  tfe_config_automated_external_services_replicated = <<-EOF
    {
        "DaemonAuthenticationType":     "password",
        "DaemonAuthenticationPassword": "${random_password.replicated.result}",
        "TlsBootstrapType":             "self-signed",
        "BypassPreflightChecks":        true,
        "ImportSettingsFrom":           "/etc/tfe_settings.json",
        "LicenseFileLocation":          "/etc/license.rli"
    }
EOF

  tfe_config_automated_external_services_tfe = <<-EOF
    {
        "aws_instance_profile": {
            "value": "1"
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
        "pg_dbname": {
            "value": "tfedb"
        },
        "pg_extra_params": {
            "value": "sslmode=require"
        },
        "pg_netloc": {
            "value": "${aws_db_instance.postgresql.endpoint}"
        },
        "pg_password": {
            "value": "${random_password.rds_password.result}"
        },
        "pg_user": {
            "value": "${random_password.rds_username.result}"
        },
        "placement": {
            "value": "placement_s3"
        },
        "production_type": {
            "value": "external"
        },
        "s3_bucket": {
            "value": "${aws_s3_bucket.tfe_data_bucket.id}"
        },
        "s3_region": {
            "value": "${aws_s3_bucket.tfe_data_bucket.region}"
        },
        "s3_sse": {
            "value": "aws:kms"
        },
        "s3_sse_kms_key_id": {
            "value": "${aws_kms_key.data.arn}"
        }
    }
EOF
}