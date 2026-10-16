# Otpus

A tiny, local TOTP (RFC 6238) code generator in Elixir. Paste a base32
secret, read the current one-time code, watch it tick down. Inspired by
[jaden/totp-generator](https://github.com/jaden/totp-generator), rebuilt
with the smallest possible stack: Plug + Bandit, one HTML page, no
Phoenix, no JavaScript build.

Everything runs on `localhost` only. Secrets are never stored or logged.

## Run

Needs Elixir 1.15+ on Erlang/OTP 24+.

```bash
mix deps.get
mix run --no-halt
```

Then open <http://localhost:4000>.

To use another port:

```bash
PORT=8080 mix run --no-halt
```

## Use

- Paste the secret key. Case, spaces, dashes and padding do not matter.
- Click the code to copy it.
- Click the settings chip (it shows the current values, like
  "6 digits · 30s · SHA1") to change code length (4–10), period
  (1–300 seconds) or algorithm (SHA1, SHA256, SHA512).
- The secret is mirrored into the URL fragment (`#SECRET`) so you can
  bookmark an account. Fragments never leave the browser.

## HTTP API

The page polls one endpoint, which you can use directly:

```bash
curl 'localhost:4000/code?secret=JBSWY3DPEHPK3PXP&digits=6&period=30&algorithm=SHA1'
```

```json
{"code":"400020","period":30,"remaining":25}
```

Invalid input returns `400` with `{"error": "...", "field": "..."}`.

## Develop

```bash
mix test
```

The TOTP core (`lib/otpus/totp.ex`) is verified against the RFC 6238
Appendix B test vectors for SHA1, SHA256 and SHA512.

## Why "Otpus"

OTP + octopus. In Elixir land OTP already means two things, so a third
seemed fair.
