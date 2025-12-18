#!/bin/bash
# Gemini Line Selector for Bash
# Save this as: glines.sh
# Make executable: chmod +x glines.sh
# Place in a directory in your PATH (e.g., ~/bin/ or /usr/local/bin/)

# Set temp directory for extracted files
TEMP_DIR="${TMPDIR:-/tmp}/glines"
mkdir -p "$TEMP_DIR"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Usage function
usage() {
    echo ""
    echo -e "${GREEN}Gemini Line Selector for Bash${NC}"
    echo ""
    echo "Usage: glines <file> <selection> [prompt]"
    echo "       glines <@file> <selection> [prompt]"
    echo ""
    echo "Selection Formats:"
    echo "  10-20          Lines 10 to 20"
    echo "  10             Line 10"
    echo "  1,5,10         Lines 1, 5, and 10"
    echo "  /pattern/      Lines matching pattern"
    echo "  -10            Last 10 lines"
    echo "  +10            First 10 lines"
    echo ""
    echo "Examples:"
    echo "  glines myfile.py 10-20"
    echo "  glines @myfile.py 10-20"
    echo "  glines myfile.py /def/"
    echo "  glines myfile.py 10-20 explain this code"
    echo "  glines @config.yaml 1-50 what are these settings"
    echo ""
    exit 0
}

# Check arguments
if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
fi

# Parse arguments
FILE="$1"
SELECTION="$2"
shift 2
PROMPT="$*"

# Strip @ prefix if present
FILE_CLEAN="$FILE"
if [[ "$FILE" == @* ]]; then
    FILE_CLEAN="${FILE:1}"
fi

# Check if file exists
if [ ! -f "$FILE_CLEAN" ]; then
    echo -e "${RED}Error: File not found: $FILE_CLEAN${NC}"
    exit 1
fi

# Generate unique output filename
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT="$TEMP_DIR/gemini_selection_${TIMESTAMP}.txt"

# Process selection based on format
range_selection() {
    # Extract lines X-Y
    IFS='-' read -r START END <<< "$SELECTION"
    sed -n "${START},${END}p" "$FILE_CLEAN" > "$OUTPUT"
}

single_line() {
    # Extract single line N
    sed -n "${SELECTION}p" "$FILE_CLEAN" > "$OUTPUT"
}

multiple_lines() {
    # Extract specific lines (e.g., 1,5,10)
    # Convert comma-separated to sed format: 1p;5p;10p
    LINES=$(echo "$SELECTION" | sed 's/,/p;/g')p
    sed -n "$LINES" "$FILE_CLEAN" > "$OUTPUT"
}

pattern_match() {
    # Extract lines matching pattern
    PATTERN="${SELECTION:1:${#SELECTION}-2}"
    grep -i "$PATTERN" "$FILE_CLEAN" > "$OUTPUT"
}

last_n_lines() {
    # Extract last N lines
    NUM="${SELECTION:1}"
    tail -n "$NUM" "$FILE_CLEAN" > "$OUTPUT"
}

first_n_lines() {
    # Extract first N lines
    NUM="${SELECTION:1}"
    head -n "$NUM" "$FILE_CLEAN" > "$OUTPUT"
}

check_output() {
    # Check if extraction was successful
    if [ ! -f "$OUTPUT" ]; then
        echo -e "${YELLOW}Warning: Extraction failed${NC}"
        exit 1
    fi

    # Check if file is empty
    if [ ! -s "$OUTPUT" ]; then
        echo -e "${YELLOW}Warning: No lines extracted${NC}"
        rm "$OUTPUT"
        exit 1
    fi

    echo -e "${GREEN}✓ Extracted to: $OUTPUT${NC}"

    # If prompt provided, show command to use with Claude
    if [ -n "$PROMPT" ]; then
        echo -e "${BLUE}To use with Claude:${NC}"
        echo "  claude -c $PROMPT in the file \"$OUTPUT\""
        echo ""
        echo -e "${YELLOW}Note: Auto-send requires Claude CLI installed${NC}"
    else
        echo -e "${BLUE}Use: @$OUTPUT${NC}"
        echo "$OUTPUT"
    fi

    exit 0
}

# Determine selection type and process
# Check for range (contains hyphen not at start)
if [[ "$SELECTION" == *-* ]] && [[ "$SELECTION" != -* ]]; then
    range_selection
    check_output
fi

# Check for pattern match (starts with /)
if [[ "$SELECTION" == /* ]]; then
    pattern_match
    check_output
fi

# Check for last N lines (starts with -)
if [[ "$SELECTION" == -* ]]; then
    last_n_lines
    check_output
fi

# Check for first N lines (starts with +)
if [[ "$SELECTION" == +* ]]; then
    first_n_lines
    check_output
fi

# Check for comma-separated lines
if [[ "$SELECTION" == *,* ]]; then
    multiple_lines
    check_output
fi

# Otherwise assume single line
single_line
check_output
