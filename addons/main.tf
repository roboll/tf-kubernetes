variable env {}
variable region {}

variable fqdn {}
variable kube_fqdn {}

variable hyperkube {}
variable kube_version {}

variable acme_email {}
variable acme_url { default = "" }

provider aws {
    region = "${var.region}"
}

provider ecr {
    region = "${var.region}"
}

resource null_resource render {
    provisioner local-exec {
        command = <<EOF
mkdir -p ${path.root}/addons;

cat << "FF" > ${path.root}/addons/heapster.yaml;
${data.template_file.heapster.rendered}
FF

cat << "FF" > ${path.root}/addons/kube-addon-manager.yaml;
${data.template_file.kube_addon_manager.rendered}
FF

cat << "FF" > ${path.root}/addons/kube-metrics.yaml;
${data.template_file.kube_metrics.rendered}
FF

cat << "FF" > ${path.root}/addons/kube-dashboard.yaml;
${data.template_file.kube_dashboard.rendered}
FF

cat << "FF" > ${path.root}/addons/kube-ingress-acme.yaml;
${data.template_file.kube_ingress_acme.rendered}
FF

cat << "FF" > ${path.root}/addons/kube-ingress-dns.yaml;
${data.template_file.kube_ingress_dns.rendered}
FF

cat << "FF" > ${path.root}/addons/kube-ingress.yaml;
${data.template_file.kube_ingress.rendered}
FF

cat << "FF" > ${path.root}/addons/kube-proxy.yaml;
${data.template_file.kube_proxy.rendered}
FF

cat << "FF" > ${path.root}/addons/kube-roles.yaml;
${data.template_file.kube_roles.rendered}
FF

cat << "FF" > ${path.root}/addons/kube-scheduler.yaml;
${data.template_file.kube_scheduler.rendered}
FF

cat << "FF" > ${path.root}/addons/logging.yaml;
${data.template_file.logging.rendered}
FF

cat << "FF" > ${path.root}/addons/metrics-alerts-config.yaml;
${data.template_file.alerts_config.rendered}
FF

cat << "FF" > ${path.root}/addons/metrics-config.yaml;
${data.template_file.metrics_config.rendered}
FF

cat << "FF" > ${path.root}/addons/metrics.yaml;
${data.template_file.metrics.rendered}
FF

EOF
    }
}

data template_file heapster {
    template = "${file("${path.module}/addons/heapster.yaml")}"
}

data template_file kube_addon_manager {
    template = "${file("${path.module}/addons/kube-addon-manager.yaml")}"

    vars {
        hyperkube = "${var.hyperkube}"
        kube_version = "${var.kube_version}"
    }
}

data template_file kube_metrics {
    template = "${file("${path.module}/addons/kube-metrics.yaml")}"

    vars {
        etcd_metrics = "${ecr_push.etcd_metrics.latest_url}"
    }
}

data template_file kube_dashboard {
    template = "${file("${path.module}/addons/kube-dashboard.yaml")}"

    vars {
        fqdn = "${var.fqdn}"
    }
}

data template_file kube_ingress_acme {
    template = "${file("${path.module}/addons/kube-ingress-acme.yaml")}"

    vars {
        acme_email = "${var.acme_email}"
        acme_url = "${var.acme_url}"
    }
}

data template_file kube_ingress_dns {
    template = "${file("${path.module}/addons/kube-ingress-dns.yaml")}"
}

data template_file kube_ingress {
    template = "${file("${path.module}/addons/kube-ingress.yaml")}"
}

data template_file kube_proxy {
    template = "${file("${path.module}/addons/kube-proxy.yaml")}"
    vars {
        kube_fqdn = "${var.kube_fqdn}"

        hyperkube = "${var.hyperkube}"
        kube_version = "${var.kube_version}"
    }
}

data template_file kube_roles {
    template = "${file("${path.module}/addons/kube-roles.yaml")}"
}

data template_file kube_scheduler {
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
