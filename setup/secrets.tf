resource vaultx_secret etcd_pki_role {
    path = "${var.etcd_pki_backend}/roles/metrics"
    ignore_read = true

    data {
        allowed_domains = "metrics"
        allow_bare_domains = true
        allow_subdomains = false
        allow_localhost = false
        server_flag = false
        key_type = "ec"
        key_bits = "256"
        max_ttl = "48h"
    }
}

resource vaultx_policy etcd_metrics_policy {
    name = "${var.env}-kube-etcd-metrics"

    rules = <<EOF
path "${var.etcd_pki_backend}/issue/metrics" {
    capabilities = [ "create", "read", "update", "list" ]
}
EOF
}

resource vaultx_secret etcd_approle {
    path = "auth/approle/role/${var.env}-kube-etcd-metrics"

    data {
        role_name = "${var.env}-kube-etcd-metrics"
        policies = "${var.env}-kube-etcd-metrics"
        period = "6h"
    }
}

resource vaultx_secret etcd_role_id {
    path = "auth/approle/role/${var.env}-kube-etcd-metrics/role-id"

    depends_on = [ "vaultx_secret.etcd_approle" ]
}

resource vaultx_secret etcd_secret_id {
    path = "auth/approle/role/${var.env}-kube-etcd-metrics/secret-id"

    ignore_read = true
    ignore_delete = true

    data {
        force = "write"
    }
}