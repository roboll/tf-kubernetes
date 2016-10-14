# terraform-kubernetes

Infrastructure provisioning and Kubernetes cluster configuration.

## About

* Provision infrastructure with [terraform](https://terraform.io).
* Initialize [coreos](https://coreos.com) hosts with cloud-config.
* Secure cluster access with [vault](https://vaultproject.io) pki backend.

### Provisioning

Currently, AWS infrastructure is supported. The network infrastructure is provided as a reference; the cluster does not rely on specific subnet allocations or public/private access. A cluster may be provisioned in an existing VPC, however Kubernetes currently does not support resource sharing, so each cluster must have independant resources tagged with `KubernetesCluster` tags.

#### Dependencies

* [terraform-vault](https://github.com/roboll/terraform-vault) for configuring pki and controller secret storage

### Initialization

Simple and repeatable initialization is managed by cloud-config and systemd. During initialization, hosts are authenticated and join the cluster. When the controller instances are initialized for the first time (or after a total failure), a bootstrapping process configures the necessary cluster components.

The primary Kubernetes unit is the [kubelet](http://kubernetes.io/docs/admin/kubelet/). It requires a signed certificate to communicate with the Kubernetes apiserver, which is obtained from vault. It runs on both worker and controller instances in the cluster, however controller instances are configured to only accept specific workloads of Kubernetes components.

#### Vault Authentication

[`vault-login.service`](modules/controller/aws/config/cloud-config.yaml#L47) authenticates using the [aws-ec2 backend](https://www.vaultproject.io/docs/auth/aws-ec2.html). Once authenticated, [`vault-renew-token.service`](modules/controller/aws/config/cloud-config.yaml#L56) and [`vault-renew-token.timer`](modules/controller/aws/config/cloud-config.yaml#L62) renew the token every 12 hours.

#### Vault Certificate Issuing

[`kubelet-certs.service`](modules/controller/aws/config/cloud-config.yaml#L148) obtains a signed certificate / private key pair from the [pki backend](https://www.vaultproject.io/docs/secrets/pki/index.html). Certificates are rotated every 12 hours by [`kubelet-certs.timer`](modules/controller/aws/config/cloud-config.yaml#L160).

After certificates are rotated, systemd restarts the kubelet to realize the new configuration.

#### Controller Bootstrapping

When controller instances are initialized for the first time, the first controller instance,
`controller0`, begins a bootstrap sequence.

1. Link bootstrap components `apiserver` and `controller-manager` to kubelet config dir.
2. Wait for `bootstrap-apiserver` to become available.
3. Using `curl`, create controller components and initial configuration.
4. Wait for `bootstrap-controller-manager` to schedule the controller components.
5. Unlink bootstrap components from the kubelet config dir.

## Usage

Provisioning uses [terraform](https://terraform.io). Once the cluster is initialized, configure [`kubectl`](http://kubernetes.io/docs/user-guide/kubectl-overview/) for access using `kube-vault.sh` - it is an exercise for the user to distribute this script.

There is an [example](example) for reference.

### Failure Recovery

**If the master instances fail**, all instances of the `controller-manager` will be lost, and nothing will reschedule it. In this case, on `controller0`, re-run `/opt/bin/init-kube.sh`. This will link the bootstrap components and allow them to schedule the daemon sets.

**If storage on the master instances is lost**, recovery is not possible without data backups. In this case, it is recommended to provision a new cluster and recreate the workload.
