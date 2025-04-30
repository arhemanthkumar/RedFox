#!/bin/bash

clear

# ===== Colors =====
RED='\033[1;38;5;196m'
ORANGE='\033[38;5;208m'
GREEN='\033[1;38;5;46m'
YELLOW='\033[1;38;5;226m'
BLUE='\033[1;38;5;33m'
NC='\033[0m' # No Color


# Print BIG RedFox Banner
if command -v toilet >/dev/null 2>&1; then
    echo -e "${RED}"
    toilet -f big -F metal "RedFox"
     echo -e "${NC}"
elif command -v figlet >/dev/null 2>&1; then
    echo -e "${RED}"
    figlet -f big "RedFox"
    echo -e "${NC}"
else
    echo -e "${RED}==== RedFox ====${NC}"
fi


# 2. Show your Name and Email in a fancy way

echo -e "${GREEN}=========================================${NC}"
echo -e "${NC}  Created by: Hemanth Kumar A. R.${NC}"
echo -e "${NC}  Email     : hemanthkumar.ar@gnani.ai${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""

echo -e "${ORANGE} Welcome to RedFox Deployment Tool.${NC}"

sleep 1

# ===== Start location =====
BASE_DIR="/mnt/c/Users/HemanthKumar/OneDrive - Gnani Innovations/Desktop"
CURRENT_DIR="$BASE_DIR"
DIR_STACK=()  # Stack for directory navigation


# ===== Helper Functions =====

# Colored echo
cecho() {
  echo -e "${1}${2}${NC}"
}


# List folders and files with color and fixed-width formatting
list_folders() {
    echo ""
    DISPLAY_DIR="${CURRENT_DIR//\// -> }"
    DISPLAY_DIR="${DISPLAY_DIR# -> }"
    cecho $BLUE "Contents inside: $DISPLAY_DIR"
    echo ""

    local line_width=90
    printf "%s\n" "$(printf "%${line_width}s" | tr ' ' '-')"
    printf "%-6s %-50s %-12s %-25s\n" "Type" "Name" "Size" "Created Date"
    printf "%s\n" "$(printf "%${line_width}s" | tr ' ' '-')"

    item_list=$(find "$1" -mindepth 1 -maxdepth 1 | sort)
    total_size=0
    folder_count=0
    file_count=0

    while IFS= read -r item; do
        name=$(basename "$item")
        cdate=$(stat --format='%y' "$item" 2>/dev/null | cut -d'.' -f1)

        if [ -d "$item" ]; then
            type="DIR"
            size=$(du -sh "$item" 2>/dev/null | cut -f1)
            folder_count=$((folder_count + 1))
            size_bytes=$(du -sb "$item" 2>/dev/null | cut -f1)

            # Entire line in blue for folders
            printf "${BLUE}%-6s %-50s %-12s %-25s${NC}\n" "$type" "$name" "$size" "$cdate"
        else
            type="FILE"
            size=$(du -h "$item" 2>/dev/null | cut -f1)
            file_count=$((file_count + 1))
            size_bytes=$(stat --format='%s' "$item" 2>/dev/null)

            # Normal color for files
            printf "%-6s %-50s %-12s %-25s\n" "$type" "$name" "$size" "$cdate"
        fi

        total_size=$((total_size + size_bytes))
    done <<< "$item_list"

    printf "%s\n" "$(printf "%${line_width}s" | tr ' ' '-')"
    echo ""
    cecho $GREEN "Total Folder(s): $folder_count"
    cecho $GREEN "Total File(s)  : $file_count"

    total_size_hr=$(numfmt --to=iec-i --suffix=B $total_size 2>/dev/null)
    cecho $GREEN "Total Size     : ${total_size_hr:-N/A}"
    echo ""
}


