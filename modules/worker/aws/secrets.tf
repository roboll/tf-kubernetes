resource vaultx_secret_write_only worker_role {
    path = "${var.vault_pki_backend}/roles/worker-${var.worker_class}"

    data {
        allowed_domains = "worker,ec2.internal"
        allow_bare_domains = true
        allow_subdomains = true
        allow_localhost = false
        key_type = "ec"
        key_bits = "256"
        max_ttl = "48h"
    }
}

resource vaultx_policy worker {
    name = "${var.env}-kube-worker-${var.worker_class}"

    rules = <<EOF
path "${var.vault_pki_backend}/issue/worker-${var.worker_class}" {
    capabilities = [ "create", "read", "update", "list" ]
}
EOF
}

resource vaultx_ec2_role role {
    role = "${vaultx_policy.worker.name}"

    policies = [ "${vaultx_policy.worker.name}" ]
    bound_ami_id = "${var.image_id}"
    role_tag_key = "VaultRole"
    max_ttl = "48h"
}

resource vaultx_ec2_role_tag role_tag {
    role = "${vaultx_ec2_role.role.role}"
    policies = [ "${vaultx_policy.worker.name}" ]
}
