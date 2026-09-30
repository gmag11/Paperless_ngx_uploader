#!/usr/bin/env bash
#
# Generates throwaway certificates for the mutual-TLS tests under test/fixtures.
# These certificates are only usable against the in-process test server; they
# MUST NOT be used for anything else.
#
# Usage: scripts/generate_test_certs.sh [output-dir]
set -euo pipefail

DIR="${1:-test/fixtures}"
mkdir -p "$DIR"
cd "$DIR"

PKCS12_PASSWORD="testpass"

# --- Certificate authority -------------------------------------------------
openssl req -x509 -newkey rsa:2048 -nodes -keyout ca.key -out ca.crt -days 3650 \
  -subj "/CN=Paperless Uploader Test CA"

# --- Server certificate (SAN localhost) ------------------------------------
openssl req -newkey rsa:2048 -nodes -keyout server.key -out server.csr \
  -subj "/CN=localhost"
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out server.crt -days 3650 \
  -extfile <(printf "subjectAltName=DNS:localhost,IP:127.0.0.1")

# --- Client certificate ----------------------------------------------------
openssl req -newkey rsa:2048 -nodes -keyout client.key -out client.csr \
  -subj "/CN=paperless-client"
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out client.crt -days 3650

# --- PKCS#12 bundle of the client certificate ------------------------------
openssl pkcs12 -export -out client.p12 -inkey client.key -in client.crt \
  -certfile ca.crt -passout "pass:$PKCS12_PASSWORD"

rm -f server.csr client.csr ca.srl

echo "Test certificates written to $DIR"
