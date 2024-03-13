#!/bin/bash

prep_environment () {
  if [ -f /run/.containerenv ]; then
    echo "Please don't run this inside a container" >&2
    exit 1
  fi
  mkdir -p ~/.local/bin
  mkdir -p ~/.config/containers
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
  install <(curl https://get.helm.sh/helm-${latest_version}-linux-amd64.tar.gz | tar -xOzf - linux-amd64/helm) ~/.local/bin/helm
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

prep_environment

echo "Checking versions..."
kubectl_out_of_date || install_kubectl
kind_out_of_date || install_kind
helm_out_of_date || install_helm
tilt_out_of_date || install_tilt
