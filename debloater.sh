#!/bin/bash

# Brave Debloater macOS - Interactive Policy Manager
# Applies privacy and debloating policies to Brave Browser
# via the macOS managed policy layer (/Library/Managed Preferences).

PLIST="/Library/Managed Preferences/com.brave.Browser.plist"

# Color codes for terminal output using tput
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
BOLD=$(tput bold)
NC=$(tput sgr0)

# Temporary file to store user selections
SELECTION_FILE="/tmp/brave_debloater_selections.tmp"

# Header
show_header() {
    clear
    echo "${BOLD}${BLUE}"
    echo "  ╔══════════════════════════════════════════════════════╗"
    echo "  ║       Brave Debloater  macOS                         ║"
    echo "  ║  Remove bloat and telemetry via managed policies     ║"
    echo "  ║  Verify results at  brave://policy                   ║"
    echo "  ╚══════════════════════════════════════════════════════╝"
    echo "${NC}"
}

# Check if Brave is installed
check_brave() {
    if [ ! -d "/Applications/Brave Browser.app" ]; then
        echo "${RED}Error: Brave Browser not found in /Applications/${NC}"
        echo "${YELLOW}Please install Brave Browser first.${NC}"
        exit 1
    fi
}

# Check if Brave is running
check_brave_running() {
    if pgrep -x "Brave Browser" > /dev/null; then
        echo "${YELLOW}⚠️  Brave Browser is currently running.${NC}"
        echo "${YELLOW}For best results, please close Brave before continuing.${NC}"
        echo ""
        read -p "Do you want to continue anyway? (y/n): " continue_choice
        if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
            echo "${BLUE}Exiting. Please close Brave and run the script again.${NC}"
            exit 0
        fi
        echo ""
    fi
}

# Bootstrap /Library/Managed Preferences and the managed plist
prepare_managed_plist() {
    sudo mkdir -p "/Library/Managed Preferences"
    sudo chown root:wheel "/Library/Managed Preferences"
    sudo chmod 755 "/Library/Managed Preferences"

    if [ ! -s "$PLIST" ]; then
        echo '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict/></plist>' | sudo tee "$PLIST" >/dev/null
        sudo chown root:wheel "$PLIST"
        sudo chmod 644 "$PLIST"
    fi

    # Remove any keys written by old script runs into the user-layer
    # defaults domain. Leaving them there causes brave://policy to show
    # scope=user / level=recommended, which can be overridden by the user.
    purge_user_layer
}

# Delete every managed key from the user-layer defaults domain so that only
# the machine-scoped managed plist entries remain.
purge_user_layer() {
    local keys=(
        "MetricsReportingEnabled"
        "SafeBrowsingExtendedReportingEnabled"
        "SafeBrowsingProtectionLevel"
        "UrlKeyedAnonymizedDataCollectionEnabled"
        "FeedbackSurveysEnabled"
        "BraveRewardsDisabled"
        "BraveWalletDisabled"
        "BraveVPNDisabled"
        "BraveAIChatEnabled"
        "TorDisabled"
        "SyncDisabled"
        "ShoppingListEnabled"
        "PromotionsEnabled"
        "AlwaysOpenPdfExternally"
        "TranslateEnabled"
        "SpellcheckEnabled"
        "SearchSuggestEnabled"
        "PrintingEnabled"
        "DefaultBrowserSettingEnabled"
        "DeveloperToolsDisabled"
        "DeveloperToolsAvailability"
        "IncognitoModeAvailability"
        "BackgroundModeEnabled"
        "MediaRecommendationsEnabled"
        "AutofillAddressEnabled"
        "AutofillCreditCardEnabled"
        "PasswordManagerEnabled"
        "BrowserSignin"
        "WebRtcIPHandling"
        "QuicAllowed"
        "BlockThirdPartyCookies"
        "EnableDoNotTrack"
        "ForceGoogleSafeSearch"
        "IPFSEnabled"
        "DnsOverHttpsMode"
    )
    for key in "${keys[@]}"; do
        defaults delete "com.brave.Browser" "$key" 2>/dev/null || true
    done
}

