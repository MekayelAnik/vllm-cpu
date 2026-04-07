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
    printf "${CYAN}             /SS       /SS       /SS      /SS            /SSSSSS  /SSSSSSS  /SS   /SS   ${NC}\n"
    printf "${CYAN}            | SS      | SS      | SSS    /SSS           /SS__  SS| SS__  SS| SS  | SS   ${NC}\n"
    printf "${CYAN}  /SS    /SS| SS      | SS      | SSSS  /SSSS          | SS  \__/| SS  \ SS| SS  | SS   ${NC}\n"
    printf "${CYAN} |  SS  /SS/| SS      | SS      | SS SS/SS SS  /SSSSSS | SS      | SSSSSSS/| SS  | SS   ${NC}\n"
    printf "${CYAN}  \  SS/SS/ | SS      | SS      | SS  SSS| SS |______/ | SS      | SS____/ | SS  | SS   ${NC}\n"
    printf "${CYAN}   \  SSS/  | SS      | SS      | SS\  S | SS          | SS    SS| SS      | SS  | SS   ${NC}\n"
    printf "${CYAN}    \  S/   | SSSSSSSS| SSSSSSSS| SS \/  | SS          |  SSSSSS/| SS      |  SSSSSS/   ${NC}\n"
    printf "${CYAN}     \_/    |________/|________/|__/     |__/           \______/ |__/       \______/    ${NC}\n"
    printf "\n"

    printf "${BLUE}"
    printf "${BLUE} 888888ba                                      dP         dP        dP                                             dP                dP    ${NC}\n"
    printf "${BLUE} 88     8b                                     88         88        88                                             88                88    ${NC}\n"
    printf "${BLUE} a88aaaa8P 88d888b. .d8888b. dP    dP .d8888b. 88d888b. d8888P    d8888P .d8888b.    dp    dp .d8888b. dP    dP    88d888b. dP    dP       ${NC}\n"
    printf "${BLUE} 88    8b. 88    88 88    88 88    88 88    88 88    88   88        88   88    88    88    88 88    88 88    88    88    88 88    88       ${NC}\n" 
    printf "${BLUE} 88    .88 88       88.  .88 88.  .88 88.  .88 88    88   88        88   88.  .88    88.  .88 88.  .88 88.  .88    88.  .88 88.  .88 dP    ${NC}\n"
    printf "${BLUE} 88888888P dP        88888P   88888P   8888P88 dP    dP   888P      888P  88888P      8888P88  88888P   88888P     88Y8888   8888P88 88    ${NC}\n"
    printf "${BLUE}                                           .88                                           .88                                     .88       ${NC}\n"
    printf "${BLUE}                                       d8888P                                        d8888P                                  d8888P        ${NC}\n"
    printf "${NC}\n"
    printf "\n"

    printf "${ASH_GRAY} ███╗   ███╗██████╗        ███╗   ███╗███████╗██╗  ██╗ █████╗ ██╗   ██╗███████╗██╗          █████╗ ███╗   ██╗██╗██╗  ██╗                 ${NC}\n"           
    printf "${ASH_GRAY} ████╗ ████║██╔══██╗       ████╗ ████║██╔════╝██║ ██╔╝██╔══██╗╚██╗ ██╔╝██╔════╝██║         ██╔══██╗████╗  ██║██║██║ ██╔╝                 ${NC}\n"            
    printf "${ASH_GRAY} ██╔████╔██║██║  ██║       ██╔████╔██║█████╗  █████╔╝ ███████║ ╚████╔╝ █████╗  ██║         ███████║██╔██╗ ██║██║█████╔╝                  ${NC}\n"             
    printf "${ASH_GRAY} ██║╚██╔╝██║██║  ██║       ██║╚██╔╝██║██╔══╝  ██╔═██╗ ██╔══██║  ╚██╔╝  ██╔══╝  ██║         ██╔══██║██║╚██╗██║██║██╔═██╗                  ${NC}\n"              
    printf "${ASH_GRAY} ██║ ╚═╝ ██║██████╔╝██╗    ██║ ╚═╝ ██║███████╗██║  ██╗██║  ██║   ██║   ███████╗███████╗    ██║  ██║██║ ╚████║██║██║  ██╗                 ${NC}\n"               
    printf "${ASH_GRAY} ╚═╝     ╚═╝╚═════╝ ╚═╝    ╚═╝     ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚══════╝╚══════╝    ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝                 ${NC}\n"  
    printf "\n"
}

# Print system information
print_info() {
    local variant="${VLLM_CPU_VARIANT:-unknown}"
    # Get vLLM version - use stored version file first, fallback to runtime import
    local vllm_version
    if [ -f /vllm/vllm_version.txt ]; then
        vllm_version=$(cat /vllm/vllm_version.txt)
    else
        vllm_version=$(python -c 'import vllm; print(vllm.__version__)' 2>/dev/null || echo "unknown")
    fi
    local python_version=$(python --version 2>&1 | cut -d' ' -f2)
    local container_ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "N/A")
    local host="${VLLM_SERVER_HOST:-0.0.0.0}"
    local port="${VLLM_SERVER_PORT:-8000}"

    printf "${GRAY}══════════════════════════════════════════════════════════════════════════════${NC}\n"
    printf "${BLUE}  vLLM CPU Inference Engine${NC}\n"
    printf "${GRAY}══════════════════════════════════════════════════════════════════════════════${NC}\n"
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
    printf "${GRAY}══════════════════════════════════════════════════════════════════════════════${NC}\n"
    printf "${GRAY}  GitHub: https://github.com/MekayelAnik/vllm-cpu${NC}\n"
    printf "${GRAY}  Docs:   https://docs.vllm.ai/en/stable/getting_started/installation/cpu/${NC}\n"
    printf "${GRAY}══════════════════════════════════════════════════════════════════════════════${NC}\n"
    printf "\n"
}

# Main execution
main() {
    print_banner
    print_info
}

main
