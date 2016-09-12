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
        allowed_domains = "${var.fqdn},kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster.local"
        allow_bare_domains = true
        allow_subdomains = false
        allow_localhost = false
        key_type = "ec"
        key_bits = "256"
        max_ttl = "48h"
    }

    depends_on = [ "vaultx_secret.kube_pki_init" ]
}

resource vaultx_secret kubelet_role {
    path = "${var.env}-kube/roles/kubelet"
    ignore_read = true

    data {
        allowed_domains = "kubelet"
        allow_bare_domains = true
        allow_subdomains = false
        allow_localhost = false
        key_type = "ec"
        key_bits = "256"
        max_ttl = "48h"
    }

    depends_on = [ "vaultx_secret.kube_pki_init" ]
}

resource vaultx_secret kube_user_role {
    path = "${var.env}-kube/roles/user"
    ignore_read = true

    data {
        allowed_domains = "kube-users.local"
        allow_subdomains = true
        allow_localhost = false
        server_flag = false
        key_type = "ec"
        key_bits = "256"
        max_ttl = "48h"
    }

    depends_on = [ "vaultx_secret.kube_pki_init" ]
}

resource vaultx_policy kube_user {
    name = "${var.env}-kube-user"

    rules = <<EOF
path "${var.env}-kube/issue/user" {
    capabilities = [ "create", "read", "update", "list" ]
}
EOF

    depends_on = [
        "vaultx_secret.kube_pki_init"
    ]
}

resource vaultx_secret kube_admin_role {
    path = "${var.env}-kube/roles/admin"
    ignore_read = true

    data {
        allowed_domains = "admin"
        allow_bare_domains = true
        allow_subdomains = false
        allow_localhost = false
        server_flag = false
        key_type = "ec"
        key_bits = "256"
        max_ttl = "48h"
    }

    depends_on = [ "vaultx_secret.kube_pki_init" ]
}

resource vaultx_policy kube_admin {
    name = "${var.env}-kube-admin"

    rules = <<EOF
path "${var.env}-kube/issue/admin" {
    capabilities = [ "create", "read", "update", "list" ]
}
EOF

    depends_on = [
        "vaultx_secret.kube_pki_init"
    ]
}

resource vaultx_secret etcd_controller_role {
    path = "${var.env}-kube-etcd/roles/controller"
    ignore_read = true

    data {
        allowed_domains = "controller"
        allow_bare_domains = true
        allow_subdomains = false
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
        bound_iam_role_arn = "${aws_iam_instance_profile.kube_controller.arn}"
        max_ttl = "48h"
    }
}

data vaultx_secret oidc {
    path = "${var.oidc_vault_path}"
}
