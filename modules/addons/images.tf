resource dockerx_build etcd_metrics {
    name = "${var.env}-etcd-metrics"
    context_dir = "${replace("${path.module}/../etcd_metrics/docker/", "${path.root}", ".")}"
}

resource aws_ecr_repository etcd_metrics {
    name = "${var.env}-etcd-metrics"
}

resource aws_ecr_repository_policy etcd_metrics {
    repository = "${aws_ecr_repository.etcd_metrics.name}"
    policy = <<EOF
{
    "Version": "2008-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": "*",
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

resource ecr_push etcd_metrics {
    image = "${dockerx_build.etcd_metrics.image}"
    tag = "${dockerx_build.etcd_metrics.tag}"
    name = "${aws_ecr_repository.etcd_metrics.name}"
    repo = "${replace(aws_ecr_repository.etcd_metrics.repository_url, "/^https://(.*)/.*$/", "$1")}"

    depends_on = [ "aws_ecr_repository_policy.etcd_metrics" ]
}
