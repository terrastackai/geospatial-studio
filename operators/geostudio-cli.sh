#!/bin/bash
# ==============================================================================
# GeoStudio CLI - Unified Command Interface
# ==============================================================================
# Unified command-line interface for managing GeoStudio operator and applications
#
# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0
#
# Usage:
#   ./geostudio-cli.sh <command> [subcommand] [options]
#
# Commands:
#   operator    Manage the GeoStudio operator (infrastructure)
#   app         Manage GeoStudio application instances
#   help        Show detailed help
#
# Examples:
#   ./geostudio-cli.sh operator install --local
#   ./geostudio-cli.sh app deploy
#   ./geostudio-cli.sh app status --namespace prod
# ==============================================================================

set -euo pipefail

# ==============================================================================
# Initialize
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/.."
LIB_DIR="$SCRIPT_DIR/lib"

# Source shared libraries
source "$LIB_DIR/common.sh"
source "$LIB_DIR/k8s-utils.sh"

# Script version
CLI_VERSION="1.0.0"

# Global options
DRY_RUN=false
VERBOSE=false

# ==============================================================================
# Help Functions
# ==============================================================================

show_main_help() {
  cat << 'EOF'
GeoStudio CLI - Unified Management Interface

USAGE:
  geostudio-cli.sh <command> [subcommand] [options]

COMMANDS:
  operator    Manage the GeoStudio operator (infrastructure)
  app         Manage GeoStudio application instances
  help        Show this help message
  version     Show CLI version

OPERATOR SUBCOMMANDS:
  install     Install operator [--local|--prod] [--version VERSION]
  uninstall   Remove operator and CRDs [--keep-pvcs]
  status      Check operator health and readiness
  logs        View operator logs [--follow]
  restart     Restart operator deployment

APP SUBCOMMANDS:
  deploy      Deploy application instance [--env ENV] [--namespace NS]
  delete      Remove application instance [--namespace NS] [--keep-pvcs]
  list        List all deployed instances
  status      Check application health [--namespace NS]
  logs        View application logs [--namespace NS] [--component NAME]
  restart     Restart application pods [--namespace NS]

GLOBAL OPTIONS:
  --dry-run   Show what would happen without executing
  --verbose   Enable verbose output
  --help      Show help for command

EXAMPLES:
  # Install operator (once per cluster)
  geostudio-cli.sh operator install --local
  
  # Deploy application (can be run multiple times)
  geostudio-cli.sh app deploy
  geostudio-cli.sh app deploy --env staging --namespace staging
  
  # Check status
  geostudio-cli.sh operator status
  geostudio-cli.sh app status --namespace prod
  
  # View logs
  geostudio-cli.sh operator logs --follow
  geostudio-cli.sh app logs --namespace prod --component gateway
  
  # Clean up
  geostudio-cli.sh app delete --namespace staging
  geostudio-cli.sh operator uninstall

For more information, visit: https://github.com/geospatial-studio/geospatial-studio
EOF
}

show_operator_help() {
  cat << 'EOF'
GeoStudio CLI - Operator Management

USAGE:
  geostudio-cli.sh operator <subcommand> [options]

SUBCOMMANDS:
  install     Install the GeoStudio operator
  uninstall   Remove the GeoStudio operator and CRDs
  status      Check operator health and readiness
  logs        View operator logs
  restart     Restart the operator deployment

INSTALL OPTIONS:
  --local              Use locally built image (Lima development)
  --prod               Use production image from quay.io
  --version VERSION    Specify operator version (default: latest for prod, local for local)
  --namespace NS       Operator namespace (default: geostudio-operators-system)

UNINSTALL OPTIONS:
  --namespace NS       Operator namespace (default: geostudio-operators-system)
  --keep-pvcs          Don't delete PersistentVolumeClaims

STATUS OPTIONS:
  --namespace NS       Operator namespace (default: geostudio-operators-system)

LOGS OPTIONS:
  --namespace NS       Operator namespace (default: geostudio-operators-system)
  --follow, -f         Follow log output

RESTART OPTIONS:
  --namespace NS       Operator namespace (default: geostudio-operators-system)

EXAMPLES:
  # Install for local development
  geostudio-cli.sh operator install --local
  
  # Install for production
  geostudio-cli.sh operator install --prod --version v0.1.0
  
  # Check operator status
  geostudio-cli.sh operator status
  
  # View live logs
  geostudio-cli.sh operator logs --follow
  
  # Restart operator
  geostudio-cli.sh operator restart
  
  # Uninstall operator
  geostudio-cli.sh operator uninstall
EOF
}

