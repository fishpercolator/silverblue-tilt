#!/bin/bash

prep_environment () {
  if [ -f /run/.containerenv ]; then
    echo "Please don't run this inside a container" >&2
    exit 1
  fi
  mkdir -p ~/.local/bin
  mkdir -p ~/.config/containers/registries.conf.d
}

kubectl_out_of_date () {
  current_version=$(command -v kubectl &>/dev/null && (kubectl version --client -o yaml | grep gitVersion | sed -e 's/.* //') || true)
  latest_version=$(curl -Ls https://dl.k8s.io/release/stable.txt)
  if [ "${current_version}" == "${latest_version}" ]; then
    echo "Kubectl: ${current_version} ✅"
    return 0
  else
    echo "Kubectl: ${current_version:=Not installed} ➡️  ${latest_version} ❌"
    return 1
  fi
}

install_kubectl () {
  echo "Installing kubectl ${latest_version}..."
  install <(curl -Ls "https://dl.k8s.io/release/${latest_version}/bin/linux/amd64/kubectl") ~/.local/bin/kubectl
}

kind_out_of_date () {
  current_version=$(command -v kind &>/dev/null && echo "v$(kind version -q)" || true )
  latest_version=$(curl -s https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | grep tag_name | sed -e 's/.*: "\(.*\)".*/\1/')
  if [ "${current_version}" == "${latest_version}" ]; then
    echo "Kind: ${current_version} ✅"
    return 0
  else
    echo "Kind: ${current_version:=Not installed} ➡️  ${latest_version} ❌"
    return 1
  fi
}

install_kind () {
  echo "Installing kind ${latest_version}..."
  install <(curl -Ls "https://github.com/kubernetes-sigs/kind/releases/download/${latest_version}/kind-linux-amd64") ~/.local/bin/kind
}

helm_out_of_date () {
  current_version=$(command -v helm &>/dev/null && (helm version --short | sed -e 's/\+.*//') || true)
  latest_version=$(curl -s https://get.helm.sh/helm-latest-version)
  if [ "${current_version}" == "${latest_version}" ]; then
    echo "Helm: ${current_version} ✅"
    return 0
  else
    echo "Helm: ${current_version:=Not installed} ➡️  ${latest_version} ❌"
    return 1
  fi
}

install_helm () {
  echo "Installing helm ${latest_version}..."
  install <(curl -s https://get.helm.sh/helm-${latest_version}-linux-amd64.tar.gz | tar -xOzf - linux-amd64/helm) ~/.local/bin/helm
}

tilt_out_of_date () {
  current_version=$(command -v tilt &>/dev/null && (tilt version | sed -e 's/v\(.*\),.*/\1/') || true)
  latest_version=$(curl -s https://raw.githubusercontent.com/tilt-dev/tilt/master/scripts/install.sh | grep ^VERSION= | sed -e 's/.*"\(.*\)"/\1/')
  if [ "${current_version}" == "${latest_version}" ]; then
    echo "Tilt: ${current_version} ✅"
    return 0
  else
    echo "Tilt: ${current_version:=Not installed} ➡️  ${latest_version} ❌"
    return 1
  fi
}

install_tilt () {
  echo "Installing tilt ${latest_version}..."
  install <(curl -Ls https://github.com/tilt-dev/tilt/releases/download/v${latest_version}/tilt.${latest_version}.linux.x86_64.tar.gz | tar -xOzf - tilt) ~/.local/bin/tilt
}

insecure_registry () {
  if [ ! -f ~/.config/containers/registries.conf.d/kind.conf ]; then
    tee ~/.config/containers/registries.conf.d/kind.conf <<EOF
[[registry]]
location = "localhost:${reg_port}"
insecure = true
EOF
  fi
}

create_registry () {
  case $(podman inspect -f '{{.State.Running}}' "${reg_name}" 2>/dev/null || true) in
  false)
    echo "Starting previously configured registry..."
    podman start ${reg_name}
    ;;
  true)
    echo "Registry is already running"
    ;;
  *)
    echo "Creating registry..."
    podman run \
      -d --restart=always -p "127.0.0.1:${reg_port}:5000" --network bridge --name "${reg_name}" \
      registry:2
    ;;
  esac
}

start_cluster () {
  case $(podman inspect -f '{{.State.Running}}' kind-control-plane 2>/dev/null || true) in
  false)
    echo "Starting previously configured cluster..."
    podman start kind-control-plane
    ;;
  true)
    echo "Cluster is already running"
    ;;
  *)
    echo "Creating Kubernetes cluster..."
    # Add this patch config until https://github.com/kubernetes-sigs/kind/issues/2875 is resolved
    cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry]
    config_path = "/etc/containerd/certs.d"
EOF
    ;;
  esac
  # Now check it's the current kube context on the system
  kube_context=$(kubectl config current-context)
  if [ "$kube_context" != 'kind-kind' ]; then
    echo "Current context is not right (it's ${kube_context})"
    exit 1
  fi
}

add_registry_to_kind () {
  echo "Mapping registry hostname inside cluster..."
  REGISTRY_DIR="/etc/containerd/certs.d/localhost:${reg_port}"
  for node in $(kind get nodes); do
    podman exec "${node}" mkdir -p "${REGISTRY_DIR}"
    cat <<EOF | podman exec -i "${node}" cp /dev/stdin "${REGISTRY_DIR}/hosts.toml"
[host."http://${reg_name}:5000"]
EOF
  done
  if [ "$(podman inspect -f='{{json .NetworkSettings.Networks.kind}}' "${reg_name}")" = 'null' ]; then
    echo "Attaching registry to kind network..."
    podman network connect "kind" "${reg_name}"
  fi
  # https://github.com/kubernetes/enhancements/tree/master/keps/sig-cluster-lifecycle/generic/1755-communicating-a-local-registry
  echo "Adding or updating local-registry-hosting configmap..."
  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${reg_port}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF
}

prep_environment

echo "Checking versions..."
kubectl_out_of_date || install_kubectl
kind_out_of_date || install_kind
helm_out_of_date || install_helm
tilt_out_of_date || install_tilt

echo
echo "Configuring kind..."
# This is based on https://kind.sigs.k8s.io/docs/user/local-registry/
reg_name='kind-registry'
reg_port='5001'
insecure_registry
create_registry
start_cluster
add_registry_to_kind
