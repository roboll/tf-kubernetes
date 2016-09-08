resource docker_image hyperkube {
    name = "${var.hyperkube}:${var.hyperkube_tag}"
    keep_locally = true
}

module podmaster {
    source = "../images/podmaster/"

    prefix = "${var.env}-kube-controller"
}

resource aws_ecr_repository hyperkube {
    name = "${var.env}-kube-controller-hyperkube"
}

resource aws_ecr_repository podmaster {
    name = "${module.podmaster.name}"
}

resource template_file ecr_pull_policy {
    template = "${file("${path.module}/ecr/pull-policy.json")}"

    vars { role = "${aws_iam_role.kube_controller.arn}" }
}

resource aws_ecr_repository_policy hyperkube {
    repository = "${aws_ecr_repository.hyperkube.name}"
    policy = "${template_file.ecr_pull_policy.rendered}"
}

resource aws_ecr_repository_policy podmaster {
    repository = "${aws_ecr_repository.podmaster.name}"
    policy = "${template_file.ecr_pull_policy.rendered}"
}

resource dockerx_push hyperkube {
    image = "${var.hyperkube}"
    tag = "${var.hyperkube_tag}"
    name = "${aws_ecr_repository.hyperkube.name}"
    repo = "${replace(aws_ecr_repository.hyperkube.repository_url, "/^https://(.*)/.*$/", "$1")}"

    ecr_region = "${var.region}"

    depends_on = [ "docker_image.hyperkube", "aws_ecr_repository_policy.hyperkube" ]
}

resource dockerx_push podmaster {
    image = "${module.podmaster.image}"
    tag = "${module.podmaster.tag}"
    name = "${aws_ecr_repository.podmaster.name}"
    repo = "${replace(aws_ecr_repository.podmaster.repository_url, "/^https://(.*)/.*$/", "$1")}"

    ecr_region = "${var.region}"

    depends_on = [ "aws_ecr_repository_policy.podmaster" ]
}