# Flush the macOS preference cache so Brave picks up changes immediately
reload_policy_cache() {
    sudo killall cfprefsd 2>/dev/null || true
}

# Write a key into the managed policy plist using PlistBuddy
apply_setting() {
    local key="$1"
    local value="$2"
    local type="$3"

    # Delete first to allow clean re-add (idempotent)
    sudo /usr/libexec/PlistBuddy -c "Delete :${key}" "$PLIST" 2>/dev/null || true

    case "$type" in
        "bool")
            sudo /usr/libexec/PlistBuddy -c "Add :${key} bool ${value}" "$PLIST"
            ;;
        "integer")
            sudo /usr/libexec/PlistBuddy -c "Add :${key} integer ${value}" "$PLIST"
            ;;
        "string")
            sudo /usr/libexec/PlistBuddy -c "Add :${key} string ${value}" "$PLIST"
            ;;
        *)
            echo "${RED}Unsupported setting type: $type${NC}" >&2
            exit 1
            ;;
    esac
}

# Read a key from the managed policy plist
is_setting_enabled() {
    local key="$1"
    local value
    value=$(sudo /usr/libexec/PlistBuddy -c "Print :${key}" "$PLIST" 2>/dev/null)

    if [ $? -eq 0 ]; then
        # Normalise PlistBuddy bool output ("true"/"false") — already correct
        echo "$value"
    else
        echo "not_set"
    fi
}

# Conservative safe-debloat — removes Brave bloat and telemetry without
# touching password manager, DevTools, translate, spellcheck, or printing.
apply_quick_preset() {
    echo "${CYAN}Applying SlimBrave Default Preset (conservative)...${NC}"
    echo ""
    echo "${BLUE}[Telemetry & Privacy]${NC}"

    apply_setting "MetricsReportingEnabled" "false" "bool"
    echo "${GREEN}✓${NC} Disabled Metrics Reporting"

    apply_setting "SafeBrowsingExtendedReportingEnabled" "false" "bool"
    echo "${GREEN}✓${NC} Disabled Safe Browsing Extended Reporting"

    apply_setting "UrlKeyedAnonymizedDataCollectionEnabled" "false" "bool"
    echo "${GREEN}✓${NC} Disabled URL Data Collection"

    apply_setting "FeedbackSurveysEnabled" "false" "bool"
    echo "${GREEN}✓${NC} Disabled Feedback Surveys"

    echo ""
    echo "${BLUE}[Brave Features]${NC}"

    apply_setting "BraveRewardsDisabled" "true" "bool"
    echo "${GREEN}✓${NC} Disabled Brave Rewards"

    apply_setting "BraveWalletDisabled" "true" "bool"
    echo "${GREEN}✓${NC} Disabled Brave Wallet"

    apply_setting "BraveVPNDisabled" "true" "bool"
    echo "${GREEN}✓${NC} Disabled Brave VPN"

    apply_setting "BraveAIChatEnabled" "false" "bool"
    echo "${GREEN}✓${NC} Disabled Brave AI Chat"

    echo ""
    echo "${BLUE}[Bloat Removal]${NC}"

    apply_setting "ShoppingListEnabled" "false" "bool"
    echo "${GREEN}✓${NC} Disabled Shopping List"

    apply_setting "PromotionsEnabled" "false" "bool"
    echo "${GREEN}✓${NC} Disabled Promotions"

    echo ""
    echo "${GREEN}═══════════════════════════════════════════${NC}"
    echo "${GREEN}✓ SlimBrave Default applied successfully!${NC}"
    echo "${GREEN}═══════════════════════════════════════════${NC}"
    echo ""
    reload_policy_cache
    echo "${YELLOW}⚠️  Restart Brave, then check brave://policy and click Reload policies.${NC}"
    echo "${CYAN}💡 Tip: Use option [5] (Export Profile) to make settings survive Mac reboots.${NC}"
    open -a "Brave Browser" "brave://policy" 2>/dev/null || true
}

