#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="$(pwd)/.pki/out"
mkdir -p "$OUT_DIR"

# Certificate variables
CA_KEY="$OUT_DIR/ca.key"
CA_CRT="$OUT_DIR/ca.crt"
APISERVER_KEY="$OUT_DIR/apiserver.key"
APISERVER_CSR="$OUT_DIR/apiserver.csr"
APISERVER_CRT="$OUT_DIR/apiserver.crt"
SA_KEY="$OUT_DIR/sa.key"
SA_PUB="$OUT_DIR/sa.pub"

# Generate CA
openssl genrsa -out "$CA_KEY" 4096
openssl req -x509 -new -nodes -key "$CA_KEY" -subj "/CN=kind-local-ca" -days 3650 -out "$CA_CRT"

# Generate API server key and CSR
openssl genrsa -out "$APISERVER_KEY" 2048
openssl req -new -key "$APISERVER_KEY" -subj "/CN=kube-apiserver" -out "$APISERVER_CSR"

# Create SAN config for apiserver cert
cat > "$OUT_DIR/apiserver-ext.cnf" <<EOF
[ v3_ext ]
subjectAltName = DNS:kubernetes,DNS:kubernetes.default,DNS:kubernetes.default.svc,DNS:kubernetes.default.svc.cluster.local,IP:127.0.0.1
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
EOF

# Sign API server cert with CA
openssl x509 -req -in "$APISERVER_CSR" -CA "$CA_CRT" -CAkey "$CA_KEY" -CAcreateserial -out "$APISERVER_CRT" -days 365 -sha256 -extfile "$OUT_DIR/apiserver-ext.cnf" -extensions v3_ext

# Generate service account signing key (RSA)
openssl genrsa -out "$SA_KEY" 2048
openssl rsa -in "$SA_KEY" -pubout -out "$SA_PUB"

chmod 0600 "$CA_KEY" "$APISERVER_KEY" "$SA_KEY"
chmod 0644 "$CA_CRT" "$APISERVER_CRT" "$SA_PUB"

echo "Generated PKI in $OUT_DIR"
ls -l "$OUT_DIR"
