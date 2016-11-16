variable env {}
variable region {}

variable vpc {}
variable subnets { type = "list" }

variable ssh_keypair {}

variable vault_address {}
variable vault_ca_cert_pem_b64 {}
variable vault_curl_opts { default = "" }

variable security_groups { type = "list" }

variable image_id {}
variable replicas { default = 3 }
variable min_replicas { default = 3 }
variable max_replicas { default = 5 }
variable instance_type { default = "m4.large" }
variable ebs_optimized { default = true }

variable root_volume_type { default = "gp2" }
variable root_volume_size { default = 20 }

variable worker_class {}
variable controller_fqdn {}
variable kube_pki_backend {}

variable hyperkube { default = "gcr.io/google_containers/hyperkube" }
variable kube_version { default = "v1.4.6" }

variable vault_ssh_image { default = "quay.io/roboll/vault-ssh-coreos" }
variable vault_ssh_tag { default = "v0.3.2" }

provider aws {
    region = "${var.region}"
}

resource aws_iam_role kube_worker {
    name = "${var.env}-kube_worker_${var.worker_class}"
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

resource aws_iam_role_policy kube_worker_ecr {
    name = "${var.env}-kube_worker_${var.worker_class}-ecr"
    role = "${aws_iam_role.kube_worker.id}"
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

resource aws_iam_role_policy kube_worker_ec2 {
    name = "${var.env}-kube_worker_${var.worker_class}-ec2"
    role = "${aws_iam_role.kube_worker.id}"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Resource": "*",
            "Action": "ec2:Describe*"
        }
    ]
}
EOF
}

resource aws_iam_role_policy kube_worker_volumes {
    name = "${var.env}-kube_worker_${var.worker_class}-volumes"
    role = "${aws_iam_role.kube_worker.id}"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Resource": "*",
            "Action": [
                "ec2:AttachVolume",
                "ec2:DetachVolume"
            ]
        }
    ]
}
EOF
}

resource aws_iam_instance_profile kube_worker {
    name = "${var.env}-kube_worker_${var.worker_class}-instance"
    roles = [ "${aws_iam_role.kube_worker.name}" ]

    depends_on = [
        "aws_iam_role_policy.kube_worker_ecr",
        "aws_iam_role_policy.kube_worker_ec2",
        "aws_iam_role_policy.kube_worker_volumes"
    ]

    provisioner local-exec { command = "sleep 30" }
}

resource coreos_cloudconfig cloud_config {
    gzip = false
    template = "${file("${path.module}/config/cloud-config.yaml")}"

    vars {
        worker_class = "${var.worker_class}"

        kube_fqdn = "${var.controller_fqdn}"
        kube_version = "${var.kube_version}"
        hyperkube = "${var.hyperkube}"

        vault_ssh_image = "${var.vault_ssh_image}:${var.vault_ssh_tag}"

        region = "${var.region}"
        vault_address = "${var.vault_address}"
        vault_instance_role = "${vaultx_policy.worker.name}"

        vault_ca_cert_pem = "${var.vault_ca_cert_pem_b64}"
        vault_curl_opts = "${var.vault_curl_opts}"

        kube_pki_mount = "${var.kube_pki_backend}"
    }

    lifecycle { create_before_destroy = true }
}

resource aws_launch_configuration worker {
    name_prefix = "${var.env}-kube-worker-${var.worker_class}-"

    image_id = "${var.image_id}"
    instance_type = "${var.instance_type}"

    key_name = "${var.ssh_keypair}"
    user_data = "${coreos_cloudconfig.cloud_config.rendered}"

    security_groups = [ "${var.security_groups}" ]
    iam_instance_profile = "${aws_iam_instance_profile.kube_worker.name}"

    ebs_optimized = "${var.ebs_optimized}"
    root_block_device {
        volume_type = "${var.root_volume_type}"
        volume_size = "${var.root_volume_size}"
        delete_on_termination = true
    }

    lifecycle { create_before_destroy = true }
}

resource aws_autoscaling_group worker {
    name = "${var.env}-kube-worker-${var.worker_class}"

    launch_configuration = "${aws_launch_configuration.worker.name}"
    vpc_zone_identifier = [ "${var.subnets}" ]

    min_size = "${var.min_replicas}"
    max_size = "${var.max_replicas}"
    desired_capacity = "${var.replicas}"

    health_check_grace_period = 300
    health_check_type = "EC2"

    tag {
        key = "Name"
        value = "${var.env}-kube_worker-${var.worker_class}"
        propagate_at_launch = true
    }

    tag {
        key = "Environment"
        value = "${var.env}"
        propagate_at_launch = true
    }

    tag {
        key = "KubernetesRole"
        value = "worker"
        propagate_at_launch = true
    }

    tag {
        key = "KubernetesWorkerClass"
        value = "${var.worker_class}"
        propagate_at_launch = true
    }

    tag {
        key = "KubernetesCluster"
        value = "${var.env}"
        propagate_at_launch = true
    }

    depends_on = [
        "vaultx_secret.role",
        "vaultx_policy.worker"
    ]
}