# Developer preset — conservative default plus explicit DevTools and Incognito
# availability policies. Does not disable Tor, translate, spellcheck, or printing.
apply_dev_preset() {
    echo "${CYAN}Applying Developer Preset...${NC}"
    echo ""
    echo "${BLUE}[Telemetry & Privacy]${NC}"

    apply_setting "MetricsReportingEnabled" "false" "bool"
    echo "${GREEN}✓${NC} Disabled Metrics Reporting"

    apply_setting "SafeBrowsingExtendedReportingEnabled" "false" "bool"
    echo "${GREEN}✓${NC} Disabled Safe Browsing Extended Reporting"

    apply_setting "UrlKeyedAnonymizedDataCollectionEnabled" "false" "bool"
    echo "${GREEN}✓${NC} Disabled URL Data Collection"

    apply_setting "FeedbackSurveysEnabled" "false" "bool"
    echo "${GREEN}✓${NC} Disabled Feedback Surveys"

    echo ""
    echo "${BLUE}[Brave Features]${NC}"

    apply_setting "BraveRewardsDisabled" "true" "bool"
    echo "${GREEN}✓${NC} Disabled Brave Rewards"

    apply_setting "BraveWalletDisabled" "true" "bool"
    echo "${GREEN}✓${NC} Disabled Brave Wallet"

    apply_setting "BraveVPNDisabled" "true" "bool"
    echo "${GREEN}✓${NC} Disabled Brave VPN"

    # Enforce Leo AI Chat disabled at machine scope (user/recommended level
    # is insufficient — the sidebar feature remains active)
    apply_setting "BraveAIChatEnabled" "false" "bool"
    echo "${GREEN}✓${NC} Disabled Brave AI Chat (Leo) — machine/mandatory"

    echo ""
    echo "${BLUE}[Bloat Removal]${NC}"

    apply_setting "ShoppingListEnabled" "false" "bool"
    echo "${GREEN}✓${NC} Disabled Shopping List"

    apply_setting "PromotionsEnabled" "false" "bool"
    echo "${GREEN}✓${NC} Disabled Promotions"

    echo ""
    echo "${BLUE}[Developer Tools]${NC}"

    # 1 = allow DevTools in all contexts including extension pages
    apply_setting "DeveloperToolsAvailability" "1" "integer"
    echo "${GREEN}✓${NC} DevTools available in all contexts (DeveloperToolsAvailability=1)"

    # 0 = incognito/private window allowed (default behaviour made explicit)
    apply_setting "IncognitoModeAvailability" "0" "integer"
    echo "${GREEN}✓${NC} Incognito mode available (IncognitoModeAvailability=0)"

    echo ""
    echo "${GREEN}═══════════════════════════════════════════${NC}"
    echo "${GREEN}✓ Developer Preset applied successfully!${NC}"
    echo "${GREEN}═══════════════════════════════════════════${NC}"
    echo ""
    reload_policy_cache
    echo "${YELLOW}⚠️  Restart Brave, then check brave://policy and click Reload policies.${NC}"
    echo "${CYAN}💡 Tip: Use option [5] (Export Profile) to make settings survive Mac reboots.${NC}"
    open -a "Brave Browser" "brave://policy" 2>/dev/null || true
}

# Interactive customization menu
interactive_customize() {
    > "$SELECTION_FILE"

    local categories=(
        "Telemetry & Privacy"
        "Privacy & Security"
        "Brave Features"
        "Performance & Bloat"
        "DNS Settings"
    )

    for category in "${categories[@]}"; do
        customize_category "$category"
    done

    apply_custom_selections
}

