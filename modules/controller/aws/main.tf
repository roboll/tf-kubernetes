variable env {}
variable region {}

variable vpc {}
variable subnets { type = "list" }
variable subnet_cidrs { type = "list" }

variable ssh_keypair {}
variable vault_address {}
variable vault_ca_cert_pem {}
variable vault_curl_opts { default = "" }
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
    assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            }
        }
    ]
}
EOF

    provisioner local-exec { command = "sleep 60" }
}

resource aws_iam_role_policy kube_controller_ecr {
    name = "${var.env}-kube_controller-ecr"
    role = "${aws_iam_role.kube_controller.id}"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Resource": "*",
            "Action": [
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:GetRepositoryPolicy",
                "ecr:DescribeRepositories",
                "ecr:ListImages",
                "ecr:BatchGetImage"
            ]
        }
    ]
}
EOF
}

resource aws_iam_role_policy kube_controller_ec2 {
    name = "${var.env}-kube_controller-ec2"
    role = "${aws_iam_role.kube_controller.id}"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Resource": "*",
            "Action": [
                "ec2:*"
            ]
        }
    ]
}
EOF
}

resource aws_iam_role_policy kube_controller_autoscaling {
    name = "${var.env}-kube_controller-autoscaling"
    role = "${aws_iam_role.kube_controller.id}"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Resource": "*",
            "Action": [
                "autoscaling:Describe*"
            ]
        }
    ]
}
EOF
}

resource aws_iam_role_policy kube_controller_elb {
    name = "${var.env}-kube_controller-elb"
    role = "${aws_iam_role.kube_controller.id}"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Resource": "*",
            "Action": [
                "elasticloadbalancing:*"
            ]
        }
    ]
}
EOF
}

resource aws_iam_instance_profile kube_controller {
    name = "${var.env}-kube_controller-instance"
    roles = [ "${aws_iam_role.kube_controller.name}" ]

    depends_on = [
        "aws_iam_role_policy.kube_controller_ecr",
        "aws_iam_role_policy.kube_controller_ec2",
        "aws_iam_role_policy.kube_controller_elb",
        "aws_iam_role_policy.kube_controller_autoscaling",
        "null_resource.network"
    ]

    provisioner local-exec { command = "sleep 30" }
}

resource null_resource etcd {
    triggers {
        name = "controller${count.index}"
        ip = "${cidrhost(element(var.subnet_cidrs, count.index), (count.index / length(var.subnet_cidrs) + var.cidr_offset))}"
    }

    count = "${var.replicas}"
}

resource coreos_cloudconfig cloud_config {
    gzip = true
    template = "${file("${path.module}/config/cloud-config.yaml")}"

    vars {
        oidc_issuer_url = "${data.vaultx_secret.oidc.data.issuer_url}"
        oidc_client_id = "${data.vaultx_secret.oidc.data.client_id}"
        oidc_groups_claim = "${data.vaultx_secret.oidc.data.groups_claim}"
        oidc_username_claim = "${data.vaultx_secret.oidc.data.username_claim}"

        instance_name = "${element(null_resource.etcd.*.triggers.name, count.index)}"
        etcd_peers = "${join(",",formatlist("%s=https://%s:2380", null_resource.etcd.*.triggers.name, null_resource.etcd.*.triggers.ip))}"

        hyperkube = "${ecr_push.hyperkube.latest_url}"
        ssh_helper = "${var.ssh_helper_image}"

        kube_fqdn = "${var.fqdn}"
        region = "${var.region}"
        vault_address = "${var.vault_address}"
        vault_instance_role = "${vaultx_policy.controller.name}"

        vault_ca_cert_pem = "${base64encode(var.vault_ca_cert_pem)}"
        vault_curl_opts = "${var.vault_curl_opts}"
        kube_pki_role = "kube"
        kubelet_pki_role = "kubelet"
        controller_pki_role = "controller"
        etcd_pki_role = "controller"

        kube_pki_mount = "${null_resource.pki_mount.triggers.kube_path}"
        etcd_pki_mount = "${null_resource.pki_mount.triggers.etcd_path}"
        kubelet_pki_mount = "${null_resource.pki_mount.triggers.kube_path}"

        service_account_path = "${vaultx_secret.service_account.path}"
    }

    count = "${var.replicas}"

    depends_on = [ "vaultx_secret.role" ]
}

resource aws_instance controller {
    ami = "${var.image_id}"
    instance_type = "${var.instance_type}"

    key_name = "${var.ssh_keypair}"
    user_data = "${element(coreos_cloudconfig.cloud_config.*.rendered, count.index)}"

    iam_instance_profile = "${aws_iam_instance_profile.kube_controller.name}"

    subnet_id = "${element(var.subnets, count.index)}"
    private_ip = "${element(null_resource.etcd.*.triggers.ip, count.index)}"
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
    }

    lifecycle { ignore_changes = [ "ami" ] }

    count = "${var.replicas}"

    depends_on = [
        "vaultx_secret.role",
        "vaultx_policy.controller",
        "vaultx_secret.service_account",
        "vaultx_secret.kube_pki_init",
        "vaultx_secret.etcd_pki_init"
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
output kube_pki_backend { value = "${null_resource.pki_mount.triggers.kube_path}" }
output etcd_pki_backend { value = "${null_resource.pki_mount.triggers.etcd_path}" }
output worker_security_group { value = "${aws_security_group.kube_worker.id}" }
