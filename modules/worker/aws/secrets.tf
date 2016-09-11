resource vaultx_secret worker_role {
    path = "${var.vault_pki_backend}/roles/worker-${var.worker_class}"

    data {
        allowed_domains = "kubelet"
        allow_bare_domains = true
        allow_subdomains = false
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

resource vaultx_secret role {
    path = "auth/aws-ec2/role/${vaultx_policy.worker.name}"
    ignore_read = true

    data {
        policies = "${vaultx_policy.worker.name}"
        bound_ami_id = "${var.image_id}"
        bound_iam_role_arn = "${aws_iam_role.kube_controller.arn}"
        max_ttl = "48h"
    }
}