# Checklist-based category display.
# Each item is a pipe-delimited string: "key|Name|target|type|on_label|off_label|risk_note"
#   on_label  — shown when the policy is active (desired state applied)
#   off_label — shown when no policy is set (Brave default)
show_checklist() {
    local _cat="$1"
    shift
    local _items=("$@")
    local _count=${#_items[@]}

    clear
    show_header
    echo "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "${MAGENTA}  $_cat${NC}"
    echo "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  Type numbers to toggle (e.g. ${BOLD}1 3 4${NC}), or Enter to skip all."
    echo "  Toggling a setting that is already ON turns it OFF, and vice versa."
    echo ""
    printf "  ${BOLD}%-5s %-38s %s${NC}\n" "No." "Setting" "Status"
    echo "  ───────────────────────────────────────────────────────────────"

    local _i
    for ((_i = 0; _i < _count; _i++)); do
        local _key _name _target _type _on _off _risk
        IFS='|' read -r _key _name _target _type _on _off _risk <<< "${_items[$_i]}"

        local _cur _state
        _cur=$(is_setting_enabled "$_key")

        if [ "$_cur" = "$_target" ]; then
            _state="${GREEN}${_on}${NC}"
        elif [ "$_cur" = "not_set" ]; then
            _state="${YELLOW}${_off}${NC}"
        else
            _state="${RED}Value: $_cur${NC}"
        fi

        printf "  [%2d] %-38s " "$((_i + 1))" "$_name"
        echo -e "$_state"

        if [ -n "$_risk" ]; then
            printf "        ${YELLOW}⚠  %s${NC}\n" "$_risk"
        fi
    done

    echo "  ───────────────────────────────────────────────────────────────"
    echo ""
    local _sel
    read -p "  Numbers to toggle [Enter = skip]: " _sel
    echo ""

    for _s in $_sel; do
        if [[ "$_s" =~ ^[0-9]+$ ]] && [ "$_s" -ge 1 ] && [ "$_s" -le "$_count" ]; then
            local _idx=$((_s - 1))
            local _k _n _t _tp _al _dl _r
            IFS='|' read -r _k _n _t _tp _al _dl _r <<< "${_items[$_idx]}"

            local _cur
            _cur=$(is_setting_enabled "$_k")

            if [ "$_cur" = "$_t" ]; then
                echo "$_k|__DELETE__|$_tp" >> "$SELECTION_FILE"
                echo "  ${RED}−${NC} [$_s] $_n  →  policy removed (Brave default restored)"
            else
                echo "$_k|$_t|$_tp" >> "$SELECTION_FILE"
                echo "  ${GREEN}+${NC} [$_s] $_n  →  policy applied"
            fi
        else
            echo "  ${YELLOW}⚠  '$_s' is not valid — skipped${NC}"
        fi
    done
}

# Customize specific category — uses show_checklist for all except DNS
customize_category() {
    local category="$1"

    case "$category" in
        "Telemetry & Privacy")
            show_checklist "Telemetry & Privacy" \
                "MetricsReportingEnabled|Metrics Reporting|false|bool|OFF  ✓ (telemetry disabled)|ON   (sending data — Brave default)|" \
                "SafeBrowsingExtendedReportingEnabled|Safe Browsing Extended Reporting|false|bool|OFF  ✓ (not reporting to Google)|ON   (reporting incidents — Brave default)|" \
                "UrlKeyedAnonymizedDataCollectionEnabled|URL Data Collection|false|bool|OFF  ✓ (URLs not sent)|ON   (URLs sent for analysis — Brave default)|" \
                "FeedbackSurveysEnabled|Feedback Surveys|false|bool|OFF  ✓ (no survey popups)|ON   (surveys may appear — Brave default)|"
            ;;

        "Privacy & Security")
            show_checklist "Privacy & Security" \
                "SafeBrowsingProtectionLevel|Safe Browsing|0|integer|OFF  ✓ (disabled — ⚠ no protection)|ON   (active — Brave default, recommended)|Disabling removes phishing and malware protection." \
                "AutofillAddressEnabled|Autofill — Addresses|false|bool|OFF  ✓ (address fill disabled)|ON   (Brave default)|" \
                "AutofillCreditCardEnabled|Autofill — Credit Cards|false|bool|OFF  ✓ (card fill disabled)|ON   (Brave default)|" \
                "PasswordManagerEnabled|Password Manager|false|bool|OFF  ✓ (built-in passwords disabled)|ON   (Brave default)|Only turn off if you use 1Password or Bitwarden." \
                "BrowserSignin|Browser Sign-in|0|integer|OFF  ✓ (cannot sign into Brave account)|ON   (Brave default)|" \
                "WebRtcIPHandling|WebRTC IP Leak Protection|disable_non_proxied_udp|string|ON   ✓ (local IP hidden)|OFF  (Brave default)|May break Google Meet, Discord, video calls." \
                "QuicAllowed|QUIC Protocol|false|bool|OFF  ✓ (QUIC disabled)|ON   (Brave default)|" \
                "BlockThirdPartyCookies|Third-Party Cookies|true|bool|BLOCKED ✓|Allowed (Brave default)|May break login flows and SSO portals." \
                "EnableDoNotTrack|Do Not Track header|true|bool|ON   ✓ (DNT signal sent)|OFF  (Brave default)|" \
                "ForceGoogleSafeSearch|Google SafeSearch|true|bool|FORCED ✓|Not forced (Brave default)|" \
                "IPFSEnabled|IPFS Protocol|false|bool|OFF  ✓ (IPFS disabled)|ON   (Brave default)|" \
                "IncognitoModeAvailability|Incognito / Private Window|1|integer|DISABLED ✓ (no private windows)|Allowed (Brave default)|Removes private browsing entirely."
            ;;

        "Brave Features")
            show_checklist "Brave Features" \
                "BraveRewardsDisabled|Brave Rewards (BAT)|true|bool|OFF  ✓ (Rewards removed)|ON   (Brave default)|" \
                "BraveWalletDisabled|Brave Wallet (crypto)|true|bool|OFF  ✓ (Wallet removed)|ON   (Brave default)|" \
                "BraveVPNDisabled|Brave VPN|true|bool|OFF  ✓ (VPN removed)|ON   (Brave default)|" \
                "BraveAIChatEnabled|Brave AI Chat — Leo|false|bool|OFF  ✓ (Leo disabled)|ON   (Brave default)|" \
                "TorDisabled|Tor Private Window|true|bool|OFF  ✓ (Tor disabled)|ON   (Brave default)|" \
                "SyncDisabled|Brave Sync|true|bool|OFF  ✓ (Sync disabled)|ON   (Brave default)|"
            ;;

        "Performance & Bloat")
            show_checklist "Performance & Bloat" \
                "BackgroundModeEnabled|Background Mode|false|bool|OFF  ✓ (no background activity)|ON   (Brave default)|" \
                "MediaRecommendationsEnabled|Media Recommendations|false|bool|OFF  ✓ (no recommendations)|ON   (Brave default)|" \
                "ShoppingListEnabled|Shopping List|false|bool|OFF  ✓ (shopping UI off)|ON   (Brave default)|" \
                "AlwaysOpenPdfExternally|PDF Viewer|true|bool|External app ✓|Brave built-in (default)|" \
                "TranslateEnabled|Translate|false|bool|OFF  ✓ (no translate prompt)|ON   (Brave default)|" \
                "SpellcheckEnabled|Spellcheck|false|bool|OFF  ✓ (spellcheck off)|ON   (Brave default)|" \
                "PromotionsEnabled|Promotions|false|bool|OFF  ✓ (no promo notifications)|ON   (Brave default)|" \
                "SearchSuggestEnabled|Search Suggestions|false|bool|OFF  ✓ (no suggestions sent)|ON   (Brave default)|" \
                "PrintingEnabled|Printing (Cmd+P)|false|bool|OFF  ✓ (printing disabled)|ON   (Brave default)|Removes all print functionality." \
                "DefaultBrowserSettingEnabled|Default Browser Prompt|false|bool|OFF  ✓ (no nag prompts)|ON   (Brave default)|" \
                "DeveloperToolsAvailability|Developer Tools|1|integer|ON   ✓ (all contexts incl. extensions)|Standard (Brave default)|"
            ;;

        "DNS Settings")
            clear
            show_header
            echo "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo "${MAGENTA}  DNS Settings${NC}"
            echo "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
            select_dns_mode
            ;;
    esac

    echo ""
    read -p "Press Enter to continue to next category..."
}

