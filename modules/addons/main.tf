variable fqdn {}
variable kubernetes_version {}

variable aws_region {}

provider ecr {
    region = "${var.aws_region}"
}

data template_file addon_manager {
    template = "${file("${path.module}/addons/kube-addon-manager.yaml")}"
    vars {
        kubernetes_version = "${var.kubernetes_version}"
    }
}

data template_file controller_metrics {
    template = "${file("${path.module}/addons/kube-controller-metrics.yaml")}"
    vars {
        etcd_metrics_image = "${ecr_push.etcd_metrics.image_url}"
    }
}

data template_file dashboard {
    template = "${file("${path.module}/addons/dashboard.yaml")}"
    vars {
        fqdn = "${var.fqdn}"
    }
}

data template_file heapster {
    template = "${file("${path.module}/addons/heapster.yaml")}"
    vars {
        fqdn = "${var.fqdn}"
    }
}

data template_file ingress {
    template = "${file("${path.module}/addons/kube-ingress.yaml")}"
    vars {
        auth_oidc_secret = "secret/ops/oidc/web"
        auth_email_domain = "*"
        cookie_secret = "${uuid()}"
        dns_aws_secret = "secret/ops/aws-admin" //TODO change this to aws secret
    }

    lifecycle { ignore_changes = [ "cars.cookie_secret" ] }
}

data template_file proxy {
    template = "${file("${path.module}/addons/kube-proxy.yaml")}"
    vars {
        master_url = "https://kube.dev.kitkit.cloud"
        kubernetes_version = "${var.kubernetes_version}"
    }
}

data template_file vault {
    template = "${file("${path.module}/addons/kube-vault.yaml")}"
    vars {
        vault_address = ""
        vault_token = ""
    }
}

data template_file logging {
    template = "${file("${path.module}/addons/logging.yaml")}"
    vars {
        fqdn = "${var.fqdn}"
    }
}

data template_file prometheus_config {
    template = "${file("${path.module}/addons/metrics-prometheus-config.yaml")}"
}

data template_file alerts_config {
    template = "${file("${path.module}/addons/metrics-alerts-config.yaml")}"
}

data template_file metrics {
    template = "${file("${path.module}/addons/metrics.yaml")}"
    vars {
        fqdn = "${var.fqdn}"
    }
}
