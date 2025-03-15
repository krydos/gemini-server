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
