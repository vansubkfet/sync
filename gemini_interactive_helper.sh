#!/bin/bash

# Gemini Interactive Helper - Setup and Configuration
# Source this file in your ~/.bashrc or ~/.zshrc

# Installation instructions will be printed when you run this script

GLINES_DIR="${HOME}/.glines"
TEMP_DIR="${TMPDIR:-/tmp}/glines"

# Create directories
mkdir -p "$GLINES_DIR"
mkdir -p "$TEMP_DIR"

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function: Extract and prepare file lines for Gemini
glines() {
    local file="$1"
    local selection="$2"
    shift 2  # Remove first two arguments
    local prompt="$*"  # Everything else is the prompt
    local output="${TEMP_DIR}/gemini_selection_$(date +%s).txt"
    
    if [[ -z "$file" || -z "$selection" ]]; then
        echo "Usage: glines <file> <selection> [prompt]"
        echo "       glines <@file> <selection> [prompt]"
        echo "Examples:"
        echo "  glines file.py 10-20"
        echo "  glines @file.py 10-20"
        echo "  glines file.py /def/"
        echo "  glines @file.py 1,5,10"
        echo "  glines file.py 10-20 explain this code"
        echo "  glines @file.py 10-20 explain this code"
        return 1
    fi
    
    # Strip @ prefix if present
    if [[ "$file" == @* ]]; then
        file="${file:1}"
    fi
    
    # Check if file exists
    if [[ ! -f "$file" ]]; then
        echo -e "${YELLOW}Error: File not found: $file${NC}"
        return 1
    fi
    
    # Extract based on selection type
    if [[ "$selection" =~ ^[0-9]+-[0-9]+$ ]]; then
        sed -n "${selection//-/,}p" "$file" > "$output"
    elif [[ "$selection" =~ ^[0-9]+$ ]]; then
        sed -n "${selection}p" "$file" > "$output"
    elif [[ "$selection" =~ ^/ ]]; then
        local pattern="${selection:1:-1}"
        grep "$pattern" "$file" > "$output"
    elif [[ "$selection" =~ ^-[0-9]+$ ]]; then
        tail -n "${selection:1}" "$file" > "$output"
    else
        echo "Invalid selection format"
        return 1
    fi
    
    if [[ ! -s "$output" ]]; then
        echo -e "${YELLOW}Warning: No lines extracted${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ Extracted to: $output${NC}"
    
    # If prompt provided, send to Gemini automatically
    if [[ -n "$prompt" ]]; then
        if command -v gemini &> /dev/null; then
            echo -e "${BLUE}Sending to Gemini with prompt: \"$prompt\"${NC}"
            echo ""
            gemini "@$output" "$prompt"
        else
            echo -e "${YELLOW}Gemini CLI not found. Manual command:${NC}"
            echo "  gemini @$output $prompt"
        fi
    else
        echo -e "${BLUE}Use: @$output${NC}"
        echo "$output"
    fi
}

# Function: Quick copy to clipboard (works with pbcopy on macOS, xclip on Linux)
gclip() {
    local file="$1"
    local selection="$2"
    local output="${TEMP_DIR}/gemini_selection_$(date +%s).txt"
    
    # Strip @ prefix if present
    if [[ "$file" == @* ]]; then
        file="${file:1}"
    fi
    
    # Check if file exists
    if [[ ! -f "$file" ]]; then
        echo -e "${YELLOW}Error: File not found: $file${NC}"
        return 1
    fi
    
    # Extract lines
    if [[ "$selection" =~ ^[0-9]+-[0-9]+$ ]]; then
        sed -n "${selection//-/,}p" "$file" > "$output"
    elif [[ "$selection" =~ ^[0-9]+$ ]]; then
        sed -n "${selection}p" "$file" > "$output"
    elif [[ "$selection" =~ ^/ ]]; then
        local pattern="${selection:1:-1}"
        grep "$pattern" "$file" > "$output"
    elif [[ "$selection" =~ ^-[0-9]+$ ]]; then
        tail -n "${selection:1}" "$file" > "$output"
    else
        echo "Invalid selection format"
        return 1
    fi
    
    if [[ -f "$output" ]]; then
        if command -v pbcopy &> /dev/null; then
            cat "$output" | pbcopy
            echo -e "${GREEN}✓ Copied to clipboard${NC}"
        elif command -v xclip &> /dev/null; then
            cat "$output" | xclip -selection clipboard
            echo -e "${GREEN}✓ Copied to clipboard${NC}"
        else
            echo "Clipboard tool not found (pbcopy/xclip)"
            cat "$output"
        fi
    fi
}

