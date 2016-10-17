resource vaultx_policy worker {
    name = "${var.env}-kube-worker-${var.worker_class}"

    rules = <<EOF
path "${var.kube_pki_backend}/issue/kubelet" {
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
        bound_iam_role_arn = "${aws_iam_role.kube_worker.arn}"
        bound_iam_instance_profile_arn = "${aws_iam_instance_profile.kube_worker.arn}"
        max_ttl = "48h"
    }
}
