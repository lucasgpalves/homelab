#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
CERT_DIR="${ROOT_DIR}/certs"
BIN_DIR="${ROOT_DIR}/.bin"
MKCERT_VERSION="v1.4.4"
MKCERT_BIN="${BIN_DIR}/mkcert"

mkdir -p "${CERT_DIR}" "${BIN_DIR}"

if [[ ! -x "${MKCERT_BIN}" ]]; then
  echo "Baixando mkcert ${MKCERT_VERSION}..."
  curl -fsSL \
    "https://github.com/FiloSottile/mkcert/releases/download/${MKCERT_VERSION}/mkcert-${MKCERT_VERSION}-linux-amd64" \
    -o "${MKCERT_BIN}"
  chmod +x "${MKCERT_BIN}"
fi

export CAROOT="${CERT_DIR}"

echo "Gerando CA local e certificado para *.lab.home.arpa..."
"${MKCERT_BIN}" -cert-file "${CERT_DIR}/homelab.pem" \
  -key-file "${CERT_DIR}/homelab-key.pem" \
  "*.lab.home.arpa" "lab.home.arpa" localhost 127.0.0.1

echo
echo "Pronto."
echo "  Certificado: ${CERT_DIR}/homelab.pem"
echo "  Chave:       ${CERT_DIR}/homelab-key.pem"
echo "  CA (Windows): ${CERT_DIR}/rootCA.pem"
echo
echo "No Windows, importe rootCA.pem em 'Autoridades de Certificação Raiz Confiáveis'."
