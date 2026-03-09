#!/bin/bash
#
# Configure PAN-OS firewall for GCP Aviatrix FireNet
#
# This script can be run after deployment to configure (or reconfigure) a
# PAN-OS firewall. It is idempotent and safe to run multiple times. It also
# cleans up legacy DNAT-based ILB health check rules if present.
#
# What it configures:
#   - Hostname
#   - Interface zones (WAN/LAN) and management profiles
#   - Static routes (default via egress, RFC1918 + Google HC ranges via LAN)
#   - Loopback interfaces for ILB health checks (VIP IPs with mgmt profile)
#   - External Application LB inbound NAT rules (DNAT to workload + SNAT via LAN interface)
#   - NAT-Out rule (LAN→WAN source NAT)
#   - Security rules (Allow-Any-Out LAN→WAN, Allow-Inbound per ELB rule)
#
# Usage:
#   ./configure-pan-fw.sh [OPTIONS] <fw_mgmt_ip> <hostname> \
#                         <egress_gateway> <lan_gateway> \
#                         <ilb_vip1> [ilb_vip2 ...] \
#                         [-- <fw_egress_ip> <rule_name>:<frontend_port>:<backend_port>:<destination_ip> ...]
#
# Options:
#   -k <path>   SSH private key file (default: ~/.ssh/id_rsa)
#   -w <secs>   Wait up to N seconds for firewall SSH to become ready (default: 0, no wait)
#   -d          Dry run — print the PAN-OS commands without connecting
#   -h          Show this help
#
# Example:
#   ./configure-pan-fw.sh -k ~/.ssh/pan_key -w 300 \
#     34.74.151.89 gcp-us-transit-fw1 \
#     10.1.243.1 10.1.241.1 \
#     10.1.241.99 10.1.241.100 \
#     -- 10.1.243.4 app-https:443:8443:10.0.1.5 app-api:8080:80:10.0.2.10
#

set -euo pipefail

SSH_KEY=""
WAIT_SECS=0
DRY_RUN=false

usage() {
  echo "Usage: $0 [OPTIONS] <fw_mgmt_ip> <hostname> <egress_gateway> <lan_gateway> <ilb_vip1> [ilb_vip2 ...] [-- <fw_egress_ip> <rule>...]"
  echo ""
  echo "Options:"
  echo "  -k <path>   SSH private key file (default: ~/.ssh/id_rsa)"
  echo "  -w <secs>   Wait up to N seconds for firewall SSH to become ready (default: 0)"
  echo "  -d          Dry run — print PAN-OS commands without connecting"
  echo "  -h          Show this help"
  echo ""
  echo "Arguments:"
  echo "  fw_mgmt_ip      Management IP of the firewall (SSH target)"
  echo "  hostname         Hostname to set on the firewall"
  echo "  egress_gateway   Egress subnet gateway (e.g., x.x.x.1)"
  echo "  lan_gateway      LAN subnet gateway (e.g., x.x.x.1)"
  echo "  ilb_vip1...      One or more ILB VIP addresses (assigned to loopback interfaces)"
  echo ""
  echo "ELB NAT rules (after --):"
  echo "  First arg after -- is the FW egress NIC IP (DNAT destination match)"
  echo "  Then rules in format: <name>:<frontend_port>:<backend_port>:<destination_ip>"
  echo "  Example: -- 10.30.0.4 app-https:443:8443:10.0.1.5"
  exit 1
}

while getopts "k:w:dh" opt; do
  case ${opt} in
    k) SSH_KEY="${OPTARG}" ;;
    w) WAIT_SECS="${OPTARG}" ;;
    d) DRY_RUN=true ;;
    h) usage ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))