show_app_help() {
  cat << 'EOF'
GeoStudio CLI - Application Management

USAGE:
  geostudio-cli.sh app <subcommand> [options]

SUBCOMMANDS:
  deploy      Deploy a GeoStudio application instance
  delete      Remove a GeoStudio application instance
  list        List all deployed GeoStudio instances
  status      Check application health
  logs        View application logs
  restart     Restart application pods

DEPLOY OPTIONS:
  --env ENV            Deployment environment (default: lima)
  --namespace NS       Target namespace (default: default)
  --dry-run           Generate manifest without applying

DELETE OPTIONS:
  --namespace NS       Target namespace (default: default)
  --keep-pvcs          Don't delete PersistentVolumeClaims

LIST OPTIONS:
  --namespace NS       Filter by namespace (default: all namespaces)

STATUS OPTIONS:
  --namespace NS       Target namespace (default: default)

LOGS OPTIONS:
  --namespace NS       Target namespace (default: default)
  --component NAME     Filter by component (gateway, ui, mlflow, etc.)
  --follow, -f         Follow log output

RESTART OPTIONS:
  --namespace NS       Target namespace (default: default)
  --component NAME     Restart specific component (default: all)

EXAMPLES:
  # Deploy to lima/default
  geostudio-cli.sh app deploy
  
  # Deploy to production
  geostudio-cli.sh app deploy --env production --namespace prod
  
  # List all instances
  geostudio-cli.sh app list
  
  # Check app status
  geostudio-cli.sh app status --namespace prod
  
  # View gateway logs
  geostudio-cli.sh app logs --namespace prod --component gateway --follow
  
  # Restart UI component
  geostudio-cli.sh app restart --namespace prod --component ui
  
  # Delete instance
  geostudio-cli.sh app delete --namespace staging
EOF
}

# ==============================================================================
# Command Router
# ==============================================================================

main() {
  # Check for no arguments
  if [ $# -eq 0 ]; then
    show_main_help
    exit 0
  fi
  
  # Parse global options first
  while [[ $# -gt 0 ]]; do
    case $1 in
      --dry-run)
        DRY_RUN=true
        export DRY_RUN
        shift
        ;;
      --verbose)
        VERBOSE=true
        set -x
        shift
        ;;
      --help)
        show_main_help
        exit 0
        ;;
      version|--version)
        echo "GeoStudio CLI version $CLI_VERSION"
        exit 0
        ;;
      help)
        show_main_help
        exit 0
        ;;
      operator)
        shift
        source "$LIB_DIR/operator-commands.sh"
        operator_command "$@"
        exit $?
        ;;
      app)
        shift
        source "$LIB_DIR/app-commands.sh"
        app_command "$@"
        exit $?
        ;;
      *)
        log_error "Unknown command: $1"
        echo ""
        echo "Run 'geostudio-cli.sh help' for usage information"
        exit 1
        ;;
    esac
  done
}

# ==============================================================================
# Trap Handlers
# ==============================================================================

cleanup() {
  # Clean up any temporary files
  if [ -n "${TEMP_MANIFEST:-}" ] && [ -f "$TEMP_MANIFEST" ]; then
    rm -f "$TEMP_MANIFEST" 2>/dev/null || true
  fi
}

trap cleanup EXIT
trap 'log_error "Script interrupted"; exit 130' INT TERM

# ==============================================================================
# Entry Point
# ==============================================================================

main "$@"
