resource vaultx_secret_backend kube_pki {
    type = "pki"
    path = "${var.env}-kube"
    default_lease_ttl = "24h"
    max_lease_ttl = "43800h"
}

resource vaultx_secret_backend etcd_pki {
    type = "pki"
    path = "${var.env}-kube-etcd"
    default_lease_ttl = "24h"
    max_lease_ttl = "43800h"
}

resource vaultx_secret kube_pki_config {
    path = "${var.env}-kube/config/urls"
    ignore_read = true
    ignore_delete = true

    data {
        issuing_certificates = "${replace(var.vault_address, "/^https://(.*)$/", "$1")}/v1/${var.env}-kube/ca"
        crl_distribution_points = "${replace(var.vault_address, "/^https://(.*)$/", "$1")}/v1/${var.env}-kube/crl"
        ocsp_servers = ""
    }

    depends_on = [ "vaultx_secret_backend.kube_pki" ]
}

resource vaultx_secret etcd_pki_config {
    path = "${var.env}-kube-etcd/config/urls"
    ignore_read = true
    ignore_delete = true

    data {
        issuing_certificates = "${replace(var.vault_address, "/^https://(.*)$/", "$1")}/v1/${var.env}-kube-etcd/ca"
        crl_distribution_points = "${replace(var.vault_address, "/^https://(.*)$/", "$1")}/v1/${var.env}-kube-etcd/crl"
        ocsp_servers = ""
    }

    depends_on = [ "vaultx_secret_backend.etcd_pki" ]
}

resource vaultx_secret kube_pki_init {
    path = "${var.env}-kube/root/generate/internal"
    ignore_read = true
    ignore_delete = true

    data {
        common_name = "Kubernetes ${var.env} CA"
        key_type = "ec"
        key_bits = "521"
        ttl = "43800h"
        csr = ""
    }

    depends_on = [ "vaultx_secret.kube_pki_config" ]
    lifecycle { ignore_changes = [ "data" ] }
}

resource vaultx_secret etcd_pki_init {
    path = "${var.env}-kube-etcd/root/generate/internal"
    ignore_read = true
    ignore_delete = true

    data {
        common_name = "Kubernetes etcd ${var.fqdn} CA"
        key_type = "ec"
        key_bits = "521"
        ttl = "43800h"
        csr = ""
    }

    depends_on = [ "vaultx_secret.etcd_pki_config" ]
    lifecycle { ignore_changes = [ "data" ] }
}

resource null_resource pki_mount {
    triggers {
        kube_path = "${vaultx_secret_backend.kube_pki.path}"
        etcd_path = "${vaultx_secret_backend.etcd_pki.path}"
    }

    depends_on = [
        "vaultx_secret.kube_pki_init",
        "vaultx_secret.etcd_pki_init"
    ]
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

resource vaultx_secret kube_controller_role {
    path = "${var.env}-kube/roles/controller"
    ignore_read = true

    data {
        allowed_domains = "${var.fqdn},controller,kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster.local,ec2.internal"
        allow_bare_domains = true
        allow_subdomains = true
        allow_localhost = false
        key_type = "ec"
        key_bits = "256"
        max_ttl = "48h"
    }

    depends_on = [ "vaultx_secret.kube_pki_init" ]
}

resource vaultx_secret etcd_controller_role {
    path = "${var.env}-kube-etcd/roles/controller"
    ignore_read = true

    data {
        allowed_domains = "${var.fqdn},controller,kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster.local,ec2.internal"
        allow_bare_domains = true
        allow_subdomains = true
        allow_localhost = false
        key_type = "ec"
        key_bits = "256"
        max_ttl = "48h"
    }

    depends_on = [ "vaultx_secret.etcd_pki_init" ]
}


resource vaultx_policy controller {
    name = "${var.env}-kube-controller"

    rules = <<EOF
path "${var.env}-kube/issue/controller" {
    capabilities = [ "create", "read", "update", "list" ]
}
path "${var.env}-kube-etcd/issue/controller" {
    capabilities = [ "create", "read", "update", "list" ]
}
path "${vaultx_secret.service_account.path}" {
    capabilities = [ "read" ]
}
EOF

    depends_on = [
        "vaultx_secret.kube_pki_init",
        "vaultx_secret.etcd_pki_init"
    ]
}

resource vaultx_secret role {
    path = "auth/aws-ec2/role/${vaultx_policy.controller.name}"
    ignore_read = true

    data {
        policies = "${vaultx_policy.controller.name}"
        bound_ami_id = "${var.image_id}"
        bound_iam_role_arn = "${aws_iam_role.kube_controller.arn}"
        role_tag = "VaultRole"
        max_ttl = "48h"
    }
}

resource vaultx_secret role_tag {
    path = "auth/aws-ec2/role/${vaultx_policy.controller.name}/tag"
    ignore_read = true
    ignore_delete = true

    data {
        role = "${vaultx_policy.controller.name}"
        policies = "${vaultx_policy.controller.name}"
        tag_data = ""
    }

    lifecycle { ignore_changes = [ "data" ] }
    depends_on = [ "vaultx_secret.role" ]
}

data vaultx_secret oidc {
    path = "${var.oidc_vault_path}"
}
