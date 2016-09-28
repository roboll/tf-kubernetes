variable env {}
variable region {}

variable domain {}
variable kube_fqdn {}

variable hyperkube {}
variable kube_version {}

variable etcd_pki_backend {}

variable acme_email {}
variable acme_url { default = "" }

variable vpn_address {}
variable vpn_hostnames { type = "list" }
variable vpn_mongo_hostnames { type = "list" }
variable vault_address {}
variable vault_hostnames { type = "list" }

provider aws {
    region = "${var.region}"
}

provider ecr {
    region = "${var.region}"
}

resource null_resource render {
    triggers {
        heapster = "${data.template_file.heapster.rendered}"
        kube_addon_manager = "${data.template_file.kube_addon_manager.rendered}"
        kube_controller_metrics = "${data.template_file.kube_controller_metrics.rendered}"
        kube_dashboard = "${data.template_file.kube_dashboard.rendered}"
        kube_etcd_metrics = "${data.template_file.kube_etcd_metrics.rendered}"
        kube_ingress_acme = "${data.template_file.kube_ingress_acme.rendered}"
        kube_ingress_dns = "${data.template_file.kube_ingress_dns.rendered}"
        kube_ingress = "${data.template_file.kube_ingress.rendered}"
        kube_scheduler = "${data.template_file.kube_scheduler.rendered}"
        logging = "${data.template_file.logging.rendered}"
        metrics_alerts_config = "${data.template_file.metrics_alerts_config.rendered}"
        metrics_config = "${data.template_file.metrics_config.rendered}"
        metrics = "${data.template_file.metrics.rendered}"
    }

    provisioner local-exec {
        command = <<EOF
mkdir -p ${path.root}/kube/manifests;
mkdir -p ${path.root}/kube/scripts;

cat << "FF" > ${path.root}/kube/manifests/heapster.yaml;
${data.template_file.heapster.rendered}
FF

cat << "FF" > ${path.root}/kube/manifests/kube-addon-manager.yaml;
${data.template_file.kube_addon_manager.rendered}
FF

cat << "FF" > ${path.root}/kube/manifests/kube-controller-metrics.yaml;
${data.template_file.kube_controller_metrics.rendered}
FF

cat << "FF" > ${path.root}/kube/manifests/kube-dashboard.yaml;
${data.template_file.kube_dashboard.rendered}
FF

cat << "FF" > ${path.root}/kube/manifests/kube-etcd-metrics.yaml;
${data.template_file.kube_etcd_metrics.rendered}
FF

cat << "FF" > ${path.root}/kube/manifests/kube-ingress-acme.yaml;
${data.template_file.kube_ingress_acme.rendered}
FF

cat << "FF" > ${path.root}/kube/manifests/kube-ingress-dns.yaml;
${data.template_file.kube_ingress_dns.rendered}
FF

cat << "FF" > ${path.root}/kube/manifests/kube-ingress.yaml;
${data.template_file.kube_ingress.rendered}
FF

cat << "FF" > ${path.root}/kube/manifests/kube-scheduler.yaml;
${data.template_file.kube_scheduler.rendered}
FF

cat << "FF" > ${path.root}/kube/manifests/logging.yaml;
${data.template_file.logging.rendered}
FF

cat << "FF" > ${path.root}/kube/manifests/metrics_alerts-config.yaml;
${data.template_file.metrics_alerts_config.rendered}
FF

cat << "FF" > ${path.root}/kube/manifests/metrics_config.yaml;
${data.template_file.metrics_config.rendered}
FF

cat << "FF" > ${path.root}/kube/manifests/metrics.yaml;
${data.template_file.metrics.rendered}
FF

cat << "FF" > ${path.root}/kube/scripts/etcd-vault-setup.sh;
${data.template_file.etcd_vault_setup.rendered}
FF
chmod +x ${path.root}/kube/scripts/etcd-vault-setup.sh

cat << "FF" > ${path.root}/kube/scripts/kube-ingress-dns-vault-setup.sh;
${data.template_file.kube_ingress_dns_vault_setup.rendered}
FF
chmod +x ${path.root}/kube/scripts/kube-ingress-dns-vault-setup.sh

EOF
    }
}

data template_file heapster {
    template = "${file("${path.module}/manifests/heapster.yaml")}"
}

data template_file kube_addon_manager {
    template = "${file("${path.module}/manifests/kube-addon-manager.yaml")}"

    vars {
        hyperkube = "${var.hyperkube}"
        kube_version = "${var.kube_version}"
    }
}

data template_file kube_controller_metrics {
    template = "${file("${path.module}/manifests/kube-controller-metrics.yaml")}"
}

data template_file kube_dashboard {
    template = "${file("${path.module}/manifests/kube-dashboard.yaml")}"

    vars {
        domain = "${var.domain}"
    }
}

data template_file kube_etcd_metrics {
    template = "${file("${path.module}/manifests/kube-etcd-metrics.yaml")}"

    vars {
        etcd_pki = "${var.etcd_pki_backend}/issue/metrics"
    }
}


data template_file kube_ingress_acme {
    template = "${file("${path.module}/manifests/kube-ingress-acme.yaml")}"

    vars {
        acme_email = "${var.acme_email}"
        acme_url = "${var.acme_url}"
    }
}

data template_file kube_ingress_dns {
    template = "${file("${path.module}/manifests/kube-ingress-dns.yaml")}"

    vars {
        dns_path = "aws/creds/${var.env}-kube-ingress-dns"
    }
}

data template_file kube_ingress {
    template = "${file("${path.module}/manifests/kube-ingress.yaml")}"
}

data template_file kube_scheduler {
    template = "${file("${path.module}/manifests/kube-scheduler.yaml")}"

    vars {
        kube_fqdn = "${var.kube_fqdn}"

        hyperkube = "${var.hyperkube}"
        kube_version = "${var.kube_version}"
    }
}

data template_file logging {
    template = "${file("${path.module}/manifests/logging.yaml")}"

    vars {
        domain = "${var.domain}"
    }
}

data template_file metrics_alerts_config {
    template = "${file("${path.module}/manifests/metrics_alerts-config.yaml")}"
}

data template_file metrics_config {
    template = "${file("${path.module}/manifests/metrics_config.yaml")}"

    vars {
        vpn_address = "${var.vpn_address}"
        vpn_hostnames = "${jsonencode(var.vpn_hostnames)}"
        vpn_mongo_hostnames = "${jsonencode(var.vpn_mongo_hostnames)}"
        vault_address = "${var.vault_address}"
        vault_hostnames = "${jsonencode(var.vault_hostnames)}"
    }
}

data template_file metrics {
    template = "${file("${path.module}/manifests/metrics.yaml")}"

    vars {
        domain = "${var.domain}"
    }
}

data template_file etcd_vault_setup {
    template = "${file("${path.module}/scripts/vault-setup.sh")}"

    vars {
        approle = "${var.env}-kube-etcd-metrics"

        name = "kube-etcd-metrics"
        namespace = "kube-system"
    }
}

data template_file kube_ingress_dns_vault_setup {
    template = "${file("${path.module}/scripts/vault-setup.sh")}"

    vars {
        approle = "${var.env}-kube-ingress-dns"

        name = "kube-ingress-dns"
        namespace = "kube-system"
    }
}
