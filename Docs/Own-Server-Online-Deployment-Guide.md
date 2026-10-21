# Own Server Online Deployment Guide

This guide explains how to run Famalth Lynx on your own online server and connect client PCs over network/internet.

## 1. Prerequisites

- A server machine (Windows or Linux) with stable internet.
- Node.js 18+ installed.
- PostgreSQL installed and reachable from backend.
- Required runtime files in backend run folder:
  - `license.key`
  - `config.enc`
  - `sysConfig.enc`
  - `client.json`
  - `uploads/` (folder)
- Port `3000` open on server firewall (or a reverse-proxy port like `80/443`).

## 2. Backend Deployment

From project root:

```bash
cd backend
npm install
npm start
```

Default server port is `3000` (`backend/server.js` uses `process.env.PORT || 3000`).

Health check:

```text
http://<SERVER-IP-OR-DOMAIN>:3000/health
```

Expected when healthy: JSON with `success: true`.

## 3. Optional: Run as Background Service

Use a process manager so backend auto-restarts after reboot/crash.

- Linux: `pm2`, `systemd`.
- Windows: NSSM / Task Scheduler / service wrapper.

Keep working directory pointed to backend runtime folder so config and license files are found.

## 4. Optional: Domain + HTTPS (Recommended)

Put Nginx/Apache in front of Node app:

- Public URL: `https://api.yourdomain.com`
- Proxy target: `http://127.0.0.1:3000`
- Enable SSL certificate (Let’s Encrypt or purchased cert).

Then clients will use HTTPS base URL in `server_config.json`.

## 5. Client Connection Setup

On every client machine, set `server_config.json` in app working directory:

```json
{
  "baseUrl": "http://<SERVER-IP-OR-DOMAIN>:3000",
  "outlets": []
}
```

Examples:

- LAN: `http://192.168.1.50:3000`
- Public: `https://api.yourdomain.com`

## 6. Behavior on Server vs Client PCs

The app now validates host mode from `baseUrl`:

- `localhost` / `127.0.0.1` (host mode):
  - Shows cloud backup controls.
  - Shows backup protection popups.
  - Link flow supports full `Verify + Recover System`.
- Any non-localhost URL (network/client mode):
  - Hides cloud backup controls and backup popups.
  - Link flow works as `Verify + Link Device` (PIN/OTP verification and linking).

## 7. Device Link Flow (Client PCs)

1. Open setup screen.
2. Choose `Link Existing`.
3. Enter Business ID + PIN, or choose OTP fallback.
4. Verify identity.
5. Device gets linked to server business profile.

## 8. Troubleshooting

- `Cannot connect to server`:
  - Confirm backend is running.
  - Check firewall port allow rule.
  - Verify `server_config.json` URL/port.
  - Test `/health` URL directly from client browser.
- `Health returns config/license errors`:
  - Re-check `license.key`, `config.enc`, `sysConfig.enc`.
- `Database connection failed`:
  - Verify DB host/user/password/port in encrypted config.
  - Confirm PostgreSQL service is running.

## 9. Security Checklist

- Prefer HTTPS for internet deployments.
- Restrict DB access to backend host only.
- Keep server OS patched.
- Keep license/config files readable only by service account.
- Back up database and `uploads/` regularly.