select_dns_mode() {
    local current=$(is_setting_enabled "DnsOverHttpsMode")
    
    echo "Current DNS Mode: ${CYAN}$current${NC}"
    echo ""
    echo "Select DNS Over HTTPS Mode:"
    echo "  1. automatic (recommended)"
    echo "  2. off"
    echo "  3. custom"
    echo "  4. Skip (no change)"
    echo ""
    read -p "Select option (1-4): " dns_choice
    
    case $dns_choice in
        1)
            echo "DnsOverHttpsMode|automatic|string" >> "$SELECTION_FILE"
            echo "${CYAN}→ Will set to 'automatic'${NC}"
            ;;
        2)
            echo "DnsOverHttpsMode|off|string" >> "$SELECTION_FILE"
            echo "${CYAN}→ Will set to 'off'${NC}"
            ;;
        3)
            echo "DnsOverHttpsMode|custom|string" >> "$SELECTION_FILE"
            echo "${CYAN}→ Will set to 'custom'${NC}"
            ;;
        4)
            echo "${YELLOW}Skipping DNS setting${NC}"
            ;;
    esac
}

apply_custom_selections() {
    clear
    show_header
    echo "${CYAN}Applying your custom selections...${NC}"
    echo ""

    if [ ! -s "$SELECTION_FILE" ]; then
        echo "${YELLOW}No changes selected.${NC}"
        rm -f "$SELECTION_FILE"
        return
    fi

    while IFS='|' read -r key value type; do
        if [ "$value" = "__DELETE__" ]; then
            sudo /usr/libexec/PlistBuddy -c "Delete :${key}" "$PLIST" 2>/dev/null || true
            echo "${RED}✕${NC} Removed policy: $key (restored to Brave default)"
        else
            apply_setting "$key" "$value" "$type"
            echo "${GREEN}✓${NC} Applied: $key = $value"
        fi
    done < "$SELECTION_FILE"

    rm -f "$SELECTION_FILE"

    echo ""
    echo "${GREEN}═══════════════════════════════════════════${NC}"
    echo "${GREEN}✓ Custom settings applied successfully!${NC}"
    echo "${GREEN}═══════════════════════════════════════════${NC}"
    echo ""
    reload_policy_cache
    echo "${YELLOW}⚠️  Restart Brave, then check brave://policy and click Reload policies.${NC}"
    echo "${CYAN}💡 Tip: Use option [5] (Export Profile) to make settings survive Mac reboots.${NC}"
    open -a "Brave Browser" "brave://policy" 2>/dev/null || true
}

