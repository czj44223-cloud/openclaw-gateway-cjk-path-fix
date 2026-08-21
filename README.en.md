# Fix: OpenClaw Gateway fails to start when installed under a non-ASCII (CJK) path on Windows

## Problem

When Node.js / OpenClaw is installed under a Chinese (or any non-ASCII) path like `E:\小龙虾\`:

1. OpenClaw writes `gateway.cmd` in **UTF-8**, embedding the CJK path.
2. Windows `cmd.exe` parses `.cmd` files with the system ANSI code page (**GBK** on Chinese systems).
3. The UTF-8 bytes are decoded as GBK → mojibake (`E:\灏忛緳铏綷node.exe`) → `node.exe` not found → the gateway silently fails to start.
4. The Scheduled Task still reports exit code 0, so the failure is invisible. Rebooting never recovers the gateway.
5. `openclaw gateway start` rewrites `gateway.cmd` every time (version-mismatch repair), undoing manual fixes — the bug keeps coming back.

## Fix

Remove CJK paths from the launch chain entirely:

```
Before: Scheduled Task → gateway.vbs → gateway.cmd (UTF-8 CJK path) → ✗ mojibake, node not found
After:  Scheduled Task → gateway.vbs (auto-repair first) → gateway.cmd (ASCII junction path) → ✓
```

1. **ASCII junction**: `mklink /J <user>\.openclaw\nodejs-link E:\小龙虾`
2. **gateway.cmd** uses the junction path (`...\nodejs-link\node.exe`) — safe under both UTF-8 and GBK parsing.
3. **Self-healing launcher** (`gateway.vbs` + `fix-gateway-cmd.ps1`): before launching, repair `gateway.cmd` if OpenClaw overwrote it with a CJK path again. The Scheduled Task always points at the ASCII `gateway.vbs`, which OpenClaw does not rewrite.

## Files

| File | Purpose |
|---|---|
| `fix-gateway-cmd.ps1` | Detects & replaces mangled node paths in `gateway.cmd` (handles UTF-8 CJK and GBK mojibake) |
| `gateway.vbs` | Protected launcher: repair first, then start (Scheduled Task entry point) |
| `gateway.cmd` | Fixed launcher template (ASCII junction path) |
| `install.ps1` | One-click: create junction + write scripts + register Scheduled Task |

## Usage

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```

Then open `http://127.0.0.1:18789`.

Verified: manual run, simulated overwrite → auto-repair, kill → task restart all pass (HTTP 200 / Health OK).

## License

MIT
