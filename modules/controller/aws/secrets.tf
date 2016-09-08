resource vaultx_secret_backend pki {
    type = "pki"
    path = "kube-${var.env}"
    default_lease_ttl = "24h"
    max_lease_ttl = "43800h"
}

resource vaultx_secret_write_only pki_config {
    path = "kube-${var.env}/config/urls"

    data {
        issuing_certificates = "${replace(var.vault_address, "/^https://(.*)$/", "$1")}/v1/kube-${var.env}/ca"
        crl_distribution_points = "${replace(var.vault_address, "/^https://(.*)$/", "$1")}/v1/kube-${var.env}/crl"
        ocsp_servers = ""
    }

    depends_on = [ "vaultx_secret_backend.pki" ]
}

resource vaultx_secret_write_only pki_init {
    //path = "${var.env}-kube/intermediate/generate/internal"
    path = "kube-${var.env}/root/generate/internal"

    data {
        common_name = "${var.fqdn} CA"
        key_type = "ec"
        key_bits = "521"
        ttl = "43800h"
        csr = ""
    }

    depends_on = [ "vaultx_secret_write_only.pki_config" ]
    lifecycle { ignore_changes = [ "data" ] }
}

// UNUSED UNTIL USING SIGNED ROOT
/*
resource vaultx_secret_write_only pki_sign {
    path = "${var.vault_pki_root_mount}/root/sign-intermediate"

    data {
        ttl = "43800h"
        csr = "${vaultx_secret_write_only.pki_init.data.csr}"
        common_name = "${var.fqdn} CA"
        certificate = ""
    }

    depends_on = [ "vaultx_secret_write_only.pki_init" ]
}

resource vaultx_secret_write_only pki_signed {
    path = "kube-${var.env}/intermediate/set-signed"

    data {
        certificate = "${vaultx_secret_write_only.pki_sign.data.certificate}"
    }

    depends_on = [ "vaultx_secret_write_only.pki_sign" ]
}
*/
// UNUSED UNTIL USING SIGNED ROOT

resource template_file pki_mount {
    template = "${vaultx_secret_backend.pki.path}"
    depends_on = [ "vaultx_secret_write_only.pki_init" ]
}

resource tls_private_key service_account_key {
    algorithm = "RSA"
}

resource vaultx_secret service_account {
    path = "secret/kube-${var.env}/service_account"

    data {
        public_key = "${tls_private_key.service_account_key.public_key_pem}"
        private_key = "${tls_private_key.service_account_key.private_key_pem}"
    }
}

resource vaultx_secret_write_only controller_role {
    path = "kube-${var.env}/roles/controller"

    data {
        allowed_domains = "${var.fqdn},controller,kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster.local,ec2.internal"
        allow_bare_domains = true
        allow_subdomains = true
        allow_localhost = false
        key_type = "ec"
        key_bits = "256"
        max_ttl = "48h"
    }

    depends_on = [ "vaultx_secret_write_only.pki_init" ]
}

resource vaultx_policy controller {
    name = "${var.env}-kube-controller"

    rules = <<EOF
path "kube-${var.env}/issue/controller" {
    capabilities = [ "create", "read", "update", "list" ]
}
path "${vaultx_secret.service_account.path}" {
    capabilities = [ "read" ]
}
EOF

    depends_on = [ "vaultx_secret_write_only.pki_init" ]
}

resource vaultx_ec2_role role {
    role = "${vaultx_policy.controller.name}"

    policies = [ "${vaultx_policy.controller.name}" ]
    bound_ami_id = "${var.image_id}"
    role_tag_key = "VaultRole"
    max_ttl = "48h"
}

resource vaultx_ec2_role_tag role_tag {
    role = "${vaultx_ec2_role.role.role}"
    policies = [ "${vaultx_policy.controller.name}" ]
}

data vaultx_secret oidc {
    path = "${var.oidc_vault_path}"
}