# Export the current policies to a .mobileconfig file for persistence
export_mobileconfig() {
    echo ""
    echo "${CYAN}Generating Persistent Configuration Profile...${NC}"

    if [ ! -s "$PLIST" ]; then
        echo "${YELLOW}No policies currently applied. Apply a preset or custom config first.${NC}"
        return
    fi

    local profile_path="$HOME/Desktop/Brave_Debloater.mobileconfig"

    # Create base mobileconfig structure
    echo '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict/></plist>' > "$profile_path"

    /usr/libexec/PlistBuddy -c "Add :PayloadDisplayName string 'Brave Debloater Policies'" "$profile_path"
    /usr/libexec/PlistBuddy -c "Add :PayloadIdentifier string 'com.github.brave-debloat-macos'" "$profile_path"
    /usr/libexec/PlistBuddy -c "Add :PayloadType string 'Configuration'" "$profile_path"
    /usr/libexec/PlistBuddy -c "Add :PayloadUUID string '$(uuidgen)'" "$profile_path"
    /usr/libexec/PlistBuddy -c "Add :PayloadVersion integer 1" "$profile_path"
    /usr/libexec/PlistBuddy -c "Add :PayloadContent array" "$profile_path"
    
    /usr/libexec/PlistBuddy -c "Add :PayloadContent:0 dict" "$profile_path"
    /usr/libexec/PlistBuddy -c "Add :PayloadContent:0:PayloadType string 'com.brave.Browser'" "$profile_path"
    /usr/libexec/PlistBuddy -c "Add :PayloadContent:0:PayloadVersion integer 1" "$profile_path"
    /usr/libexec/PlistBuddy -c "Add :PayloadContent:0:PayloadIdentifier string 'com.brave.Browser.policy'" "$profile_path"
    /usr/libexec/PlistBuddy -c "Add :PayloadContent:0:PayloadUUID string '$(uuidgen)'" "$profile_path"
    /usr/libexec/PlistBuddy -c "Add :PayloadContent:0:PayloadDisplayName string 'Brave Policies'" "$profile_path"

    # Merge the active policies into the profile payload
    /usr/libexec/PlistBuddy -c "Merge '$PLIST' :PayloadContent:0" "$profile_path" 2>/dev/null

    echo "${GREEN}✓ Profile exported to Desktop: ${BOLD}Brave_Debloater.mobileconfig${NC}"
    echo ""
    echo "${YELLOW}⚠️  IMPORTANT: To make policies survive reboots, you must install the profile!${NC}"
    echo "1. Double-click the file on your Desktop"
    echo "2. Open System Settings → Privacy & Security → Profiles"
    echo "3. Double-click 'Brave Debloater Policies' and click Install"
    echo ""
    
    # Auto-open the profile to trigger the system prompt
    open "$profile_path" 2>/dev/null || true
}

