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

resource vaultx_secret ingress_dns_policy {
    path = "aws/roles/${var.env}-kube-ingress-dns"
    ignore_read = true

    data {
        policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "route53:List*",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "elasticloadbalancing:DescribeLoadBalancers",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "route53:ChangeResourceRecordSets",
            "Resource": "*"
        }
    ]
}
EOF
    }
}

resource vaultx_policy ingress_dns_policy {
    name = "${var.env}-kube-ingress-dns"

    rules = <<EOF
path "aws/creds/${var.env}-kube-ingress-dns" {
    capabilities = [ "read", "list" ]
}
EOF
}

resource vaultx_secret ingress_dns_approle {
    path = "auth/approle/role/${var.env}-kube-ingress-dns"
    ignore_read = true

    data {
        policies = "${var.env}-kube-ingress-dns"
        period = "12h"
    }
}

resource aws_s3_bucket registry {
    bucket = "registry.${var.domain}"
    acl = "private"
}

resource vaultx_secret registry_policy {
    path = "aws/roles/${var.env}-registry"
    ignore_read = true

    data {
        policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:GetBucketLocation",
                "s3:ListBucketMultipartUploads"
            ],
            "Resource": "${aws_s3_bucket.registry.arn}"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject",
                "s3:ListMultipartUploadParts",
                "s3:AbortMultipartUpload"
            ],
            "Resource": "${aws_s3_bucket.registry.arn}/*"
        }
    ]
}
EOF
    }
}

resource vaultx_policy registry {
    name = "${var.env}-registry"

    rules = <<EOF
path "aws/creds/${var.env}-registry" {
    capabilities = [ "read", "list" ]
}
path "secret/${var.env}/registry" {
    capabilities = [ "read", "list" ]
}
path "${var.env}-kube/issue/registry" {
    capabilities = [ "create", "read", "update", "list" ]
}
EOF
}

resource vaultx_secret registry_role {
    path = "${var.env}-kube/roles/registry"
    ignore_read = true

    data {
        allowed_domains = "registry.${var.domain},registry,registry.kube-system,registry.kube-system.svc,registry.kube-system.svc.cluster.local"
        allow_bare_domains = true
        allow_subdomains = false
        allow_localhost = false
        key_type = "ec"
        key_bits = "256"
        max_ttl = "48h"
    }
}

resource vaultx_secret registry_approle {
    path = "auth/approle/role/${var.env}-registry"
    ignore_read = true

    data {
        policies = "${var.env}-registry"
        period = "12h"
    }
}

resource random_id http_secret {
    byte_length = 32
}

resource vaultx_secret registry_http_secret {
    path = "secret/${var.env}/registry"
    ignore_read = true

    data {
        registry_http_secret = "${random_id.http_secret.b64}"
    }
}
