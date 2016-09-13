variable env {}
variable aws_region {}

variable fqdn {}
variable kube_fqdn {}

variable hyperkube {}
variable kube_version {}

provider ecr {
    region = "${var.aws_region}"
}

resource null_resource render {
    provisioner local-exec {
        command = <<EOF
mkdir -p ${path.root}/kube && \
echo ${data.template_file.access.rendered} > ${path.root}/kube/access.yaml && \
echo ${data.template_file.dashboard.rendered} > ${path.root}/kube/kube-dashboard.yaml && \
echo ${data.template_file.heapster.rendered} > ${path.root}/kube/heapster.yaml && \
echo ${data.template_file.addon_manager.rendered} > ${path.root}/kube/kube-addon-manager.yaml && \
echo ${data.template_file.controller_manager.rendered} > ${path.root}/kube/kube-controller-manager.yaml && \
echo ${data.template_file.controller_metrics.rendered} > ${path.root}/kube/controller-metrics.yaml && \
echo ${data.template_file.ingress.rendered} > ${path.root}/kube/kube-ingress.yaml && \
echo ${data.template_file.proxy.rendered} > ${path.root}/kube/kube-proxy.yaml && \
echo ${data.template_file.scheduler.rendered} > ${path.root}/kube/kube-scheduler.yaml && \
echo ${data.template_file.logging.rendered} > ${path.root}/kube/logging.yaml && \
echo ${data.template_file.alerts_config.rendered} > ${path.root}/kube/metrics-alerts-config.yaml && \
echo ${data.template_file.metrics_config.rendered} > ${path.root}/kube/metrics-config.yaml && \
echo ${data.template_file.metrics.rendered} > ${path.root}/kube/metrics.yaml
EOF
    }
}

data template_file access {
    template = "${file("${path.module}/addons/access.yaml")}"
}

data template_file dashboard {
    template = "${file("${path.module}/addons/dashboard.yaml")}"

    vars {
        fqdn = "${var.fqdn}"
    }
}

data template_file heapster {
    template = "${file("${path.module}/addons/heapster.yaml")}"
}

data template_file addon_manager {
    template = "${file("${path.module}/addons/kube-addon-manager.yaml")}"

    vars {
        hyperkube = "${var.hyperkube}"
        kube_version = "${var.kube_version}"
    }
}

data template_file controller_manager {
    template = "${file("${path.module}/addons/kube-controller-manager.yaml")}"

    vars {
        kube_fqdn = "${var.kube_fqdn}"

        hyperkube = "${var.hyperkube}"
        kube_version = "${var.kube_version}"
    }
}

data template_file controller_metrics {
    template = "${file("${path.module}/addons/kube-controller-metrics.yaml")}"

    vars {
        etcd_metrics_image = "${ecr_push.etcd_metrics.latest_url}"
    }
}

data template_file ingress {
    template = "${file("${path.module}/addons/kube-ingress.yaml")}"
}

data template_file proxy {
    template = "${file("${path.module}/addons/kube-proxy.yaml")}"
    vars {
        kube_fqdn = "${var.kube_fqdn}"

        hyperkube = "${var.hyperkube}"
        kube_version = "${var.kube_version}"
    }
}

data template_file scheduler {
    template = "${file("${path.module}/addons/kube-scheduler.yaml")}"

    vars {
        kube_fqdn = "${var.kube_fqdn}"

        hyperkube = "${var.hyperkube}"
        kube_version = "${var.kube_version}"
    }
}

data template_file logging {
    template = "${file("${path.module}/addons/logging.yaml")}"

    vars {
        fqdn = "${var.fqdn}"
    }
}

data template_file alerts_config {
    template = "${file("${path.module}/addons/metrics-alerts-config.yaml")}"
}

data template_file metrics_config {
    template = "${file("${path.module}/addons/metrics-prometheus-config.yaml")}"
}

data template_file metrics {
    template = "${file("${path.module}/addons/metrics.yaml")}"

    vars {
        fqdn = "${var.fqdn}"
    }
}