# Function to reset all settings
reset_settings() {
    echo ""
    echo "${RED}═══════════════════════════════════════════${NC}"
    echo "${RED}    WARNING: RESET ALL SETTINGS${NC}"
    echo "${RED}═══════════════════════════════════════════${NC}"
    echo ""
    echo "This will remove the managed policy plist and restore"
    echo "Brave to its default configuration."
    echo ""
    read -p "Are you absolutely sure? Type 'yes' to confirm: " confirm

    if [ "$confirm" = "yes" ]; then
        sudo rm -f "$PLIST"
        reload_policy_cache
        echo ""
        echo "${GREEN}✓ Managed policy plist removed. Brave restored to defaults.${NC}"
        echo "${YELLOW}⚠️  Please restart Brave Browser.${NC}"
    else
        echo ""
        echo "${BLUE}Reset cancelled.${NC}"
    fi
}

# Function to view current settings
view_settings() {
    echo ""
    echo "${CYAN}Current Brave Managed Policy Settings:${NC}"
    echo "${CYAN}(source: $PLIST)${NC}"
    echo "${CYAN}══════════════════════════════${NC}"
    echo ""

    if [ ! -f "$PLIST" ]; then
        echo "${YELLOW}No managed policy plist found — Brave is using defaults.${NC}"
        echo ""
        return
    fi

    local settings=(
        "MetricsReportingEnabled"
        "SafeBrowsingExtendedReportingEnabled"
        "UrlKeyedAnonymizedDataCollectionEnabled"
        "FeedbackSurveysEnabled"
        "SafeBrowsingProtectionLevel"
        "AutofillAddressEnabled"
        "AutofillCreditCardEnabled"
        "PasswordManagerEnabled"
        "BrowserSignin"
        "WebRtcIPHandling"
        "QuicAllowed"
        "BlockThirdPartyCookies"
        "EnableDoNotTrack"
        "ForceGoogleSafeSearch"
        "IPFSEnabled"
        "IncognitoModeAvailability"
        "BraveRewardsDisabled"
        "BraveWalletDisabled"
        "BraveVPNDisabled"
        "BraveAIChatEnabled"
        "TorDisabled"
        "SyncDisabled"
        "BackgroundModeEnabled"
        "MediaRecommendationsEnabled"
        "ShoppingListEnabled"
        "AlwaysOpenPdfExternally"
        "TranslateEnabled"
        "SpellcheckEnabled"
        "PromotionsEnabled"
        "SearchSuggestEnabled"
        "PrintingEnabled"
        "DefaultBrowserSettingEnabled"
        "DeveloperToolsAvailability"
        "DnsOverHttpsMode"
    )

    for setting in "${settings[@]}"; do
        local value
        value=$(sudo /usr/libexec/PlistBuddy -c "Print :${setting}" "$PLIST" 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo "${GREEN}✓${NC} $setting = $value"
        else
            echo "${YELLOW}○${NC} $setting = (not set)"
        fi
    done

    echo ""
}

# Main menu
show_menu() {
    show_header
    echo "  ${BOLD}What would you like to do?${NC}"
    echo ""
    echo "  ${BOLD}${GREEN} 1 ${NC}  Safe Debloat          Remove Brave bloat and telemetry"
    echo "        ${CYAN}(Recommended for most users)${NC}"
    echo ""
    echo "  ${BOLD}${MAGENTA} 2 ${NC}  Developer Preset      Safe Debloat + DevTools & Incognito pinned"
    echo "        ${CYAN}(Recommended for developers)${NC}"
    echo ""
    echo "  ${BOLD}${BLUE} 3 ${NC}  Custom Configure      Choose exactly which policies to apply"
    echo ""
    echo "  ${BOLD}${YELLOW} 4 ${NC}  View Current Policies Show what is currently managed"
    echo ""
    echo "  ${BOLD}${CYAN} 5 ${NC}  Export Profile        Make policies survive reboots (.mobileconfig)"
    echo ""
    echo "  ${BOLD}${RED} 6 ${NC}  Reset to Defaults     Remove all managed policies"
    echo ""
    echo "  ${BOLD} 7 ${NC}  Exit"
    echo ""
    echo "  ${BOLD}─────────────────────────────────────────────────────────${NC}"
    echo "  CLI flags:  --apply  --dev  --profile  --reset  --view"
    echo "  Validate:   brave://policy  →  Reload policies"
    echo "  ${BOLD}─────────────────────────────────────────────────────────${NC}"
    echo ""
    read -p "  Select (1-7): " choice

    case $choice in
        1)
            echo ""
            prepare_managed_plist
            apply_quick_preset
            echo ""
            read -p "  Press Enter to continue..."
            show_menu
            ;;
        2)
            echo ""
            prepare_managed_plist
            apply_dev_preset
            echo ""
            read -p "  Press Enter to continue..."
            show_menu
            ;;
        3)
            prepare_managed_plist
            interactive_customize
            echo ""
            read -p "  Press Enter to continue..."
            show_menu
            ;;
        4)
            view_settings
            read -p "  Press Enter to continue..."
            show_menu
            ;;
        5)
            export_mobileconfig
            read -p "  Press Enter to continue..."
            show_menu
            ;;
        6)
            reset_settings
            echo ""
            read -p "  Press Enter to continue..."
            show_menu
            ;;
        7)
            echo ""
            echo "  ${GREEN}${BOLD}Done.${NC} Verify your policies at ${CYAN}brave://policy${NC}"
            echo ""
            exit 0
            ;;
        *)
            echo "  ${RED}Invalid option. Select 1-7.${NC}"
            sleep 1
            show_menu
            ;;
    esac
}

# Non-interactive mode: --apply applies the Safe Debloat preset
if [ "$1" = "--apply" ] || [ "$1" = "-a" ]; then
    show_header
    check_brave
    check_brave_running
    prepare_managed_plist
    apply_quick_preset
    echo ""
    exit 0
fi

# Developer preset mode (with --dev flag)
if [ "$1" = "--dev" ] || [ "$1" = "-d" ]; then
    show_header
    check_brave
    check_brave_running
    prepare_managed_plist
    apply_dev_preset
    echo ""
    exit 0
fi

# Quick reset mode (with --reset flag)
if [ "$1" = "--reset" ] || [ "$1" = "-r" ]; then
    show_header
    check_brave
    reset_settings
    echo ""
    exit 0
fi

# Quick view mode (with --view flag)
if [ "$1" = "--view" ] || [ "$1" = "-v" ]; then
    show_header
    check_brave
    view_settings
    exit 0
fi

# Export profile mode (with --profile flag)
if [ "$1" = "--profile" ] || [ "$1" = "-p" ]; then
    show_header
    check_brave
    export_mobileconfig
    echo ""
    exit 0
fi

# Interactive mode (default)
check_brave
check_brave_running
show_menu
