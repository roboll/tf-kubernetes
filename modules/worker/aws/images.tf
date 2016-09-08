resource docker_image hyperkube {
    name = "${var.hyperkube}:${var.hyperkube_tag}"
    keep_locally = true
}

resource aws_ecr_repository hyperkube {
    name = "${var.env}-kube-worker-${var.worker_class}-hyperkube"
}

resource template_file ecr_pull_policy {
    template = "${file("${path.module}/ecr/pull-policy.json")}"

    vars { role = "${aws_iam_role.kube_worker.arn}" }
}

resource aws_ecr_repository_policy hyperkube {
    repository = "${aws_ecr_repository.hyperkube.name}"
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
