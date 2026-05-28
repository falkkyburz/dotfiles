#!/usr/bin/env bash
set -euo pipefail

TARGET_HOST=${1:-example.com}
TARGET_IP=${NETWORK_DOCTOR_IP:-1.1.1.1}
DNS_TEST_HOST=${NETWORK_DOCTOR_DNS_HOST:-$TARGET_HOST}

ok() {
  printf '[ok]   %s\n' "$1"
}

warn() {
  printf '[warn] %s\n' "$1"
}

fail() {
  printf '[fail] %s\n' "$1"
}

note() {
  printf '       %s\n' "$1"
}

section() {
  printf '\n%s\n' "$1"
}

have() {
  command -v "$1" >/dev/null 2>&1
}

run_capture() {
  "$@" 2>&1 || true
}

check_binary() {
  local name=$1 required=${2:-0}

  if have "$name"; then
    ok "found $name at $(command -v "$name")"
  elif [[ "$required" == 1 ]]; then
    fail "missing required command: $name"
  else
    warn "missing optional command: $name"
  fi
}

print_resolv_conf() {
  if [[ ! -e /etc/resolv.conf ]]; then
    fail '/etc/resolv.conf does not exist'
    return
  fi

  if [[ -L /etc/resolv.conf ]]; then
    printf 'symlink: /etc/resolv.conf -> %s\n' "$(readlink /etc/resolv.conf)"
  else
    printf 'file: /etc/resolv.conf\n'
  fi

  awk '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    /^(nameserver|search|domain|options)/ { print "  " $0; found=1 }
    END { if (!found) print "  [warn] no resolver settings found" }
  ' /etc/resolv.conf
}

print_devices() {
  if have nmcli; then
    nmcli -f DEVICE,TYPE,STATE,CONNECTION device status 2>/dev/null || warn 'nmcli device status failed'
    return
  fi

  if have ip; then
    ip -brief addr show
  else
    warn 'cannot show devices without nmcli or ip'
  fi
}

print_routes() {
  if ! have ip; then
    warn 'cannot show routes without ip'
    return
  fi

  printf 'IPv4 routes:\n'
  ip route show | sed 's/^/  /'

  printf 'IPv6 routes:\n'
  local route6
  route6=$(ip -6 route show || true)
  if [[ -n "$route6" ]]; then
    sed 's/^/  /' <<<"$route6"
  else
    warn 'no IPv6 routes found'
  fi

  if ip route show default | grep -q .; then
    ok 'IPv4 default route exists'
  else
    fail 'no IPv4 default route'
  fi

  if ip -6 route show default | grep -q .; then
    ok 'IPv6 default route exists'
  else
    warn 'no IPv6 default route; IPv6 internet access will fail'
  fi
}

test_dns() {
  local host=$1

  if have getent; then
    if getent ahostsv4 "$host" >/dev/null 2>&1; then
      ok "IPv4 DNS resolves $host"
      getent ahostsv4 "$host" | awk 'NR <= 4 { print "       " $0 }'
    else
      fail "IPv4 DNS failed for $host"
    fi

    if getent ahostsv6 "$host" >/dev/null 2>&1; then
      ok "IPv6 DNS resolves $host"
      getent ahostsv6 "$host" | awk 'NR <= 4 { print "       " $0 }'
    else
      warn "IPv6 DNS did not return usable addresses for $host"
    fi
  else
    warn 'cannot test DNS without getent'
  fi
}

test_ping() {
  local target=$1 label=$2

  if ! have ping; then
    warn 'cannot test ICMP without ping'
    return
  fi

  if ping -c 3 -W 2 "$target" >/dev/null 2>&1; then
    ok "$label ping works: $target"
  else
    warn "$label ping failed: $target"
  fi
}

