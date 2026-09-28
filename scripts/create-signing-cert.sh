#!/usr/bin/env bash
# Crea (una tantum) un certificato self-signed per la firma del codice nel portachiavi login.
# Con una firma stabile macOS ricorda i permessi (Calendario, Promemoria, Posizione, Mail) tra una build e l'altra.
set -euo pipefail

NAME="${SIGN_IDENTITY:-Personal Dashboard Dev}"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -p codesigning | grep -q "\"$NAME\""; then
    echo "Il certificato \"$NAME\" esiste già."
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -config "$TMP/cert.cnf" -keyout "$TMP/key.pem" -out "$TMP/cert.pem" 2>/dev/null
openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -out "$TMP/identity.p12" -passout pass:temp 2>/dev/null

security import "$TMP/identity.p12" -k "$KEYCHAIN" -P temp -T /usr/bin/codesign
echo "Certificato \"$NAME\" importato. Se codesign chiede l'accesso al portachiavi, scegli \"Consenti sempre\"."
