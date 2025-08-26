#!/usr/bin/env bash
set -euo pipefail

# Script de automação para criar e excluir o Hextris no Kubernetes via Minikube + Terraform (modo externo)
# Uso:
#   ./hextris.sh up       # cria/atualiza o jogo
#   ./hextris.sh down     # exclui o jogo
#   ./hextris.sh status   # mostra status do deployment/serviço
#   ./hextris.sh help     # ajuda

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$ROOT_DIR/terraform"

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Erro: comando '$cmd' não encontrado. Instale-o e tente novamente." >&2
    exit 1
  fi
}

require_all() {
  for c in "$@"; do
    require_cmd "$c"
  done
}

ensure_minikube() {
  echo "[+] Verificando Minikube..."
  if ! minikube status >/dev/null 2>&1; then
    echo "[+] Iniciando Minikube (hyperkit, 2 CPU, 4GB RAM, 20GB disco)..."
    minikube start --driver=hyperkit --cpus=2 --memory=4096 --disk-size=20g
  else
    echo "[✓] Minikube já está em execução."
  fi
  echo "[+] Atualizando contexto do kubectl..."
  minikube update-context >/dev/null
}

build_image() {
  echo "[+] Construindo imagem hextris:local dentro do Docker do Minikube..."
  # Aponta o docker CLI para o daemon interno do Minikube
  eval "$(minikube docker-env)"
  docker build -t hextris:local "$ROOT_DIR"
  # Desfaz alterações de ambiente do docker-env
  eval "$(minikube docker-env -u)"
}

tf_apply() {
  echo "[+] Aplicando Terraform (modo externo)..."
  pushd "$TF_DIR" >/dev/null
  terraform init -input=false
  terraform apply -auto-approve -var='cluster_mode=external'
  popd >/dev/null
}

tf_destroy() {
  echo "[+] Destruindo instalação do Hextris via Terraform (modo externo)..."
  pushd "$TF_DIR" >/dev/null
  terraform destroy -auto-approve -var='cluster_mode=external'
  popd >/dev/null
}

rollout_wait() {
  echo "[+] Aguardando rollout do deployment..."
  kubectl -n hextris rollout status deploy/hextris --timeout=180s || true
  kubectl -n hextris get pods,svc -o wide || true
}

print_url() {
  local url="http://$(minikube ip):30080"
  echo "[✓] Acesse o Hextris em: $url"
}

status_info() {
  echo "[+] Contexto atual: $(kubectl config current-context || true)"
  echo "[+] Cluster info:" && kubectl cluster-info || true
  echo "[+] Recursos em hextris:" && kubectl -n hextris get svc,pods -o wide || true
  echo "[+] Helm release:" && helm -n hextris status hextris || true
}

usage() {
  cat <<EOF
Uso: $0 <comando>

Comandos:
  up       Cria/atualiza o jogo no cluster (Minikube + Terraform)
  down     Exclui o jogo (terraform destroy)
  status   Mostra status do deployment/serviço
  help     Mostra esta ajuda
EOF
}

main() {
  local cmd="${1:-help}"
  case "$cmd" in
    up|apply|create)
      require_all minikube kubectl terraform helm docker
      ensure_minikube
      build_image
      tf_apply
      rollout_wait
      print_url
      ;;
    down|destroy|delete)
      require_all minikube kubectl terraform helm
      ensure_minikube
      tf_destroy
      ;;
    status)
      require_all minikube kubectl helm
      ensure_minikube
      status_info
      ;;
    help|--help|-h)
      usage
      ;;
    *)
      echo "Comando inválido: $cmd" >&2
      usage
      exit 1
      ;;
  esac
}

main "$@"