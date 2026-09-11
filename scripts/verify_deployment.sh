#!/usr/bin/env bash
# ==============================================================================
# Cloud-1: Automated Deployment Verification Script
# Validates all mandatory requirements during peer evaluation / defense
# ==============================================================================

set -euo pipefail

TARGET_HOST="${1:-localhost}"
TARGET_IP="${2:-127.0.0.1}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

pass_count=0
fail_count=0

report_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    pass_count=$((pass_count + 1))
}

report_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    fail_count=$((fail_count + 1))
}

report_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

echo "========================================================================"
echo " Cloud-1 Deployment Verification & Peer Defense Checklist"
echo " Target Host: ${TARGET_HOST}"
echo " Target IP:   ${TARGET_IP}"
echo "========================================================================"

# ------------------------------------------------------------------------------
# 1. Firewall & Port Accessibility (Ports 22, 80, 443 only)
# ------------------------------------------------------------------------------
report_info "Test 1: Checking External Port Accessibility..."

# Port 80 (HTTP)
if nc -z -w 3 "${TARGET_IP}" 80 2>/dev/null || curl -s -o /dev/null --connect-timeout 3 "http://${TARGET_IP}:80"; then
    report_pass "Port 80 (HTTP) is open and accessible."
else
    report_fail "Port 80 (HTTP) is NOT reachable."
fi

# Port 443 (HTTPS)
if nc -z -w 3 "${TARGET_IP}" 443 2>/dev/null || curl -k -s -o /dev/null --connect-timeout 3 "https://${TARGET_IP}:443"; then
    report_pass "Port 443 (HTTPS) is open and accessible."
else
    report_fail "Port 443 (HTTPS) is NOT reachable."
fi

# Port 22 (SSH)
if nc -z -w 3 "${TARGET_IP}" 22 2>/dev/null; then
    report_pass "Port 22 (SSH) is open and accessible."
else
    report_info "Port 22 check skipped or blocked by network filter."
fi

# ------------------------------------------------------------------------------
# 2. Database Isolation (Port 3306 MUST be BLOCKED)
# ------------------------------------------------------------------------------
report_info "Test 2: Verifying MariaDB Database Port 3306 is BLOCKED from the internet..."

if nc -z -w 2 "${TARGET_IP}" 3306 2>/dev/null; then
    report_fail "CRITICAL: Port 3306 is OPEN to the public! Public access to database must be blocked!"
else
    report_pass "Port 3306 (MySQL/MariaDB) is properly blocked from external access."
fi

# ------------------------------------------------------------------------------
# 3. HTTP (80) -> HTTPS (443) 301 Permanent Redirection
# ------------------------------------------------------------------------------
report_info "Test 3: Testing HTTP to HTTPS 301 Redirection..."

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: ${TARGET_HOST}" "http://${TARGET_IP}/" || true)
REDIRECT_URL=$(curl -s -o /dev/null -w "%{redirect_url}" -H "Host: ${TARGET_HOST}" "http://${TARGET_IP}/" || true)

if [ "${HTTP_CODE}" = "301" ]; then
    report_pass "HTTP 80 returned 301 Moved Permanently redirecting to: ${REDIRECT_URL}"
else
    report_fail "HTTP 80 did not return 301 (Received HTTP ${HTTP_CODE})"
fi

# ------------------------------------------------------------------------------
# 4. HTTPS WordPress Availability (Root Path /)
# ------------------------------------------------------------------------------
report_info "Test 4: Testing WordPress over HTTPS (Port 443)..."

WP_HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" -H "Host: ${TARGET_HOST}" "https://${TARGET_IP}/" || true)

if [ "${WP_HTTP_CODE}" = "200" ] || [ "${WP_HTTP_CODE}" = "302" ]; then
    report_pass "WordPress is accessible via HTTPS (HTTP Status: ${WP_HTTP_CODE})"
else
    report_fail "WordPress failed to respond on HTTPS / (HTTP Status: ${WP_HTTP_CODE})"
fi

# ------------------------------------------------------------------------------
# 5. phpMyAdmin Availability (/phpmyadmin/ Path)
# ------------------------------------------------------------------------------
report_info "Test 5: Testing phpMyAdmin over HTTPS (/phpmyadmin/)..."

PMA_CONTENT=$(curl -k -s -L -H "Host: ${TARGET_HOST}" "https://${TARGET_IP}/phpmyadmin/" || true)

if echo "${PMA_CONTENT}" | grep -qi "phpMyAdmin"; then
    report_pass "phpMyAdmin is successfully accessible and rendering login page."
else
    report_fail "phpMyAdmin page content does not match expected response."
fi

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
echo "========================================================================"
echo " Verification Summary"
echo " Passed: ${pass_count}"
echo " Failed: ${fail_count}"
echo "========================================================================"

if [ "${fail_count}" -eq 0 ]; then
    echo -e "${GREEN}[SUCCESS] All Cloud-1 mandatory checks passed successfully!${NC}"
    exit 0
else
    echo -e "${RED}[WARNING] Some checks failed. Please inspect logs and configuration.${NC}"
    exit 1
fi
