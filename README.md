# SMS Code Filler

A **Firefox add-on for macOS** that reads the SMS **phone-verification codes** that
get forwarded to your Mac's **Messages.app** and **auto-fills** them into the code
box — and auto-submits, so you don't have to type or click anything.

## How it works

1. A small background **helper** (a Login LaunchAgent) reads the Messages database
   (with **Full Disk Access**) and caches the recent verification codes.
2. The add-on detects the verification-code field on a page, picks the code that
   matches the site (e.g. "Best Buy"), fills it, and presses Enter / clicks Submit.
3. Auto-fill only uses codes received in the **last 30 minutes**; used codes are
   removed from the list. It never fills **password/username/email** fields.

## Files

| File | What it is |
|------|------------|
| `sms-code-filler-1.1.8-signed.xpi` | The Firefox add-on (signed by Mozilla/AMO, installs without warnings) |
| `install.sh` | Installs the native host + reader (run this) |
| `dist/arm64/`, `dist/x86_64/` | The compiled host + reader + libpython — **self-contained**, **Developer-ID signed + notarized** (no Python/Xcode/CLT needed) |
| `SETUP.md` | Full step-by-step installation guide |

## Requirements

- **macOS:** Apple Silicon → 11.0+ • Intel → 10.15+
- **Firefox:** 142+
- **An iPhone** with **Text Message Forwarding** enabled to this Mac (so SMS codes
  arrive in **Messages.app** on the Mac).

## Install

See **[SETUP.md](SETUP.md)**. In short:

1. Install the add-on: Firefox → `about:addons` → gear ⚙ → **Install Add-on From File…** → pick the `.xpi`.
2. From this folder run `bash install.sh` (it needs `dist/` alongside — already here).
3. Grant **Full Disk Access** to
   `~/Library/Application Support/SMSFiller/sms_reader`.
4. On your iPhone: **Settings → Messages → Text Message Forwarding → enable this Mac**.
5. Restart Firefox, open a site's verification page, request a code — it auto-fills + submits.

## Security & privacy

- Reads **your own** SMS codes **locally** — nothing is sent anywhere (no telemetry, no server).
- The binaries are signed by the developer (Apple **Developer ID**) and **notarized**;
  the add-on is signed by **Mozilla (AMO)**.
- **Full Disk Access** is a macOS privacy grant the reader needs to read Messages;
  only enable it if you trust the source.
