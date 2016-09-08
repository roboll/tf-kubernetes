variable env {}
variable region {}

variable vpc {}
variable subnets { type = "list" }
variable subnet_cidrs { type = "list" }

variable ssh_keypair {}
variable vault_address {}
variable ssh_helper_image {}

variable fqdn {}
variable dns_zone_id {}
variable security_groups { type = "list" }
variable internal_elb { default = true }

variable image_id {}
variable replicas { default = 3 }
variable instance_type { default = "t2.small" }
variable ebs_optimized { default = false }

variable root_volume_type { default = "gp2" }
variable root_volume_size { default = 20 }

variable etcd_volume_type { default = "gp2" }
variable etcd_volume_size { default = 20 }

variable oidc_vault_path {}

variable hyperkube { default = "gcr.io/google_containers/hyperkube-amd64" }
variable hyperkube_tag { default = "v1.3.4" }

variable addon_manager { default = "gcr.io/google-containers/kube-addon-manager-amd64" }
variable addon_manager_tag { default = "v5.1" }

variable cidr_offset { default = "16" }

provider aws {
    region = "${var.region}"
}

provider ecr {
    region = "${var.region}"
}

resource aws_iam_role kube_controller {
    name = "${var.env}-kube_controller"
    path = "/${var.env}/"
    assume_role_policy = "${file("${path.module}/iam/kube_controller-role.json")}"

    provisioner local-exec { command = "sleep 30" }
}

resource aws_iam_role_policy kube_controller_ecr {
    name = "${var.env}-kube_controller-ecr"
    role = "${aws_iam_role.kube_controller.id}"
    policy = "${file("${path.module}/iam/kube_controller-policy-ecr.json")}"
}

resource aws_iam_role_policy kube_controller_instances {
    name = "${var.env}-kube_controller-instances"
    role = "${aws_iam_role.kube_controller.id}"
    policy = "${file("${path.module}/iam/kube_controller-policy-instances.json")}"
}

resource aws_iam_role_policy kube_controller_route53 {
    name = "${var.env}-kube_controller-route53"
    role = "${aws_iam_role.kube_controller.id}"
    policy = "${file("${path.module}/iam/kube_controller-policy-route53.json")}"
}

resource aws_iam_instance_profile kube_controller {
    name = "${var.env}-kube_controller-instance"
    roles = [ "${aws_iam_role.kube_controller.name}" ]

    depends_on = [
        "aws_iam_role_policy.kube_controller_ecr",
        "aws_iam_role_policy.kube_controller_instances",
        "aws_iam_role_policy.kube_controller_route53",
        "null_resource.network"
    ]

    provisioner local-exec { command = "sleep 30" }
}

resource template_file instances {
    vars {
        name = "controller${count.index}"
        ip = "${cidrhost(element(var.subnet_cidrs, count.index), (count.index / length(var.subnet_cidrs) + var.cidr_offset))}"
    }

    template = ""
    count = "${var.replicas}"
}

resource template_file etcd_members {
    template = "${join(",",formatlist("%s=https://%s:2380", template_file.instances.*.vars.name, template_file.instances.*.vars.ip))}"

    vars {
        name_list = "${join(",", template_file.instances.*.vars.name)}"
    }
}

resource coreos_cloudconfig cloud_config {
    gzip = true
    template = "${file("${path.module}/config/cloud-config.yaml")}"

    vars {
        oidc_issuer_url = "${data.vaultx_secret.oidc.data.issuer_url}"
        oidc_client_id = "${data.vaultx_secret.oidc.data.client_id}"
        oidc_groups_claim = "${data.vaultx_secret.oidc.data.groups_claim}"
        oidc_username_claim = "${data.vaultx_secret.oidc.data.username_claim}"

        etcd_peers = "${template_file.etcd_members.rendered}"
        instance_name = "${element(split(",", template_file.etcd_members.vars.name_list), count.index)}"

        hyperkube = "${ecr_push.hyperkube.latest_url}"
        podmaster = "${ecr_push.podmaster.latest_url}"
        ssh_helper = "${var.ssh_helper_image}"

        fqdn = "${var.fqdn}"
        region = "${var.region}"
        vault_address = "${var.vault_address}"
        vault_pki_mount = "${template_file.pki_mount.rendered}"
        vault_pki_role = "controller"
        vault_instance_role = "${vaultx_policy.controller.name}"
        service_account_path = "${vaultx_secret.service_account.path}"
    }

    count = "${var.replicas}"

    depends_on = [ "vaultx_policy.controller", "vaultx_secret.controller_role" ]
}

resource aws_instance controller {
    ami = "${var.image_id}"
    instance_type = "${var.instance_type}"

    key_name = "${var.ssh_keypair}"
    user_data = "${element(coreos_cloudconfig.cloud_config.*.rendered, count.index)}"

    iam_instance_profile = "${aws_iam_instance_profile.kube_controller.name}"


    subnet_id = "${element(var.subnets, count.index)}"
    private_ip = "${element(template_file.instances.*.vars.ip, count.index)}"
    vpc_security_group_ids = [
        "${var.security_groups}",
        "${aws_security_group.kube_controller.id}"
    ]

    ebs_optimized = "${var.ebs_optimized}"
    root_block_device {
        volume_type = "${var.root_volume_type}"
        volume_size = "${var.root_volume_size}"
    }

    ebs_block_device {
        device_name = "/dev/sdb"
        volume_type = "${var.etcd_volume_type}"
        volume_size = "${var.etcd_volume_size}"
        delete_on_termination = false
    }

    tags {
        Name = "${var.env}-kube_controller${count.index}"
        Role = "controller"
        Environment = "${var.env}"
        KubernetesCluster = "${var.env}"
        VaultRole = "${vaultx_secret.role_tag.data.tag_value}"
    }

    lifecycle { ignore_changes = [ "ami" ] }

    count = "${var.replicas}"

    depends_on = [
        "vaultx_policy.controller",
        "vaultx_secret.service_account",
        "vaultx_secret.controller_role",
        "vaultx_secret.pki_init"
    ]
}

resource aws_elb kube_controller {
    name = "${replace(var.env, ".", "-")}-kube-controller"

    internal = "${var.internal_elb}"
    subnets = [ "${var.subnets}" ]
    security_groups = [ "${aws_security_group.kube_controller_elb.id}" ]

    instances = [ "${aws_instance.controller.*.id}" ]

    connection_draining = true
    connection_draining_timeout = 60

    listener {
        instance_port = 443
        instance_protocol = "tcp"
        lb_port = 443
        lb_protocol = "tcp"
    }

    listener {
        instance_port = 8888
        instance_protocol = "tcp"
        lb_port = 8888
        lb_protocol = "tcp"
    }

    health_check {
        target = "TCP:443"

        healthy_threshold = 2
        unhealthy_threshold = 2

        interval = 15
        timeout = 2
    }

    tags {
        Name = "${var.env}-kube_controller"
        Environment = "${var.env}"
    }
}

resource aws_route53_record kube {
    zone_id = "${var.dns_zone_id}"
    name = "${var.fqdn}"
    type = "A"

    alias {
        name = "${aws_elb.kube_controller.dns_name}"
        zone_id = "${aws_elb.kube_controller.zone_id}"
        evaluate_target_health = false
    }
}

output address { value = "https://${aws_route53_record.kube.fqdn}"}
output vault_pki_backend { value = "${template_file.pki_mount.rendered}" }
output worker_security_group { value = "${aws_security_group.kube_worker.id}" }
