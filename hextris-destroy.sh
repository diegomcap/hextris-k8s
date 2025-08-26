#!/usr/bin/env bash
set -euo pipefail

# Script simples para EXCLUIR o Hextris do cluster (Terraform em modo external/Minikube)
# Uso:
#   ./hextris-destroy.sh

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$ROOT_DIR/terraform"

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Erro: comando '$cmd' não encontrado. Instale-o e tente novamente." >&2
    exit 1
  fi
}

# Verificações mínimas
require_cmd terraform
require_cmd minikube
require_cmd kubectl

# Garantir que o kubecontext do minikube está correto (não falhar caso minikube não esteja rodando)
echo "[+] Atualizando contexto do kubectl (minikube)..."
minikube update-context >/dev/null 2>&1 || true

# Destruir com Terraform (modo external)
echo "[+] Destruindo recursos do Hextris via Terraform (cluster_mode=external)..."
(
  cd "$TF_DIR"
  terraform init -input=false >/dev/null
  terraform destroy -auto-approve -var='cluster_mode=external'
)

echo "[✓] Remoção concluída. Se desejar, você pode também remover o namespace manualmente com:\n    kubectl delete ns hextris"