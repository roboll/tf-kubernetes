resource docker_image hyperkube {
    name = "${var.hyperkube}:${var.hyperkube_tag}"
    keep_locally = true
}

resource dockerx_build podmaster {
    name = "${var.prefix}-podmaster"
    context_dir = "${replace("${path.module}/../podmaster/docker/", "${path.root}", ".")}"
}

resource aws_ecr_repository hyperkube {
    name = "${var.env}-kube-controller-hyperkube"
}

resource aws_ecr_repository podmaster {
    name = "${dockerx_build.podmaster.name}"
}

resource aws_ecr_repository_policy hyperkube {
    repository = "${aws_ecr_repository.hyperkube.name}"
    policy = <<EOF
{
    "Version": "2008-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": [ "${aws_iam_role.kube_controller.arn}" ]
            },
            "Action": [
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:BatchCheckLayerAvailability"
            ]
        }
    ]
}
EOF
}

resource aws_ecr_repository_policy podmaster {
    repository = "${aws_ecr_repository.podmaster.name}"
    policy = <<EOF
{
    "Version": "2008-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": [ "${aws_iam_role.kube_controller.arn}" ]
            },
            "Action": [
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:BatchCheckLayerAvailability"
            ]
        }
    ]
}
EOF
}

resource ecr_push hyperkube {
    image = "${var.hyperkube}"
    tag = "${var.hyperkube_tag}"
    name = "${aws_ecr_repository.hyperkube.name}"
    repo = "${replace(aws_ecr_repository.hyperkube.repository_url, "/^https://(.*)/.*$/", "$1")}"

    depends_on = [ "docker_image.hyperkube", "aws_ecr_repository_policy.hyperkube" ]
}

resource ecr_push podmaster {
    image = "${dockerx_build.podmaster.image}"
    tag = "${dockerx_build.podmaster.tag}"
    name = "${aws_ecr_repository.podmaster.name}"
    repo = "${replace(aws_ecr_repository.podmaster.repository_url, "/^https://(.*)/.*$/", "$1")}"

    depends_on = [ "aws_ecr_repository_policy.podmaster" ]
}
