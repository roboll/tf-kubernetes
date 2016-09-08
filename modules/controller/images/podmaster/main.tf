variable prefix { description = "Container name prefix." }

resource dockerx_build podmaster {
    name = "${var.prefix}-podmaster"
    context_dir = "${replace("${path.module}/docker/", "${path.root}", ".")}"
}

output image { value = "${dockerx_build.podmaster.image}" }
output name { value = "${dockerx_build.podmaster.name}" }
output tag { value = "${dockerx_build.podmaster.tag}" }
