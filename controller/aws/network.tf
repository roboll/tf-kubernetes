resource aws_security_group kube_controller {
    vpc_id = "${var.vpc}"

    name = "${var.env}-kube_controller"
    description = "kube controller instances"

    tags {
        Name = "${var.env}-kube_controller"
    }
}

resource aws_security_group_rule kube_controller_egress {
    security_group_id = "${aws_security_group.kube_controller.id}"
    cidr_blocks = [ "0.0.0.0/0" ]

    type = "egress"
    from_port = 0
    to_port = 0
    protocol = "-1"
}

resource aws_security_group_rule kube_controller_ingress_apiserver_elb {
    security_group_id = "${aws_security_group.kube_controller.id}"
    source_security_group_id = "${aws_security_group.kube_controller_elb.id}"

    type = "ingress"
    from_port = 443
    to_port = 443
    protocol = "tcp"
}

resource aws_security_group_rule kube_controller_ingress_flannel_elb {
    security_group_id = "${aws_security_group.kube_controller.id}"
    source_security_group_id = "${aws_security_group.kube_controller_elb.id}"

    type = "ingress"
    from_port = 8888
    to_port = 8888
    protocol = "tcp"
}

resource aws_security_group_rule kube_controller_ingress_self_etcd_server {
    security_group_id = "${aws_security_group.kube_controller.id}"
    self = true

    type = "ingress"
    from_port = 2380
    to_port = 2380
    protocol = "tcp"
}

resource aws_security_group_rule kube_controller_ingress_worker_etcd_metrics {
    security_group_id = "${aws_security_group.kube_controller.id}"
    source_security_group_id = "${aws_security_group.kube_worker.id}"

    type = "ingress"
    from_port = 2381
    to_port = 2381
    protocol = "tcp"
}

resource aws_security_group_rule kube_controller_ingress_vxlan_worker {
    security_group_id = "${aws_security_group.kube_controller.id}"
    source_security_group_id = "${aws_security_group.kube_worker.id}"

    type = "ingress"
    from_port = 8472
    to_port = 8472
    protocol = "udp"
}

resource aws_security_group_rule kube_controller_ingress_kubelet_worker {
    security_group_id = "${aws_security_group.kube_controller.id}"
    source_security_group_id = "${aws_security_group.kube_worker.id}"

    type = "ingress"
    from_port = 10250
    to_port = 10252
    protocol = "tcp"
}

resource aws_security_group kube_controller_elb {
    name = "kube_controller-elb"
    description = "kube controller elb"

    vpc_id = "${var.vpc}"

    tags {
        Name = "${var.env}-kube_controller-elb"
    }
}

resource aws_security_group_rule kube_controller_elb_ingress_apiserver {
    security_group_id = "${aws_security_group.kube_controller_elb.id}"
    cidr_blocks = [ "0.0.0.0/0" ]

    type = "ingress"
    from_port = 443
    to_port = 443
    protocol = "tcp"
}

resource aws_security_group_rule kube_controller_elb_ingress_flannel {
    security_group_id = "${aws_security_group.kube_controller_elb.id}"
    cidr_blocks = [ "0.0.0.0/0" ]

    type = "ingress"
    from_port = 8888
    to_port = 8888
    protocol = "tcp"
}

resource aws_security_group_rule kube_controller_elb_egress_apiserver {
    security_group_id = "${aws_security_group.kube_controller_elb.id}"
    source_security_group_id = "${aws_security_group.kube_controller.id}"

    type = "egress"
    from_port = 443
    to_port = 443
    protocol = "tcp"
}

resource aws_security_group_rule kube_controller_elb_egress_flannel {
    security_group_id = "${aws_security_group.kube_controller_elb.id}"
    source_security_group_id = "${aws_security_group.kube_controller.id}"

    type = "egress"
    from_port = 8888
    to_port = 8888
    protocol = "tcp"
}

resource aws_security_group kube_worker {
    vpc_id = "${var.vpc}"

    name = "${var.env}-kube_worker"
    description = "kube worker instances"

    tags {
        Name = "${var.env}-kube_worker"
        KubernetesCluster = "${var.env}"
    }
}

resource aws_security_group_rule kube_worker_egress {
    security_group_id = "${aws_security_group.kube_worker.id}"
    cidr_blocks = [ "0.0.0.0/0" ]

    type = "egress"
    from_port = 0
    to_port = 0
    protocol = "-1"
}

resource aws_security_group_rule kube_worker_ingress_vxlan_self {
    security_group_id = "${aws_security_group.kube_worker.id}"
    self = true

    type = "ingress"
    from_port = 8472
    to_port = 8472
    protocol = "udp"
}

resource aws_security_group_rule kube_worker_ingress_vxlan_controller {
    security_group_id = "${aws_security_group.kube_worker.id}"
    source_security_group_id = "${aws_security_group.kube_controller.id}"

    type = "ingress"
    from_port = 8472
    to_port = 8472
    protocol = "udp"
}

resource aws_security_group_rule kube_worker_ingress_kubelet_controller {
    security_group_id = "${aws_security_group.kube_worker.id}"
    source_security_group_id = "${aws_security_group.kube_controller.id}"

    type = "ingress"
    from_port = 10250
    to_port = 10250
    protocol = "tcp"
}

resource null_resource network {
    depends_on = [
        "aws_security_group_rule.kube_controller_egress",
        "aws_security_group_rule.kube_controller_ingress_apiserver_elb",
        "aws_security_group_rule.kube_controller_ingress_self_etcd_server",
        "aws_security_group_rule.kube_controller_ingress_worker_etcd_metrics",
        "aws_security_group_rule.kube_controller_ingress_vxlan_worker",
        "aws_security_group_rule.kube_controller_ingress_kubelet_worker",
        "aws_security_group_rule.kube_worker_egress",
        "aws_security_group_rule.kube_worker_ingress_vxlan_self",
        "aws_security_group_rule.kube_worker_ingress_vxlan_controller",
        "aws_security_group_rule.kube_worker_ingress_kubelet_controller"
    ]
}
