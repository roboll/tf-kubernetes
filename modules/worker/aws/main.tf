variable env {}
variable region {}

variable vpc {}
variable subnets {}

variable ssh_keypair {}
variable vault_address {}
variable ssh_helper_image {}
variable vault_pki_backend {}

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
variable controller_url {}

variable hyperkube { default = "gcr.io/google_containers/hyperkube-amd64" }
variable hyperkube_tag { default = "v1.3.4" }

resource aws_iam_role kube_worker {
    name = "${var.env}-kube_worker_${var.worker_class}"
    path = "/${var.env}/"
    assume_role_policy = "${file("${path.module}/iam/kube_worker-role.json")}"

    provisioner local-exec { command = "sleep 30" }
}

resource aws_iam_role_policy kube_worker_ecr {
    name = "${var.env}-kube_worker_${var.worker_class}-ecr"
    role = "${aws_iam_role.kube_worker.id}"
    policy = "${file("${path.module}/iam/kube_worker-policy-ecr.json")}"
}

resource aws_iam_role_policy kube_worker_instances {
    name = "${var.env}-kube_worker_${var.worker_class}-instances"
    role = "${aws_iam_role.kube_worker.id}"
    policy = "${file("${path.module}/iam/kube_worker-policy-instances.json")}"
}

resource aws_iam_role_policy kube_worker_volumes {
    name = "${var.env}-kube_worker_${var.worker_class}-volumes"
    role = "${aws_iam_role.kube_worker.id}"
    policy = "${file("${path.module}/iam/kube_worker-policy-volumes.json")}"
}

resource aws_iam_instance_profile kube_worker {
    name = "${var.env}-kube_worker_${var.worker_class}-instance"
    roles = [ "${aws_iam_role.kube_worker.name}" ]

    depends_on = [
        "aws_iam_role_policy.kube_worker_ecr",
        "aws_iam_role_policy.kube_worker_instances",
        "aws_iam_role_policy.kube_worker_volumes"
    ]

    provisioner local-exec { command = "sleep 30" }
}

resource coreos_cloudconfig cloud_config {
    gzip = true
    template = "${file("${path.module}/config/cloud-config.yaml")}"

    vars {
        worker_class = "${var.worker_class}"
        kube_controller_url = "${var.controller_url}"
        kube_controller_host = "${replace(var.controller_url, "https://", "")}"

        hyperkube = "${dockerx_push.hyperkube.latest_url}"
        ssh_helper = "${var.ssh_helper_image}"

        region = "${var.region}"
        vault_address = "${var.vault_address}"
        vault_pki_mount = "${var.vault_pki_backend}"
        vault_pki_role = "worker-${var.worker_class}"
        vault_instance_role = "${vaultx_ec2_role.role.role}"
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
    name = "${var.env}-kube-worker-${var.worker_class}-autoscale"

    launch_configuration = "${aws_launch_configuration.worker.name}"
    vpc_zone_identifier = [ "${var.subnets}" ]

    min_size = "${var.min_replicas}"
    max_size = "${var.max_replicas}"
    desired_capacity = "${var.replicas}"

    health_check_grace_period = 300
    health_check_type = "EC2"

    depends_on = [
        "vaultx_policy.worker",
        "vaultx_secret_write_only.worker_role"
    ]

    tag {
        key = "Name"
        value = "${var.env}-kube_worker-${var.worker_class}"
        propagate_at_launch = true
    }

    tag {
        key = "Role"
        value = "worker"
        propagate_at_launch = true
    }

    tag {
        key = "WorkerClass"
        value = "${var.worker_class}"
        propagate_at_launch = true
    }

    tag {
        key = "Environment"
        value = "${var.env}"
        propagate_at_launch = true
    }

    tag {
        key = "KubernetesCluster"
        value = "${var.env}"
        propagate_at_launch = true
    }

    tag {
        key = "VaultRole"
        value = "${vaultx_ec2_role_tag.role_tag.tag_value}"
        propagate_at_launch = true
    }
}
