# Mi Phone Assistant English Patch

English translation patch for **Xiaomi Mi Phone Assistant 4.2.1028.10** (小米手机助手) — turns the Chinese-only UI into English.

This project replaces user-visible Chinese text in the extracted DuiLib XML resource files under `mi_phone_assistant.res`. It does not patch binaries, APKs, DLLs, or image assets.

## ⚠️ Disclaimer

**This is a test project made for study purposes only.**

- We do **not** guarantee how the Mi Phone Assistant app will behave after patching, or how it will interact with your phone. The patch only worked in testing on a single local machine.
- **Never use this with your daily/working phone.** Mi Phone Assistant is a flashing and backup tool — unexpected behavior may cause damage to the phone. Use a spare/test device only, at your own risk.
- Images were intentionally **not translated**: some Chinese text is baked into PNG artwork (e.g. phone mockup screenshots). Leaving images untouched gives better compatibility and avoids UI misalignment.
- This project is not affiliated with or endorsed by Xiaomi.

A backup of the original files is created automatically before any file is overwritten.

## Supported Version

- Mi Phone Assistant `4.2.1028.10`
- Expected executable: `MiPhoneAssistant.exe`
- Expected resource folder: `mi_phone_assistant.res`

The patcher refuses to run if `MiPhoneAssistant.exe` does not report `FileVersion` or `ProductVersion` as `4.2.1028.10`.

## What Is Translated

- Main toolbar labels
- Connection and Recovery/Fastboot screens
- Backup/restore/flash pages
- Settings, menus, warning dialogs, update dialogs, and file manager labels
- XML string table values in `values/strings.xml`

## Usage

Open PowerShell **as Administrator** and run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\MiPhoneAssistant-English-Patch.ps1
```

A simple menu opens:

```text
[1] Apply English patch (a backup is created first)
[2] Restore original files from a backup
[3] Show disclaimer again
[4] Exit
```

If Mi Phone Assistant is installed somewhere other than the default `C:\Program Files (x86)\MiPhoneAssistant`, you will be asked for the folder — or pass it up front:

```powershell
.\MiPhoneAssistant-English-Patch.ps1 -InstallDir "D:\Apps\MiPhoneAssistant"
```

### Applying the patch

The script will:

1. Show the disclaimer and require `y`/`n` acceptance.
2. Ask for the Mi Phone Assistant installation folder if not supplied.
3. Verify the folder contains Mi Phone Assistant `4.2.1028.10`.
4. Verify Administrator privileges.
5. Refuse to continue if Mi Phone Assistant is running.
6. Back up the original XML files.
7. Copy the translated XML overlay into `mi_phone_assistant.res`.

### Backups and restore

Each patch run creates a timestamped backup **in a `Backups` folder next to the script**:

```text
<script folder>\Backups\MiPhoneAssistant_4.2.1028.10_YYYYMMDD_HHMMSS\
```

To restore, run the script again and choose option `[2]` — it lists every backup it finds (newest first) and copies the selected one back into the installed `mi_phone_assistant.res` folder.

You can also restore manually by copying the backed-up `mi_phone_assistant.res` XML files back into the installation folder as Administrator.

## Repository Layout

```text
MiPhoneAssistant-English-Patch.ps1
resources/
  mi_phone_assistant.res/
    *.xml
    values/strings.xml
```

Only XML resource files are included in this repo.