# Search folders by partial inputs
search_folder() {
    # Ask for keyword
    keyword=$(gum input --placeholder "Enter part of the folder name to search") || return

    # Check if keyword is empty
    if [ -z "$keyword" ]; then
        cecho $RED "No keyword entered. Returning to menu."
        return
    fi

    # Find matching folders
    mapfile -t matches < <(find "$BASE_DIR" -type d -iname "*$keyword*" 2>/dev/null)

    # Check if anything found
    if [ ${#matches[@]} -eq 0 ]; then
        cecho $RED "No matching folders found!"
        return
    fi

    # Show selection with gum
    selected=$(printf "%s\n" "${matches[@]}" | gum choose --height=15)

    # If user selected something valid
    if [ -n "$selected" ] && [ -d "$selected" ]; then
        folder_menu "$selected"
    else
        cecho $RED "No valid selection made."
    fi
}




# List docker files
list_docker_files() {
    echo ""
    cecho $BLUE "Docker-related files in $1:"
    find "$1" \( -name "Dockerfile" -o -name "docker-compose.yml" \) 2>/dev/null || echo "None found."
}

# Create Dockerfile (safe mode)
create_dockerfile() {
    TARGET_DIR=$1
    if [ -f "$TARGET_DIR/Dockerfile" ]; then
        cecho $YELLOW "Dockerfile already exists!"
        read -p "Overwrite it? (y/n): " overwrite
        if [[ "$overwrite" != "y" ]]; then
            cecho $GREEN "Aborted creating new Dockerfile."
            return
        fi
    fi

    cecho $GREEN "Creating a basic Dockerfile at $TARGET_DIR..."
    cat <<EOL > "$TARGET_DIR/Dockerfile"
# Basic Dockerfile
FROM ubuntu:20.04
RUN apt-get update && apt-get install -y curl
CMD ["/bin/bash"]
EOL
    cecho $GREEN "Dockerfile created successfully."
}

# Redeploy
redeploy() {
    TARGET_DIR=$1
    if [ -f "$TARGET_DIR/redeploy.sh" ]; then
        cecho $GREEN "Running redeploy.sh in $TARGET_DIR..."
        (cd "$TARGET_DIR" && bash redeploy.sh | tee /dev/tty)
    else
        cecho $RED "redeploy.sh not found in $TARGET_DIR!"
    fi
}

# Auto-discover and list all redeploy.sh
discover_redeploys() {
    echo ""
    cecho $YELLOW "Discovering all redeploy.sh files under $BASE_DIR..."
    list=$(find "$BASE_DIR" -name "redeploy.sh")
    if [ -z "$list" ]; then
        cecho $RED "No redeploy.sh files found!"
        return
    fi
 
    echo ""
    count=1
    declare -A redeploy_map

    while read -r line; do
        echo "$count. $line"
        redeploy_map[$count]=$line
        ((count++))
    done <<< "$list"

    read -p "Enter number to run redeploy.sh (0 to cancel): " num
    if [[ "$num" == "0" ]]; then
        cecho $YELLOW "Cancelled."
        return
    fi

    if [[ -n "${redeploy_map[$num]}" ]]; then
        cecho $GREEN "Running ${redeploy_map[$num]}"
        (cd "$(dirname "${redeploy_map[$num]}")" && bash redeploy.sh | tee /dev/tty)
    else
        cecho $RED "Invalid choice."
    fi
}


# Folder operation menu
folder_menu() {
    CURRENT_DIR="$1"
    DIR_STACK=("$CURRENT_DIR")  # Reset stack for new navigation

    while true; do
        echo ""
	DISPLAY_DIR="${CURRENT_DIR//\// -> }"
	DISPLAY_DIR="${DISPLAY_DIR# -> }"
        cecho $BLUE "===== Inside: $DISPLAY_DIR ====="
        echo "1. List Docker Files"
        echo "2. Create New Dockerfile"
        echo "3. Run redeploy.sh"
        echo "4. Go Into Subfolder"
        echo "9. Back to Previous Directory"
        echo "0. Main Menu"
        echo "00. Exit"
        read -p "Enter your choice [1-4,9,0,00]: " choice

        case $choice in
            1)
                list_docker_files "$CURRENT_DIR"
                ;;
            2)
                create_dockerfile "$CURRENT_DIR"
                ;;
            3)
                redeploy "$CURRENT_DIR"
                ;;
            4)
                list_folders "$CURRENT_DIR"
                read -p "Enter subfolder name to go into: " subfolder
                NEW_DIR="$CURRENT_DIR/$subfolder"
                if [ -d "$NEW_DIR" ]; then
                    DIR_STACK+=("$CURRENT_DIR")  # Push current dir
                    CURRENT_DIR="$NEW_DIR"        # Move into new dir
                else
                    cecho $RED "Subfolder not found!"
                fi
                ;;
            9)
	        
    		if [ "$CURRENT_DIR" = "$BASE_DIR" ]; then
        	    cecho $YELLOW "Already at the root base directory. Returning to main menu."
        	    break
    		elif [ ${#DIR_STACK[@]} -gt 0 ]; then
        	    CURRENT_DIR="${DIR_STACK[-1]}"
        	    unset 'DIR_STACK[-1]'
        	    if [ ${#DIR_STACK[@]} -eq 0 ]; then
            	        # After popping, stack is empty => we are at BASE_DIR now
            	        CURRENT_DIR="$BASE_DIR"
            	        cecho $YELLOW "Already at the root base directory after going back. Returning to main menu."
            	        break
        	    fi
    		else
        	    CURRENT_DIR="$BASE_DIR"
        	    cecho $YELLOW "Already at the root level (stack empty). Returning to main menu."
        	    break
    		fi
    		;;


            0)
                cecho $YELLOW "Returning to main menu..."
                return
                ;;
            00)
                cecho $GREEN "Goodbye!"
                echo ""
                exit 0
                ;;
            *)
                cecho $RED "Invalid option. Try again."
                ;;
        esac
    done
}

# Main menu
main_menu() {
    while true; do
        echo ""	
        cecho $BLUE "===== Main Menu ====="
	DISPLAY_DIR="${CURRENT_DIR//\// -> }"
	DISPLAY_DIR="${DISPLAY_DIR# -> }"
        cecho $CYAN "Current Base Directory: $DISPLAY_DIR"
        echo ""
        echo "1. List Folders"
        echo "2. Search Folder by Name"
        echo "3. Discover and Run Any redeploy.sh"
        echo "00. Exit"
        read -p "Enter your choice [1-3,00]: " main_choice

        case $main_choice in
            1)
                list_folders "$BASE_DIR"
                read -p "Enter folder name to enter: " foldername
                TARGET="$BASE_DIR/$foldername"
                if [ -d "$TARGET" ]; then
                    folder_menu "$TARGET"
                else
                    cecho $RED "Folder not found! Try again."
                fi
                ;;
            2)
		echo "DEBUG: search_folder running..."
                search_folder
                ;;
            3)
                discover_redeploys
                ;;
            00)
                cecho $GREEN "Goodbye!"
                echo ""
                exit 0
                ;;
            *)
                cecho $RED "Invalid option. Try again."
                ;;
        esac
    done
}


# Start
main_menu
