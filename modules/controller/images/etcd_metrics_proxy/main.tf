variable prefix { description = "Container name prefix." }

resource dockerx_build proxy {
    name = "${var.prefix}-etcd-metrics-proxy"
    context_dir = "${replace("${path.module}/docker/", "${path.root}", ".")}"
}

output image { value = "${dockerx_build.proxy.image}" }
output name { value = "${dockerx_build.proxy.name}" }
output tag { value = "${dockerx_build.proxy.tag}" }
