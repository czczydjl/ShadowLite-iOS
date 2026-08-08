# GitHub Build Steps

Use this when you do not have a Mac.

## 1. Upload the source

Upload the `ShadowLite-iOS` folder to a new GitHub repository. Make sure the hidden `.github` folder is included.

If using Git from this folder:

```bash
git init
git add .
git commit -m "Initial ShadowLite iOS build"
git branch -M main
git remote add origin <your-github-repo-url>
git push -u origin main
```

## 2. Run the cloud build

1. Open the repository on GitHub.
2. Go to `Actions`.
3. Select `Build ShadowLite IPA`.
4. Click `Run workflow`.
5. Wait for the job to finish.
6. Download the `ShadowLite-unsigned-ipa` artifact.

## 3. Install with the current Windows + jailbroken iPhone setup

From PowerShell:

```powershell
.\Scripts\install_ipa_via_usb.ps1 -IpaPath "C:\path\to\ShadowLite-unsigned.ipa"
```

The script copies the IPA to:

```text
/var/mobile/Documents/
```

Then it opens the IPA on the phone. If TrollStore does not pick it up automatically, open TrollStore manually and import the IPA from the Documents location.

## Current device notes

- Device is visible over USB.
- OpenSSH is running.
- `mobile` SSH key login works.
- Root password is not known, so system package installs still need manual Sileo confirmation.
