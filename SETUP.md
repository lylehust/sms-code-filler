# SMS Code Filler — Installation Guide

A Firefox add-on that reads the **SMS verification codes** forwarded to your Mac's
**Messages.app** and auto-fills them into the code box (and auto-submits). This guide
takes a fresh Mac from zero to working in ~5 minutes.

---

## What you need to install

Get the project folder (it already contains `install.sh`, the `dist/` binaries, and
this guide), plus the add-on file:

| What | It is |
|------|-------|
| `sms-code-filler-1.1.8-signed.xpi` | The Firefox add-on |
| `install.sh` + `dist/` | The macOS native host + reader (compiled, signed binaries) |

> Download/clone it from `github.com/lylehust/sms-code-filler` — no zip needed.
> (The repo has `install.sh`, `dist/arm64/` + `dist/x86_64/`, the `.xpi`, and this guide.)

---

## Requirements on the computer

- **macOS:** Apple Silicon (M1/M2/M3/M4) → macOS **11.0+**; Intel → macOS **10.15+**.
- **Firefox:** version **142+** (the add-on's minimum).
- **iPhone** (for SMS forwarding — see step 4), signed into the **same Apple ID** as the Mac.

The host/reader binaries are **self-contained** and **Developer-ID signed + notarized** —
they bundle their own Python, and need **no Python, Xcode, or Command Line Tools**.

---

## Step 1 — Install the Firefox add-on (`.xpi`)

1. Open Firefox.
2. Go to **`about:addons`**.
3. Click the **gear ⚙** (top-right) → **Install Add-on From File…**.
4. In the picker press **`Cmd+Shift+G`**, paste the path to the `.xpi`, select it, click **Open**.
5. Confirm the install → **Add**.
6. Verify it appears in **Extensions** (and is enabled).

> If you get a dialog saying the add-on isn't verified, use **Install Add-on From File**
> again and it will install — it's signed by Mozilla (AMO).

---

## Step 2 — Install the native host

1. Unzip (or `git clone`) the project. The folder should contain `install.sh`
   and a `dist/` folder with the binaries.
2. Open **Terminal** and run:
   ```bash
   cd ~/Downloads/sms-code-filler   # or wherever the folder is
   bash install.sh
   ```
   This installs the correct binaries for your Mac (Apple Silicon or Intel) into
   `~/Library/Application Support/SMSFiller/`, registers the native-messaging
   manifest for Firefox, and starts the background **reader**.

---

## Step 3 — Grant Full Disk Access to the READER (required)

The reader needs permission to read your Messages database. Grant it once:

1. **System Settings → Privacy & Security → Full Disk Access** → click **`+`**.
2. Press **`Cmd+Shift+G`**, paste:
   ```
   ~/Library/Application Support/SMSFiller/sms_reader
   ```
   → **Enter** → select it → **Open** → toggle it **ON**.
3. **Note:** because the reader is Developer-ID signed (stable Team ID), this grant
   persists across updates — you won't need to redo it.

> Firefox, sqlite3, Python, and Xcode are **not** needed.

---

## Step 4 — Make verification codes arrive on this Mac

The add-on reads codes from **this Mac's Messages.app**, so your phone's SMS texts
must land here:

1. On the Mac, open **Messages.app** and sign in with the **same Apple ID** as your iPhone.
2. On your **iPhone**: **Settings → Messages → Text Message Forwarding** → enable **this Mac**.
3. Send yourself a test text, or request a code on a website — it should appear in
   this Mac's **Messages.app**.

> If your carrier/phone doesn't support SMS forwarding, this tool won't receive
> codes on the Mac (it only reads what's in Messages.app).

---

## Step 5 — Verify the reader is working

```bash
cat ~/Library/Application\ Support/SMSFiller/codes.json    # should list codes
tail ~/Library/Application\ Support/SMSFiller/reader.log   # should update, no "error:"
```

If `codes.json` has codes and `reader.log` is clean, you're ready.

---

## Step 6 — Test

1. **Restart Firefox** (Cmd+Q, then reopen).
2. Open a website's verification page, enter your phone, and request a **new** code.
3. The add-on **auto-fills** the code and **auto-submits**. You'll see a toast
   `✓ filled …`. If it can't detect the field, an **SMS** pill appears — click it
   and pick the code.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Add-on shows **"Native host unreachable"** | Re-run `bash install.sh` (from the folder with `install.sh` + `dist/`); fully quit & reopen Firefox. |
| Add-on shows **"No SMS codes found"** | The reader is fine; codes just aren't reaching this Mac — recheck Step 4 (SMS forwarding + Messages sign-in). |
| `reader.log` shows **"authorization denied"** | Full Disk Access not granted/applied to the reader — redo Step 3, then `launchctl kickstart gui/$(id -u)/com.ye.smsfiller.reader`. |
| **Gatekeeper/“could not verify”** | Shouldn't happen — binaries are Developer-ID signed + notarized. If it still appears, right-click the file → **Open** once. |

---

## Security / Privacy

- The tool reads your **own** SMS codes, **locally** — nothing is sent anywhere
  (no telemetry, no server).
- The binaries are signed by the developer (Developer ID, notarized by Apple) and
  the add-on is signed by Mozilla.
- **Full Disk Access** is a macOS privacy grant the reader needs to read Messages;
  it's not an install and you can revoke it at any time.
- Only grant Full Disk Access if you trust the source.
