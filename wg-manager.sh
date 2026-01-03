#!/bin/bash

# Ensure script runs as root
if [[ $EUID -ne 0 ]]; then
    echo "Error: Please run as root (sudo)."
    exit 1
fi

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

while true; do
    clear
    echo -e "--- ${GREEN}WireGuard${NC} Manager ---"

    mapfile -t CONFS < <(find /etc/wireguard -maxdepth 1 -name "*.conf" -printf "%f\n" | sed 's/\.conf$//')
    ACTIVE_IFS=$(wg show interfaces)

    if [[ ${#CONFS[@]} -eq 0 ]]; then
        echo "No configurations found in /etc/wireguard."
        exit 1
    fi

    echo "Select a configuration to manage:"
    for i in "${!CONFS[@]}"; do
        if echo "$ACTIVE_IFS" | grep -qw "${CONFS[$i]}"; then
            echo -e "$((i+1))) ${GREEN}[UP]${NC}   ${CONFS[$i]}"
        else
            echo -e "$((i+1))) ${RED}[DOWN]${NC} ${CONFS[$i]}"
        fi
    done
    echo -e "q) Quit"

    read -p "$(echo -e "\nSelection: ") " CONF_REPLY

    if [[ "$CONF_REPLY" == "q" ]]; then exit 0; fi
    
    if [[ "$CONF_REPLY" =~ ^[0-9]+$ ]] && [[ "$CONF_REPLY" -gt 0 && "$CONF_REPLY" -le ${#CONFS[@]} ]]; then
        CONF_NAME="${CONFS[$((CONF_REPLY-1))]}"
    else
        echo "Invalid selection. Press Enter..."
        read -r; continue
    fi

    while true; do
        clear
        ACTIVE_IFS=$(wg show interfaces)
        IS_UP=false
        if echo "$ACTIVE_IFS" | grep -qw "$CONF_NAME"; then IS_UP=true; fi

        echo -e "--- Managing: ${YELLOW}$CONF_NAME${NC} ---"
        echo -e "Status: $( [[ $IS_UP == true ]] && echo -e "${GREEN}ACTIVE${NC}" || echo -e "${RED}INACTIVE${NC}" )"
        echo "--------------------------------"
        
        # Build actions list
        ACTIONS=()
        [[ $IS_UP == true ]] && ACTIONS+=("Stop Interface") || ACTIONS+=("Start Interface")
        ACTIONS+=("View Config" "Edit Config")
        [[ $IS_UP == true ]] && ACTIONS+=("View Live Stats (Real-time)")
        ACTIONS+=("Back to Main Menu" "Quit")

        for i in "${!ACTIONS[@]}"; do
            echo "$((i+1))) ${ACTIONS[$i]}"
        done

        read -p "$(echo -e "\nChoose an action: ") " ACT_REPLY

        # Handle Action logic based on selection
        case $ACT_REPLY in
            1) # Toggle
                [[ $IS_UP == true ]] && wg-quick down "$CONF_NAME" || wg-quick up "$CONF_NAME"
                break 2
                ;;
            2) # View
                echo -e "\n${CYAN}--- $CONF_NAME.conf ---${NC}"
                cat "/etc/wireguard/$CONF_NAME.conf"
                echo ""
                read -p "Press Enter to return..."
                ;;
            3) # Edit
                nano "/etc/wireguard/$CONF_NAME.conf"
                ;;
            4) # Live Stats or Back
                if [[ $IS_UP == true ]]; then
                    while true; do
                        clear
                        echo -e "${GREEN}--- Live Statistics for $CONF_NAME ---${NC}"
                        wg show "$CONF_NAME"
                        echo -e "${GREEN}--------------------------------------${NC}"
                        echo "Press any key to exit live view..."
                        read -t 1 -n 1 && break
                        if ! wg show interfaces | grep -qw "$CONF_NAME"; then break; fi
                    done
                else
                    break 2
                fi
                ;;
            5) # Back or Quit
                if [[ $IS_UP == true ]]; then break 2; else exit 0; fi
                ;;
            6) # Quit
                exit 0
                ;;
            *)
                echo "Invalid selection."
                sleep 1
                ;;
        esac
    done
done
