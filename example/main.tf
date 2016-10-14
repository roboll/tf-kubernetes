###############################################################################
# variables
###############################################################################
variable aws_account_id {}
variable aws_region {}

variable vault_address {}
variable vault_ca_cert_file {}

variable env {}
variable vpc {}
variable subnets { type = "list" }
variable subnet_cidrs { type = "list" }

variable ssh_keypair {}

variable domain {}
variable dns_zone_id {}
variable security_groups {}

###############################################################################
# providers
###############################################################################
provider aws {
    region = "${var.aws_region}"

    allowed_account_ids = [
        "${var.aws_account_id}"
    ]
}

provider vaultx {
    address = "${var.vault_address}"
}

###############################################################################
# config
###############################################################################
module primary_coreos {
    source = "github.com/roboll/terraform-coreos//modules/image/aws/"

    region = "${var.aws_region}"
    release_channel = "stable"
}

module secondary_coreos {
    source = "github.com/roboll/terraform-coreos//modules/image/aws/"

    region = "${var.aws_region}"
    release_channel = "stable"
}

###############################################################################
# kube controller
###############################################################################
variable kube_version {}

variable controller_instance_type { default = "m4.large" }
variable controller_ebs_optimized { default = false }
variable controller_replicas { default = 3 }

module primary_controller {
    source = "github.com/roboll/terraform-kubernetes//controller/aws/"

    env = "${var.env}"
    region = "${var.aws_region}"

    vpc = "${var.vpc}"
    subnets = [ "${var.subnets}" ]
    subnet_cidrs = [ "${var.subnet_cidrs}" ]

    ssh_keypair = "${var.ssh_keypair}"

    vault_address = "${var.vault.address}"
    vault_ca_cert_pem = "${file(var.vault_ca_cert_file)}"

    domain = "${var.domain}"
    dns_zone_id = "${var.dns_zone_id}"
    security_groups = [ "${var.security_groups}" ]

    image_id = "${module.primary_coreos.id}"
    replicas = "${var.controller_replicas}"
    instance_type = "${var.controller_instance_type}"
    ebs_optimized = "${var.controller_ebs_optimized}"

    kube_version = "${var.kube_version}"
}

output kube_address { value = "${module.primary_controller.address}" }

###############################################################################
# kube workers
###############################################################################
variable basic_worker_instance_type { default = "m4.large" }
variable basic_worker_ebs_optimized { default = false }
variable basic_worker_min_replicas { default = 1 }
variable basic_worker_max_replicas { default = 5 }
variable basic_worker_replicas { default = 3 }

module primary_basic_worker {
    source = "github.com/roboll/terraform-kubernetes//worker/aws/"

    env = "${var.env}"
    region = "${var.aws_region}"

    vpc = "${var.vpc}"
    subnets = [ "${var.subnets}" ]

    ssh_keypair = "${var.ssh_keypair}"

    vault_address = "${var.vault.address}"
    vault_ca_cert_pem = "${file(var.vault_ca_cert_file)}"

    security_groups = [
        "${var.security_groups}",
        "${module.primary_controller.worker_security_group}" ]

    image_id = "${module.primary_coreos.id}"
    replicas = "${var.basic_worker_replicas}"
    min_replicas = "${var.basic_worker_min_replicas}"
    max_replicas = "${var.basic_worker_max_replicas}"
    instance_type = "${var.basic_worker_instance_type}"
    ebs_optimized = "${var.basic_worker_ebs_optimized}"

    worker_class = "basic"
    controller_fqdn = "${module.primary_controller.fqdn}"
    kube_pki_backend = "${module.primary_controller.kube_pki_backend}"

    kube_version = "${var.kube_version}"
}

###############################################################################
# kube access
###############################################################################
resource vaultx_secret primary_kube_user_role {
    path = "${module.primary_controller.kube_pki_backend}/roles/user"
    ignore_read = true

    data {
        allowed_domains = "kube-users.local"
        allow_subdomains = true
        allow_localhost = false
        server_flag = false
        key_type = "ec"
        key_bits = "256"
        max_ttl = "48h"
    }
}

resource vaultx_policy primary_kube_user_policy {
    name = "${lookup(data.terraform_remote_state.env.envs, "primary")}-kube-user"

    rules = <<EOF
path "${module.primary_controller.kube_pki_backend}/issue/user" {
    capabilities = [ "create", "read", "update", "list" ]
}
EOF
}

resource vaultx_secret primary_kube_admin_role {
    path = "${module.primary_controller.kube_pki_backend}/roles/admin"
    ignore_read = true

    data {
        allowed_domains = "admin"
        allow_bare_domains = true
        allow_subdomains = false
        allow_localhost = false
        server_flag = false
        key_type = "ec"
        key_bits = "256"
        max_ttl = "48h"
    }
}

resource vaultx_policy primary_kube_admin_policy {
    name = "${lookup(data.terraform_remote_state.env.envs,"primary")}-kube-admin"

    rules = <<EOF
path "${module.primary_controller.kube_pki_backend}/issue/admin" {
    capabilities = [ "create", "read", "update", "list" ]
}
EOF
}
