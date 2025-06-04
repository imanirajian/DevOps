#!/bin/bash

# =============================================================================
# @author   I_Irajian (Iman Irajian)
# Date:     5/25/2024 (Sun, Feb. 25)
# Time:     15:26
# =============================================================================
# Description:
# ============
#   Interactive git tagger for microservices.
#   - Auto-detects version from application.properties or package.json.
#   - Validates semantic versioning.
#   - Supports dry-run mode (--dry-run).
#   - Skips all or specific microservices using --skip-all or --skip=information,payment
#   - Records actions in audit log.
#   - Supports skipping and custom messages per service.
# =============================================================================
# Usage:
# ======
# bash tag.sh [--dry-run] [--skip-all] [--skip=user,information,ui]
# Example:
# bash tag.sh --dry-run --skip=payment
# =============================================================================
# Log:
# ====
# tag-microservices_audit.log
# =============================================================================

set -e
set -u

# === Configuration ===
# =============================================================================
services=("information" "user" "order" "payment" "catalog" "cart" "ui")
base_prefix="service"
current_date=$(date +"%d-%b-%Y")
current_time=$(date +"%H:%M:%S")
log_file="tag-microservices_audit.log"
regex_semver="^([0-9]+\.){2}[0-9]+$"

dry_run=false
skip_all=false
skip_list=()
summary=()

# === Argument Parsing ===
# =============================================================================
for arg in "$@"; do
    case $arg in
        --dry-run)
            dry_run=true
            ;;
        --skip-all)
            skip_all=true
            ;;
        --skip=*)
            IFS=',' read -r -a skip_list <<< "${arg#--skip=}"
            ;;
        *)
            echo "❌ Unknown argument: $arg"
            echo "Usage: ./tag-microservices.sh [--dry-run] [--skip-all] [--skip=ui,payment]"
            exit 1
            ;;
    esac
done

# === Startup Message ===
# =============================================================================
echo "=== 📝 Microservice Tagging Script 📝 ==="
echo "Date: $current_date"
echo "Time: $current_time"
echo "Audit log: $log_file"
echo

$dry_run && echo "🚧 DRY-RUN MODE: No git commands will be executed."
$skip_all && echo "⏭️  SKIP-ALL MODE: No microservices will be processed." && exit 0
[[ ${#skip_list[@]} -gt 0 ]] && echo "⏭️  Skipping specific services: ${skip_list[*]}"
echo

# === Fetch Tags for All Services ===
# =============================================================================
echo "Fetching latest tags from remote..."
for service in "${services[@]}"; do
    dir="${base_prefix}-${service}"
    [ -d "$dir" ] && (cd "$dir" && git fetch --tags --quiet)
done
echo "✔ Tags fetched."
echo

echo "==== Tagging session on $current_date $(date +"%H:%M:%S") ====" >> "$log_file"

# === Function to Extract Version ===
# =============================================================================
get_version() {
    local svc="$1"
    local dir="${base_prefix}-${svc}"

    if [[ "$svc" == "ui" ]]; then
        local pkg_file="${dir}/package.json"
        if command -v jq >/dev/null 2>&1; then
            jq -r '.version' "$pkg_file" 2>/dev/null || echo ""
        else
            # Fallback: grep + sed to extract version string
            grep -E '"version":' "$pkg_file" 2>/dev/null | sed -E 's/.*"version": *"([^"]+)".*/\1/' || echo ""
        fi
    else
        local path1="${dir}/${svc}-app/src/main/resources/application.properties"
        local path2="${dir}/src/main/resources/application.properties"

        if [[ -f "$path1" ]]; then
            grep -E '^app\.version=' "$path1" | cut -d= -f2
        elif [[ -f "$path2" ]]; then
            grep -E '^app\.version=' "$path2" | cut -d= -f2
        else
            echo ""
        fi
    fi
}

# === Loop Through Services ===
# =============================================================================
for service in "${services[@]}"; do
    if [[ " ${skip_list[*]} " =~ " $service " ]]; then
        echo ">> ${service^^} - SKIPPED (via --skip)"
        summary+=("${service^^} | SKIPPED")
        echo
        continue
    fi

    dir="${base_prefix}-${service}"

    echo ">> ${service^^}"
    echo "------------------------------"
    read -p "Do you want to tag ${service^^}? (y: Yes, [n: No]: default): " confirm_tag

    if [[ "$confirm_tag" != "y" ]]; then
        summary+=("${service^^} | SKIPPED")
        echo
        continue
    fi

    detected_version=$(get_version "$service")
    if [[ $detected_version =~ $regex_semver ]]; then
        echo "Auto-detected version: $detected_version"
    else
        echo "⚠️ Could not auto-detect version or invalid format."
        detected_version=""
    fi

    while true; do
        read -p "Enter version [${detected_version}]: " version
        version="${version:-$detected_version}"
        if [[ $version =~ $regex_semver ]]; then
            break
        else
            echo "❌ Invalid version format. Please use semantic versioning (e.g., 1.0.2)"
        fi
    done

    read -p "Enter message, Sample: [FEATURE: Adding sth | PATCH: Fixing sth | UPDATE: sth version]: " message
    full_message="[RELEASE-DEV-${version}-${current_date}]${message}"

    echo
    echo "Preview Tag for ${service^^}:"
    echo "  Version: $version"
    echo "  Message: $full_message"
    read -p "Confirm to push? (y: Yes, [n: No]: default): " confirm_push

    if [[ "$confirm_push" == "y" ]]; then
        if [ -d "$dir" ]; then
            cd "$dir"

            if $dry_run; then
                echo "[DRY-RUN] Would run: git tag -a \"$version\" -m \"$full_message\""
                echo "[DRY-RUN] Would run: git push origin \"$version\""
                summary+=("${service^^} | DRY-RUN")
                echo "${service^^} - $version - $current_date $(date +"%H:%M:%S") - DRY-RUN" >> "../$log_file"
            else
                git tag -a "$version" -m "$full_message"
                git push origin "$version"
                echo "✔ Tagged and pushed ${service^^} ($version)"
                summary+=("${service^^} | $version | SUCCESS")
                echo "${service^^} - $version - $current_date $(date +"%H:%M:%S") - SUCCESS" >> "../$log_file"
            fi

            cd ..
        else
            echo "❌ Directory $dir not found!"
            summary+=("${service^^} | $version | FAILED: Directory not found")
            echo "${service^^} - $version - $current_date $(date +"%H:%M:%S") - FAILED: Directory not found" >> "$log_file"
        fi
    else
        echo "Skipped pushing ${service^^}."
        summary+=("${service^^} | $version | CANCELLED")
        echo "${service^^} - $version - $current_date $(date +"%H:%M:%S") - CANCELLED" >> "$log_file"
    fi
    echo
done

# === Summary Table ===
# =============================================================================
echo "=================="
echo "✅ Summary:"
printf "%-10s | %-10s | %-40s\n" "SERVICE" "VERSION" "STATUS"
echo "---------------------------------------------------------------"
for line in "${summary[@]}"; do
    IFS="|" read -r svc version status <<< "$line"
    printf "%-10s | %-10s | %-40s\n" "$svc" "${version:-N/A}" "${status:-N/A}"
done

echo
echo "📝 Full audit log saved to $log_file"

