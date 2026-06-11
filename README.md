
# Brave Debloater macOS

**Remove Brave Browser bloat and telemetry on macOS using enforced managed policies.**


---

## What this does

Brave ships with features most users never use — crypto wallet, VPN, AI chat, telemetry, rewards, shopping, and more. This script disables them cleanly using macOS **managed enterprise policies**, which are:

- Applied at the machine level (`/Library/Managed Preferences`)
- Enforced by Brave — not user-overridable
- Visible and verifiable at `brave://policy`
- Reversible with a single command

---

## Quick start

```bash
git clone https://github.com/yourname/brave-debloat-macos
cd brave-debloat-macos
chmod +x debloater.sh

# For most users
./debloater.sh --apply

# For developers
./debloater.sh --dev
```

Then open Brave → `brave://policy` → **Reload policies** to verify.

---

## Features

- **Three presets** — Safe Debloat, Developer, and fully interactive Custom
- **Checklist UI** — see all settings per category with current ON/OFF status; toggle by number
- **True managed policies** — `machine / mandatory` scope, not user preferences
- **Automatic cleanup** — purges stale `defaults write` entries before applying
- **Reversible** — single command to remove everything and restore Brave defaults
- **Safe defaults** — does not disable Safe Browsing, password manager, DevTools, printing, or translate

---

## Installation

### Requirements

- macOS 12 or later
- Brave Browser in `/Applications/Brave Browser.app`
- `sudo` access

### Steps

```bash
git clone https://github.com/yourname/brave-debloat-macos
cd brave-debloat-macos
chmod +x debloater.sh
```

---

## Usage

### Interactive menu

```bash
./debloater.sh
```

```
  ╔══════════════════════════════════════════════════════╗
  ║       Brave Debloater  macOS                         ║
  ║  Remove bloat and telemetry via managed policies     ║
  ║  Verify results at  brave://policy                   ║
  ╚══════════════════════════════════════════════════════╝

   1   Safe Debloat          Remove Brave bloat and telemetry
        (Recommended for most users)

   2   Developer Preset      Safe Debloat + DevTools & Incognito pinned
        (Recommended for developers)

   3   Custom Configure      Choose exactly which policies to apply

   4   View Current Policies Show what is currently managed

   5   Reset to Defaults     Remove all managed policies

   6   Exit
```

### CLI flags

| Flag | Alias | Action |
|---|---|---|
| `--apply` | `-a` | Apply Safe Debloat preset |
| `--dev` | `-d` | Apply Developer preset |
| `--reset` | `-r` | Remove all managed policies |
| `--view` | `-v` | Print currently active policies |

---

## Presets

### Safe Debloat `--apply`

Removes Brave-specific bloat and telemetry. Does **not** touch password manager, DevTools, translate, spellcheck, printing, or incognito mode.

| Policy | Value | What it removes |
|---|---|---|
| `MetricsReportingEnabled` | `false` | Usage telemetry |
| `SafeBrowsingExtendedReportingEnabled` | `false` | Incident reports to Google |
| `UrlKeyedAnonymizedDataCollectionEnabled` | `false` | URL-keyed analytics |
| `FeedbackSurveysEnabled` | `false` | In-browser survey popups |
| `BraveRewardsDisabled` | `true` | BAT crypto rewards |
| `BraveWalletDisabled` | `true` | Crypto wallet UI |
| `BraveVPNDisabled` | `true` | Brave VPN upsell |
| `BraveAIChatEnabled` | `false` | Leo AI Chat sidebar |
| `ShoppingListEnabled` | `false` | Shopping price tracker |
| `PromotionsEnabled` | `false` | Promotional notifications |

> Safe Browsing itself stays **on**. Only extended incident reporting is disabled.

### Developer Preset `--dev`

Everything in Safe Debloat plus explicit developer-friendly policy pins:

| Policy | Value | Effect |
|---|---|---|
| `DeveloperToolsAvailability` | `1` | DevTools in all contexts, including extensions |
| `IncognitoModeAvailability` | `0` | Incognito / private windows explicitly permitted |

### Custom Configure

Interactive checklist UI. Each category (Telemetry, Privacy, Brave Features, Bloat, DNS) shows all its settings with current status. Type space-separated numbers to toggle multiple items at once. Toggling an active policy removes it; toggling an inactive one applies it.

---

## Verification

After running any preset:

1. Open Brave Browser
2. Go to `brave://policy`
3. Click **Reload policies**
4. All applied policies should show `scope: machine` · `level: mandatory`

If any policy shows `scope: user / level: recommended`, re-run the script — it will purge the stale user-layer entries automatically.

---

## Reset

```bash
./debloater.sh --reset
```

Deletes `/Library/Managed Preferences/com.brave.Browser.plist` and flushes the macOS preference cache. Brave returns to its own defaults. Requires confirmation.

---

## How it works

```
prepare_managed_plist()
  ├── mkdir -p /Library/Managed Preferences       (root:wheel 755)
  ├── touch com.brave.Browser.plist               (root:wheel 644)
  └── purge_user_layer()
        └── defaults delete com.brave.Browser <key>  ← removes stale user-layer entries

apply_setting(key, value, type)
  ├── PlistBuddy Delete :key    (idempotent, ignores errors)
  └── PlistBuddy Add :key type value

reload_policy_cache()
  └── sudo killall cfprefsd     ← forces macOS to re-read the managed plist
```

---

## Contributing

Pull requests welcome. When adding new policies:

1. Verify the key is valid in `brave://policy` after applying
2. Add it to `purge_user_layer()` so stale user-layer entries are cleaned up
3. Add it to `view_settings()` so it appears in `--view` output
4. Prefer conservative defaults — do not add policies that break normal browser workflows