if [ $# -lt 5 ]; then
  usage
fi

FW_MGMT_IP="$1"
HOSTNAME="$2"
EGRESS_GW="$3"
LAN_GW="$4"
shift 4

# Collect ILB VIPs (everything before -- or end of args)
ILB_VIPS=()
while [ $# -gt 0 ] && [ "$1" != "--" ]; do
  ILB_VIPS+=("$1")
  shift
done

# Collect FW egress IP and rules (everything after --)
FW_EGRESS_IP=""
ELB_RULES=()
if [ $# -gt 0 ] && [ "$1" = "--" ]; then
  shift
  if [ $# -gt 0 ]; then
    FW_EGRESS_IP="$1"
    shift
    ELB_RULES=("$@")
  fi
fi

if [ ${#ILB_VIPS[@]} -lt 1 ]; then
  echo "ERROR: At least one ILB VIP is required" >&2
  usage
fi

echo "=== PAN-OS Firewall Configuration ==="
echo "Target:          ${FW_MGMT_IP}"
echo "Hostname:        ${HOSTNAME}"
echo "Egress Gateway:  ${EGRESS_GW}"
echo "LAN Gateway:     ${LAN_GW}"
echo "ILB VIPs:        ${ILB_VIPS[*]}"
if [ -n "${FW_EGRESS_IP}" ]; then
  echo "FW Egress IP:    ${FW_EGRESS_IP}"
fi
if [ ${#ELB_RULES[@]} -gt 0 ]; then
  echo "ELB NAT Rules:   ${ELB_RULES[*]}"
fi
if [ -n "${SSH_KEY}" ]; then
  echo "SSH Key:         ${SSH_KEY}"
fi
if [ "${DRY_RUN}" = true ]; then
  echo "Mode:            DRY RUN"
fi
echo ""

# Build loopback interface commands for ILB health checks
LOOPBACK_CMDS=""
LOOPBACK_ZONE_CMDS=""
LOOPBACK_VR_CMDS=""
LOOPBACK_IMPORT_CMDS=""
for i in "${!ILB_VIPS[@]}"; do
  VIP="${ILB_VIPS[$i]}"
  LO_NUM=$((i + 1))
  LOOPBACK_CMDS+="set network interface loopback units loopback.${LO_NUM} ip ${VIP}/32
set network interface loopback units loopback.${LO_NUM} interface-management-profile Main-Mgmt-Profile
"
  LOOPBACK_ZONE_CMDS+="set zone LAN network layer3 loopback.${LO_NUM}
"
  LOOPBACK_VR_CMDS+="set network virtual-router default interface loopback.${LO_NUM}
"
  LOOPBACK_IMPORT_CMDS+="set import network interface loopback.${LO_NUM}
"
done

# Build ELB NAT rule commands (DNAT + SNAT per rule)
ELB_CLEANUP_CMDS=""
ELB_ADDRESS_CMDS=""
ELB_SERVICE_CMDS=""
ELB_NAT_CMDS=""
ELB_SECURITY_CMDS=""

if [ ${#ELB_RULES[@]} -gt 0 ]; then
  # Clean up old ELB rules and objects before recreating (idempotent)
  ELB_CLEANUP_CMDS+="delete rulebase pbf rules ELB-HC-Return
"
  for RULE in "${ELB_RULES[@]}"; do
    IFS=':' read -r NAME FPORT BPORT DEST_IP <<< "${RULE}"
    ELB_CLEANUP_CMDS+="delete rulebase nat rules DNAT-${NAME}
delete rulebase security rules Allow-Inbound-${NAME}
delete address elb-${NAME}-dest
delete service svc-elb-${NAME}
"
  done
  ELB_CLEANUP_CMDS+="delete address elb-public-ip
delete address fw-egress-ip
"

  # Address object for FW egress IP (DNAT destination match — Application LB sends to this IP)
  ELB_ADDRESS_CMDS+="set address fw-egress-ip ip-netmask ${FW_EGRESS_IP}/32
"

  for RULE in "${ELB_RULES[@]}"; do
    IFS=':' read -r NAME FPORT BPORT DEST_IP <<< "${RULE}"

    # Address object for workload destination
    ELB_ADDRESS_CMDS+="set address elb-${NAME}-dest ip-netmask ${DEST_IP}/32
"
    # Service object for frontend port
    ELB_SERVICE_CMDS+="set service svc-elb-${NAME} protocol tcp port ${FPORT}
"
    # DNAT + SNAT rule (to any — SNAT session table handles return path)
    ELB_NAT_CMDS+="set rulebase nat rules DNAT-${NAME} from WAN
set rulebase nat rules DNAT-${NAME} to any
set rulebase nat rules DNAT-${NAME} source any
set rulebase nat rules DNAT-${NAME} destination fw-egress-ip
set rulebase nat rules DNAT-${NAME} service svc-elb-${NAME}
set rulebase nat rules DNAT-${NAME} destination-translation translated-address elb-${NAME}-dest
set rulebase nat rules DNAT-${NAME} destination-translation translated-port ${BPORT}
set rulebase nat rules DNAT-${NAME} source-translation dynamic-ip-and-port interface-address interface ethernet1/2
"
    # Ensure DNAT rule is before NAT-Out
    ELB_NAT_CMDS+="move rulebase nat rules DNAT-${NAME} before NAT-Out
"
    # Security rule: allow inbound for this service
    ELB_SECURITY_CMDS+="set rulebase security rules Allow-Inbound-${NAME} from WAN
set rulebase security rules Allow-Inbound-${NAME} to any
set rulebase security rules Allow-Inbound-${NAME} source any
set rulebase security rules Allow-Inbound-${NAME} destination fw-egress-ip
set rulebase security rules Allow-Inbound-${NAME} application any
set rulebase security rules Allow-Inbound-${NAME} service svc-elb-${NAME}
set rulebase security rules Allow-Inbound-${NAME} action allow
"
  done

  # PBF rule: force DNAT'd return traffic (from workloads via LAN) destined to
  # Google HC ranges back out WAN. Without this, the static routes for 35.191.0.0/16
  # etc. (needed for ILB HC) would send return traffic back into LAN.
  ELB_SECURITY_CMDS+="set rulebase pbf rules ELB-HC-Return from LAN
set rulebase pbf rules ELB-HC-Return source any
set rulebase pbf rules ELB-HC-Return destination Google-Health-Checks
set rulebase pbf rules ELB-HC-Return action forward egress-interface ethernet1/1 nexthop ip-address ${EGRESS_GW}
set rulebase pbf rules ELB-HC-Return action forward monitor disable no
"

fi

# Build the full PAN-OS configuration command block
CONFIG_CMDS=$(cat <<PANOS
configure

# --- Hostname ---
set deviceconfig system hostname ${HOSTNAME}

# --- Interfaces (DHCP, link-state) ---
set network interface ethernet ethernet1/1 layer3 dhcp-client enable yes create-default-route no
set network interface ethernet ethernet1/1 link-state auto
set network interface ethernet ethernet1/2 layer3 dhcp-client enable yes create-default-route no
set network interface ethernet ethernet1/2 link-state auto

# --- Management Profiles ---
set network profiles interface-management-profile Main-Mgmt-Profile ping yes ssh yes https yes http no
delete network interface ethernet ethernet1/1 layer3 interface-management-profile
set network interface ethernet ethernet1/2 layer3 interface-management-profile Main-Mgmt-Profile

# --- Virtual Router & Interfaces ---
set network virtual-router default interface ethernet1/1
set network virtual-router default interface ethernet1/2

# --- Static Routes ---
set network virtual-router default routing-table ip static-route default-route destination 0.0.0.0/0 interface ethernet1/1 nexthop ip-address ${EGRESS_GW}
set network virtual-router default routing-table ip static-route rfc1918-10 destination 10.0.0.0/8 interface ethernet1/2 nexthop ip-address ${LAN_GW}
set network virtual-router default routing-table ip static-route rfc1918-172 destination 172.16.0.0/12 interface ethernet1/2 nexthop ip-address ${LAN_GW}
set network virtual-router default routing-table ip static-route rfc1918-192 destination 192.168.0.0/16 interface ethernet1/2 nexthop ip-address ${LAN_GW}
set network virtual-router default routing-table ip static-route google-hc-1 destination 35.191.0.0/16 interface ethernet1/2 nexthop ip-address ${LAN_GW}
set network virtual-router default routing-table ip static-route google-hc-2 destination 130.211.0.0/22 interface ethernet1/2 nexthop ip-address ${LAN_GW}
set network virtual-router default routing-table ip static-route google-hc-3 destination 209.85.152.0/22 interface ethernet1/2 nexthop ip-address ${LAN_GW}
set network virtual-router default routing-table ip static-route google-hc-4 destination 209.85.204.0/22 interface ethernet1/2 nexthop ip-address ${LAN_GW}

# --- Loopback Interfaces (ILB Health Checks) ---
${LOOPBACK_CMDS}
${LOOPBACK_ZONE_CMDS}
${LOOPBACK_VR_CMDS}
${LOOPBACK_IMPORT_CMDS}
# --- Cleanup: remove legacy DNAT-based ILB/cross-check rules (if present) ---
delete rulebase nat rules HC-DNAT-LAN-TCP
delete rulebase nat rules HC-DNAT-LAN-UDP
delete rulebase nat rules HC-DNAT-LAN-0
delete rulebase nat rules HC-DNAT-LAN-1
delete rulebase nat rules HealthCheck-DNAT
delete rulebase pbf rules HC-Return-LAN
delete address-group ILB-VIPs
delete address ILB-TCP-VIP
delete address ILB-UDP-VIP
delete address ILB-VIP-0
delete address ILB-VIP-1

# --- Cleanup old ELB rules (delete before recreating) ---
${ELB_CLEANUP_CMDS}
# --- Address Objects ---
set address Google-HC-1 ip-netmask 35.191.0.0/16
set address Google-HC-2 ip-netmask 130.211.0.0/22
set address Google-HC-3 ip-netmask 209.85.152.0/22
set address Google-HC-4 ip-netmask 209.85.204.0/22
set address-group Google-Health-Checks static [ Google-HC-1 Google-HC-2 Google-HC-3 Google-HC-4 ]
${ELB_ADDRESS_CMDS}
# --- Service Objects ---
${ELB_SERVICE_CMDS}
# --- ELB Inbound NAT Rules (DNAT + SNAT) ---
${ELB_NAT_CMDS}
# --- ELB Inbound Security Rules ---
${ELB_SECURITY_CMDS}
# --- Security Rule ---
delete rulebase security rules Allow-Any-Out
set rulebase security rules Allow-Any-Out from LAN
set rulebase security rules Allow-Any-Out to WAN
set rulebase security rules Allow-Any-Out source any
set rulebase security rules Allow-Any-Out destination any
set rulebase security rules Allow-Any-Out application any
set rulebase security rules Allow-Any-Out service any
set rulebase security rules Allow-Any-Out action allow

# --- NAT: Source NAT Outbound ---
delete rulebase nat rules NAT-Out
set rulebase nat rules NAT-Out from LAN
set rulebase nat rules NAT-Out to WAN
set rulebase nat rules NAT-Out source any
set rulebase nat rules NAT-Out destination any
set rulebase nat rules NAT-Out service any
set rulebase nat rules NAT-Out source-translation dynamic-ip-and-port interface-address interface ethernet1/1

# --- Commit ---
commit

exit
PANOS
)

if [ "${DRY_RUN}" = true ]; then
  echo "--- PAN-OS Commands (dry run) ---"
  echo "${CONFIG_CMDS}"
  echo "--- End ---"
  exit 0
fi

# Build SSH options
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10"
if [ -n "${SSH_KEY}" ]; then
  SSH_OPTS+=" -i ${SSH_KEY}"
fi

# Wait for firewall SSH to become ready
if [ "${WAIT_SECS}" -gt 0 ]; then
  echo "Waiting up to ${WAIT_SECS}s for ${FW_MGMT_IP} to accept SSH..."
  DEADLINE=$(($(date +%s) + WAIT_SECS))
  while true; do
    if ssh ${SSH_OPTS} -o BatchMode=yes "admin@${FW_MGMT_IP}" echo ready 2>/dev/null; then
      echo "Firewall is ready."
      break
    fi
    if [ "$(date +%s)" -ge "${DEADLINE}" ]; then
      echo "ERROR: Timed out waiting for SSH on ${FW_MGMT_IP}" >&2
      exit 1
    fi
    echo "  Not ready yet, retrying in 15s..."
    sleep 15
  done
fi

echo "Connecting to ${FW_MGMT_IP}..."
echo "${CONFIG_CMDS}" | ssh ${SSH_OPTS} "admin@${FW_MGMT_IP}"

echo ""
echo "=== Configuration complete for ${HOSTNAME} (${FW_MGMT_IP}) ==="
