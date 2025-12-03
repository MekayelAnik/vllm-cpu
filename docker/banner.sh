#!/bin/bash
# =============================================================================
# vLLM-CPU Docker Banner Script
# =============================================================================
# Displays startup information for the vLLM-CPU Docker container

# Colors
BLUE='\033[38;5;12m'
GREEN='\033[38;5;10m'
ORANGE='\033[38;5;208m'
CYAN='\033[38;5;51m'
GRAY='\033[38;5;250m'
NC='\033[0m'

# Print ASCII art banner
print_banner() {
    printf "${CYAN}"
    printf "        _     _     __  __        ____ ____  _   _\n"
    printf " __   _| |   | |   |  \/  |      / ___|  _ \| | | |\n"
    printf " \ \ / / |   | |   | |\/| |_____| |   | |_) | | | |\n"
    printf "  \ V /| |___| |___| |  | |_____| |___|  __/| |_| |\n"
    printf "   \_/ |_____|_____|_|  |_|      \____|_|    \___/\n"
    printf "${NC}\n"
}

# Print system information
print_info() {
    local variant="${VLLM_CPU_VARIANT:-unknown}"
    local vllm_version=$(python -c 'import vllm; print(vllm.__version__)' 2>/dev/null || echo "unknown")
    local python_version=$(python --version 2>&1 | cut -d' ' -f2)
    local container_ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "N/A")
    local host="${VLLM_HOST:-0.0.0.0}"
    local port="${VLLM_PORT:-8000}"

    printf "${GRAY}══════════════════════════════════════════════════════════════════${NC}\n"
    printf "${BLUE}  vLLM CPU Inference Engine${NC}\n"
    printf "${GRAY}══════════════════════════════════════════════════════════════════${NC}\n"
    printf "\n"
    printf "${GREEN}  Variant:${NC}        %s\n" "$variant"
    printf "${GREEN}  vLLM Version:${NC}   %s\n" "$vllm_version"
    printf "${GREEN}  Python:${NC}         %s\n" "$python_version"
    printf "${GREEN}  Container IP:${NC}   %s\n" "$container_ip"
    printf "\n"
    printf "${ORANGE}  API Endpoint:${NC}   http://%s:%s\n" "$container_ip" "$port"
    printf "${ORANGE}  Health Check:${NC}   http://%s:%s/health\n" "$container_ip" "$port"
    printf "${ORANGE}  OpenAI API:${NC}     http://%s:%s/v1\n" "$container_ip" "$port"
    printf "\n"
    printf "${GRAY}══════════════════════════════════════════════════════════════════${NC}\n"
    printf "${GRAY}  GitHub: https://github.com/MekayelAnik/vllm-cpu${NC}\n"
    printf "${GRAY}  Docs:   https://docs.vllm.ai/en/stable/getting_started/installation/cpu/${NC}\n"
    printf "${GRAY}══════════════════════════════════════════════════════════════════${NC}\n"
    printf "\n"
}

# Main execution
main() {
    print_banner
    print_info
}

main
