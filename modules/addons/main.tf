variable env {}
variable region {}

variable fqdn {}
variable kube_fqdn {}

variable hyperkube {}
variable kube_version {}

provider aws {
    region = "${var.region}"
}

provider ecr {
    region = "${var.region}"
}

resource null_resource render {
    provisioner local-exec {
        command = <<EOF
mkdir -p ${path.root}/kube;

cat <<FF > ${path.root}/kube/access.yaml;
'${data.template_file.access.rendered}'
FF

cat <<FF > ${path.root}/kube/kube-dashboard.yaml;
'${data.template_file.dashboard.rendered}'
FF

cat <<FF > ${path.root}/kube/heapster.yaml;
'${data.template_file.heapster.rendered}'
FF

cat <<FF > ${path.root}/kube/kube-addon-manager.yaml;
'${data.template_file.addon_manager.rendered}'
FF

cat <<FF > ${path.root}/kube/kube-controller-manager.yaml;
'${data.template_file.controller_manager.rendered}'
FF

cat <<FF > ${path.root}/kube/kube-controller-manager.yaml;
'${data.template_file.controller_manager.rendered}'
FF

cat <<FF > ${path.root}/kube/controller-metrics.yaml;
'${data.template_file.controller_metrics.rendered}'
FF

cat <<FF > ${path.root}/kube/kube-ingress.yaml;
'${data.template_file.ingress.rendered}'
FF

cat <<FF > ${path.root}/kube/kube-controller-manager.yaml;
'${data.template_file.controller_manager.rendered}'
FF

cat <<FF > ${path.root}/kube/kube-proxy.yaml;
'${data.template_file.proxy.rendered}'
FF

cat <<FF > ${path.root}/kube/kube-scheduler.yaml;
'${data.template_file.scheduler.rendered}'
FF

cat <<FF > ${path.root}/kube/logging.yaml;
'${data.template_file.logging.rendered}'
FF

cat <<FF > ${path.root}/kube/metrics-alerts-config.yaml;
'${data.template_file.alerts_config.rendered}'
FF

cat <<FF > ${path.root}/kube/metrics-config.yaml;
'${data.template_file.metrics_config.rendered}'
FF

cat <<FF > ${path.root}/kube/metrics.yaml;
'${data.template_file.metrics.rendered}'
FF

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