test_http() {
  local family=$1 url=$2 label=$3

  if ! have curl; then
    warn 'cannot test HTTP without curl'
    return
  fi

  local out code
  out=$(curl "$family" -I --connect-timeout 5 --max-time 10 -sS -o /dev/null -w '%{http_code}' "$url" 2>&1) || {
    warn "$label failed: $url"
    note "$out"
    return
  }

  code=${out##*$'\n'}
  if [[ "$code" =~ ^[123][0-9][0-9]$ ]]; then
    ok "$label works: $url returned HTTP $code"
  else
    warn "$label reached $url but returned HTTP $code"
  fi
}

print_nm_details() {
  if ! have nmcli; then
    warn 'cannot inspect NetworkManager without nmcli'
    return
  fi

  nmcli -f GENERAL.DEVICE,GENERAL.TYPE,GENERAL.STATE,GENERAL.CONNECTION,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS,IP6.GATEWAY,IP6.DNS device show 2>/dev/null |
    awk '
      /^GENERAL.DEVICE:/ { device=$0; sub(/^GENERAL.DEVICE:[[:space:]]*/, "", device); printed=0 }
      /^GENERAL.TYPE:/ { type=$0; sub(/^GENERAL.TYPE:[[:space:]]*/, "", type) }
      /^GENERAL.STATE:/ { state=$0; sub(/^GENERAL.STATE:[[:space:]]*/, "", state) }
      /^GENERAL.CONNECTION:/ { conn=$0; sub(/^GENERAL.CONNECTION:[[:space:]]*/, "", conn) }
      /^IP[46]\./ {
        if (!printed) {
          printf "%s (%s, %s, %s)\n", device, type, state, conn
          printed=1
        }
        print "  " $0
      }
    '
}

nft_ruleset() {
  if ! have nft; then
    return 1
  fi

  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    nft list ruleset
    return 0
  fi

  if have sudo; then
    printf 'sudo is required to inspect the active nftables ruleset.\n' >&2
    sudo nft list ruleset
    return $?
  fi

  return 1
}

print_nftables() {
  if have systemctl; then
    if systemctl is-active --quiet nftables.service; then
      ok 'nftables.service is active'
    else
      warn 'nftables.service is not active; rules may still exist if another tool loaded them'
    fi
  fi

  if ! have nft; then
    warn 'cannot inspect nftables without nft'
    return
  fi

  local rules
  if ! rules=$(nft_ruleset 2>&1); then
    warn 'cannot read active nftables ruleset; sudo/root access is required'
    note 'run this script as root or install/configure sudo'
    return
  fi

  local inet_input_policy inet_forward_policy inet_output_policy forward_hooks
  inet_input_policy=$(awk '/table inet filter/,/^}/ { if ($1 == "chain" && $2 == "input") in_chain=1; if (in_chain && /policy/) { print; exit } }' <<<"$rules")
  inet_forward_policy=$(awk '/table inet filter/,/^}/ { if ($1 == "chain" && $2 == "forward") in_chain=1; if (in_chain && /policy/) { print; exit } }' <<<"$rules")
  inet_output_policy=$(awk '/table inet filter/,/^}/ { if ($1 == "chain" && $2 == "output") in_chain=1; if (in_chain && /policy/) { print; exit } }' <<<"$rules")
  forward_hooks=$(grep -c 'hook forward' <<<"$rules" || true)

  [[ -n "$inet_input_policy" ]] && note "inet input: $inet_input_policy"
  [[ -n "$inet_forward_policy" ]] && note "inet forward: $inet_forward_policy"
  [[ -n "$inet_output_policy" ]] && note "inet output: $inet_output_policy"

  if grep -q 'chain output .*policy accept\|hook output .*policy accept' <<<"$rules"; then
    ok 'at least one output base chain has policy accept'
  else
    warn 'no obvious accept-policy output chain found; outbound traffic may be filtered'
  fi

  if grep -q 'table inet filter' <<<"$rules" && grep -q 'chain input' <<<"$rules" && grep -q 'policy drop' <<<"$rules"; then
    ok 'default-drop input firewall detected'
  fi

  if ((forward_hooks > 1)); then
    warn "multiple forward base chains detected ($forward_hooks); Docker and inet forward policy can both affect forwarded packets"
  fi

  if grep -q 'table ip nat' <<<"$rules" && grep -q 'MASQUERADE' <<<"$rules"; then
    ok 'Docker IPv4 NAT masquerade rules are present'
  else
    warn 'Docker IPv4 NAT masquerade rules were not detected'
  fi

  if grep -q 'table ip filter' <<<"$rules" && grep -q 'DOCKER-FORWARD' <<<"$rules"; then
    ok 'Docker iptables-nft filter chains are present'
  fi

  if grep -q 'table inet filter' <<<"$rules" && grep -q 'iifname "br-\*" accept' <<<"$rules"; then
    ok 'inet forward chain allows traffic from Docker-style br-* bridges'
  elif grep -q 'table inet filter' <<<"$rules"; then
    warn 'inet forward chain does not obviously allow br-* bridge ingress'
  fi
}

print_summary_hint() {
  section 'Interpretation'
  printf 'If IPv4 IP ping works but DNS fails, inspect /etc/resolv.conf and the listed nameserver.\n'
  printf 'If DNS works but HTTPS fails, inspect nftables output policy, proxy settings, MTU, and remote filtering.\n'
  printf 'If only IPv6 fails and there is no IPv6 default route, disable IPv6 for clients that prefer it or configure IPv6 on the router/ISP side.\n'
  printf 'With nftables, remember Docker uses iptables-nft tables; inet forward chains can still drop forwarded Docker traffic.\n'
}

if [[ "${1:-}" == '-h' || "${1:-}" == '--help' ]]; then
  printf 'Usage: %s [host]\n' "${0##*/}"
  printf 'Defaults to example.com. Set NETWORK_DOCTOR_IP to override the raw IPv4 connectivity target.\n'
  exit 0
fi

printf 'Network doctor\n'
printf 'target host: %s\n' "$TARGET_HOST"
printf 'target IPv4: %s\n' "$TARGET_IP"

section 'Binaries'
check_binary ip 1
check_binary getent 1
check_binary ping 0
check_binary curl 0
check_binary nmcli 0
check_binary nft 0
check_binary systemctl 0

section 'Devices'
print_devices

section 'Routes'
print_routes

section 'Resolver'
print_resolv_conf

section 'NetworkManager'
print_nm_details

section 'DNS'
test_dns "$DNS_TEST_HOST"

section 'Connectivity'
test_ping "$TARGET_IP" 'IPv4 raw'
test_ping "$TARGET_HOST" 'hostname'
test_http -4 "https://$TARGET_HOST" 'IPv4 HTTPS'
test_http -6 "https://$TARGET_HOST" 'IPv6 HTTPS'

section 'nftables'
print_nftables

print_summary_hint
