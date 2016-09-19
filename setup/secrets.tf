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
    ignore_read = true

    data {
        policies = "${var.env}-kube-etcd-metrics"
        period = "12h"
    }
}
