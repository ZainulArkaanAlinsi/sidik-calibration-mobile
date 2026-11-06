# Isolated Studio HTTP/storage smoke (Windows)

This test uses a new synthetic SQLite database and real Laravel HTTP/auth/workbook
services. It opens the production Studio widget root with an in-memory device token,
test preferences, and a transport that rejects other hosts and redirects.

It covers login, two stored workbook sheets, a stored formula, required PNG captures,
and logout/token revocation. It does not run `main()`, Credential Manager, updater,
calibration calculations, reference activation, master parity, or physical Android.
The legacy forty-workbook integration test remains separate.

Prerequisites:

- Windows, Git, the existing Flutter/Visual Studio toolchain, and PHP 8.4.27.
- Clean committed API and mobile worktrees containing their synthetic harness files.
- API `vendor/` is a real directory in that checkout, not a junction or symlink.
- Cached dependencies match both lockfiles; resolution is offline and lock drift fails.
- The API harness currently restricts artifacts to `C:/Users/USER/sidik-e2e-sintetis`.
  The runner must execute under that matching profile; it never relaxes the PHP guard.

From this worktree's `studio` directory:

```powershell
.\tool\test_synthetic_e2e_guards.ps1
.\tool\run_synthetic_e2e.ps1 -ApiRepository C:\Users\USER\sidik-api-e2e-20261106 -PhpExecutable C:\laragon\bin\php\php-8.4.27-Win32-vs17-x64\php.exe -PreflightOnly
.\tool\run_synthetic_e2e.ps1 -ApiRepository C:\Users\USER\sidik-api-e2e-20261106 -PhpExecutable C:\laragon\bin\php\php-8.4.27-Win32-vs17-x64\php.exe
```

Each run creates a unique directory and rejects existing DB/manifest/env files.
The child PHP server binds only to `127.0.0.1`; marker identity must match the run,
both source SHAs, environment, driver, and manifest hash before login is attempted.
The runner stops only its own server PID and retains all artifacts on failure.

Do not publish the entire artifact directory: `defines.json` and `.env` contain
local synthetic credentials/key material, and native PHP stderr is not sanitized.
Use the sanitized `http-access.log`, verified PNGs, and redacted result metadata.
Never point this harness at an installed Studio session, existing database, production,
or the old emulator wrapper. A passing smoke is one bounded piece of evidence,
not proof that every Sidik workflow or device is ready.
