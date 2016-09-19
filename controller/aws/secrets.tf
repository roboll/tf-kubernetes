resource tls_private_key service_account_key {
    algorithm = "RSA"
}

resource vaultx_secret service_account_pubkey {
    path = "secret/kube-${var.env}/service_account/pubkey"

    data {
        public_key = "${tls_private_key.service_account_key.public_key_pem}"
    }
}

resource vaultx_secret service_account_privkey {
    path = "secret/kube-${var.env}/service_account/privkey"

    data {
        private_key = "${tls_private_key.service_account_key.private_key_pem}"
    }
}

resource vaultx_secret_backend kube_pki {
    type = "pki"
    path = "${var.env}-kube"
    default_lease_ttl = "24h"
    max_lease_ttl = "43800h"
}

resource vaultx_secret_backend kubelet_pki {
    type = "pki"
    path = "${var.env}-kube-kubelet"
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

resource vaultx_secret kubelet_pki_config {
    path = "${var.env}-kube-kubelet/config/urls"
    ignore_read = true
    ignore_delete = true

    data {
        issuing_certificates = "${replace(var.vault_address, "/^https://(.*)$/", "$1")}/v1/${var.env}-kube-kublet/ca"
        crl_distribution_points = "${replace(var.vault_address, "/^https://(.*)$/", "$1")}/v1/${var.env}-kube-kubelet/crl"
        ocsp_servers = ""
    }

    depends_on = [ "vaultx_secret_backend.kubelet_pki" ]
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
        common_name = "Kubernetes CA - ${var.env}"
        key_type = "ec"
        key_bits = "521"
        ttl = "43800h"
        csr = ""
    }

    depends_on = [ "vaultx_secret.kube_pki_config" ]
    lifecycle { ignore_changes = [ "data" ] }
}

resource vaultx_secret kubelet_pki_init {
    path = "${var.env}-kube-kubelet/root/generate/internal"
    ignore_read = true
    ignore_delete = true

    data {
        common_name = "Kubernetes CA - Kubelet ${var.env}"
        key_type = "ec"
        key_bits = "521"
        ttl = "43800h"
        csr = ""
    }

    depends_on = [ "vaultx_secret.kubelet_pki_config" ]
    lifecycle { ignore_changes = [ "data" ] }
}

resource vaultx_secret etcd_pki_init {
    path = "${var.env}-kube-etcd/root/generate/internal"
    ignore_read = true
    ignore_delete = true

    data {
        common_name = "Kubernetes CA - etcd ${var.fqdn}"
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
        kubelet_path = "${vaultx_secret_backend.kubelet_pki.path}"
        etcd_path = "${vaultx_secret_backend.etcd_pki.path}"
    }

    depends_on = [
        "vaultx_secret.kube_pki_init",
        "vaultx_secret.kubelet_pki_init",
        "vaultx_secret.etcd_pki_init"
    ]
}

resource vaultx_secret kube_apiserver_role {
    path = "${var.env}-kube/roles/apiserver"
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

resource vaultx_secret kube_flannel_role {
    path = "${var.env}-kube/roles/flannel"
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

resource vaultx_secret kube_controller_role {
    path = "${var.env}-kube/roles/controller"
    ignore_read = true

    data {
        allowed_domains = "controller"
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

resource vaultx_secret kube_bootstrap_role {
    path = "${var.env}-kube/roles/bootstrap"
    ignore_read = true

    data {
        allowed_domains = "bootstrap"
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

resource vaultx_secret kubelet_apiserver_role {
    path = "${var.env}-kube-kubelet/roles/apiserver"
    ignore_read = true

    data {
        allowed_domains = "kubernetes"
        allow_bare_domains = true
        allow_subdomains = true
        allow_any_name = true
        allow_localhost = false
        key_type = "ec"
        key_bits = "256"
        max_ttl = "48h"
    }

    depends_on = [ "vaultx_secret.kubelet_pki_init" ]
}

resource vaultx_secret kubelet_role {
    path = "${var.env}-kube-kubelet/roles/kubelet"
    ignore_read = true

    data {
        allowed_domains = "kubelet"
        allow_bare_domains = true
        allow_subdomains = true
        allow_any_name = true
        allow_localhost = false
        key_type = "ec"
        key_bits = "256"
        max_ttl = "48h"
    }

    depends_on = [ "vaultx_secret.kubelet_pki_init" ]
}

resource vaultx_secret etcd_apiserver_role {
    path = "${var.env}-kube-etcd/roles/apiserver"
    ignore_read = true

    data {
        allowed_domains = "controller"
        allow_bare_domains = true
        allow_subdomains = false
        allow_localhost = true
        key_type = "ec"
        key_bits = "256"
        max_ttl = "48h"
    }

    depends_on = [ "vaultx_secret.etcd_pki_init" ]
}

resource vaultx_secret etcd_role {
    path = "${var.env}-kube-etcd/roles/etcd"
    ignore_read = true

    data {
        allowed_domains = "controller"
        allow_bare_domains = true
        allow_subdomains = false
        allow_localhost = true
        key_type = "ec"
        key_bits = "256"
        max_ttl = "48h"
    }

    depends_on = [ "vaultx_secret.etcd_pki_init" ]
}

resource vaultx_policy controller_instance {
    name = "${var.env}-kube-controller"

    rules = <<EOF
path "${var.env}-kube/issue/apiserver" {
    capabilities = [ "create", "read", "update", "list" ]
}
path "${var.env}-kube/issue/flannel" {
    capabilities = [ "create", "read", "update", "list" ]
}
path "${var.env}-kube/issue/controller" {
    capabilities = [ "create", "read", "update", "list" ]
}
path "${var.env}-kube/issue/bootstrap" {
    capabilities = [ "create", "read", "update", "list" ]
}


path "${var.env}-kube-kubelet/issue/kubelet" {
    capabilities = [ "create", "read", "update", "list" ]
}
path "${var.env}-kube-kubelet/issue/apiserver" {
    capabilities = [ "create", "read", "update", "list" ]
}

path "${var.env}-kube-etcd/issue/apiserver" {
    capabilities = [ "create", "read", "update", "list" ]
}
path "${var.env}-kube-etcd/issue/etcd" {
    capabilities = [ "create", "read", "update", "list" ]
}

path "${vaultx_secret.service_account_pubkey.path}" {
    capabilities = [ "read" ]
}
path "${vaultx_secret.service_account_privkey.path}" {
    capabilities = [ "read" ]
}
EOF

    depends_on = [
        "vaultx_secret.kube_pki_init",
        "vaultx_secret.kubelet_pki_init",
        "vaultx_secret.etcd_pki_init"
    ]
}

resource vaultx_secret role {
    path = "auth/aws-ec2/role/${vaultx_policy.controller_instance.name}"
    ignore_read = true

    data {
        policies = "${vaultx_policy.controller_instance.name}"
        bound_ami_id = "${var.image_id}"
        bound_iam_role_arn = "${aws_iam_instance_profile.kube_controller.arn}"
        max_ttl = "48h"
    }
}
