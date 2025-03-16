[![CI](https://github.com/krydos/gemini-server/actions/workflows/ci.yml/badge.svg)](https://github.com/krydos/gemini-server/actions/workflows/ci.yml)

# Gemini Server

Gemini server implementation in just ~150 lines of code (with comments).

I currently run this server for my personal capsule [gemini://g.codelearn.me](gemini://g.codelearn.me).

To start the server run:

```
gemini-server /absolute/path/capsule/root/folder 1965 certificate.crt private.key
```

## Build

Just run `zig build`.

I'm using zig build from master so the build may not work even on the current release version.

## Generate Certificates

Generate private.key:
`openssl genrsa -out private.key 2048`

Generate CSR (Certificate Signing Request):
`openssl req -new -key private.key -out org.csr`

Generate Self-Signed SSL Certificate:
`openssl x509 -req -days 365 -in org.csr -signkey private.key -out certificate.crt`