# Function: Interactive line selector with preview
gselect() {
    local file="$1"
    
    # Strip @ prefix if present
    if [[ "$file" == @* ]]; then
        file="${file:1}"
    fi
    
    if [[ ! -f "$file" ]]; then
        echo "File not found: $file"
        return 1
    fi
    
    # Show file with line numbers
    echo -e "${YELLOW}File: $file${NC}"
    nl -ba "$file" | head -20
    echo "..."
    echo ""
    
    # Get user input
    read -p "Enter selection (e.g., 10-20, /pattern/, 1,5,10): " selection
    
    if [[ -n "$selection" ]]; then
        glines "$file" "$selection"
    fi
}

# Function: Save common file+selection combos
gsave() {
    local name="$1"
    local file="$2"
    local selection="$3"
    
    if [[ -z "$name" || -z "$file" || -z "$selection" ]]; then
        echo "Usage: gsave <name> <file> <selection>"
        return 1
    fi
    
    echo "$file|$selection" > "${GLINES_DIR}/${name}.gline"
    echo -e "${GREEN}✓ Saved as: $name${NC}"
    echo "Use: gload $name"
}

# Function: Load saved selection
gload() {
    local name="$1"
    local saved="${GLINES_DIR}/${name}.gline"
    
    if [[ ! -f "$saved" ]]; then
        echo "Saved selection not found: $name"
        echo "Available:"
        ls -1 "${GLINES_DIR}" | sed 's/.gline$//'
        return 1
    fi
    
    IFS='|' read -r file selection < "$saved"
    glines "$file" "$selection"
}

# Function: List saved selections
glist() {
    echo -e "${YELLOW}Saved selections:${NC}"
    for file in "${GLINES_DIR}"/*.gline; do
        if [[ -f "$file" ]]; then
            local name=$(basename "$file" .gline)
            local content=$(cat "$file")
            echo -e "  ${GREEN}$name${NC}: $content"
        fi
    done
}

# Function: Clean up old temp files
gclean() {
    local count=$(find "$TEMP_DIR" -name "gemini_selection_*.txt" -mtime +1 | wc -l)
    find "$TEMP_DIR" -name "gemini_selection_*.txt" -mtime +1 -delete
    echo -e "${GREEN}✓ Cleaned up $count old files${NC}"
}

# Setup aliases for common operations
alias gl='glines'
alias gs='gselect'
alias gc='gclip'

# Print help
ghelp() {
    cat << EOF
${GREEN}Gemini Line Selector - Interactive Helper${NC}

Functions:
  ${BLUE}glines <file> <selection>${NC}     Extract lines (alias: gl)
  ${BLUE}gselect <file>${NC}                Interactive selection (alias: gs)
  ${BLUE}gclip <file> <selection>${NC}      Extract and copy to clipboard (alias: gc)
  ${BLUE}gsave <name> <file> <sel>${NC}     Save a selection preset
  ${BLUE}gload <name>${NC}                  Load a saved preset
  ${BLUE}glist${NC}                         List all saved presets
  ${BLUE}gclean${NC}                        Clean up old temp files
  ${BLUE}ghelp${NC}                         Show this help

Selection Formats:
  10-20          Lines 10 to 20
  10             Line 10
  1,5,10         Lines 1, 5, and 10
  /pattern/      Lines matching pattern
  -10            Last 10 lines

Examples:
  gl myfile.py 10-50
  gs myfile.py
  gc myfile.py /def calculate/
  gsave myconfig config.yaml 10-30
  gload myconfig

EOF
}

# Show help on first run
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    cat << EOF
${GREEN}═══════════════════════════════════════════════════════════${NC}
${GREEN}Gemini Interactive Helper - Installation${NC}
${GREEN}═══════════════════════════════════════════════════════════${NC}

To install, add this to your ${YELLOW}~/.bashrc${NC} or ${YELLOW}~/.zshrc${NC}:

    ${BLUE}source $(realpath "$0")${NC}

Or run:
    ${BLUE}echo 'source $(realpath "$0")' >> ~/.bashrc${NC}

Then reload your shell:
    ${BLUE}source ~/.bashrc${NC}

After installation, run ${YELLOW}ghelp${NC} to see available commands.

${GREEN}═══════════════════════════════════════════════════════════${NC}
EOF
else
    # Quietly load when sourced
    true
fi
