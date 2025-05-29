#!/bin/bash

# Check if parameter is provided
if [ -z "$1" ]; then
    echo "Usage: $0 \"search parameter\""
    exit 1
fi

SEARCH_PARAM="$1"
RESULT_FILE="result.txt"
DEPTH_RESULT_FILE="depth-result.txt"
PROCESSED_FILE="depth-processed.txt"

# Create necessary files if they don't exist
touch "$PROCESSED_FILE"

# Initialize counters
TOTAL_URLS=0
MATCHES_FOUND=0

# Function to check if content contains search parameter
check_content() {
    local content="$1"
    local url="$2"
    
    # Skip if already processed
    if grep -q "^$url$" "$PROCESSED_FILE"; then
        echo "Skipping already processed URL: $url"
        return
    fi
    
    # Mark as processed
    echo "$url" >> "$PROCESSED_FILE"
    
    echo "Checking URL: $url"
    
    # Extract text content and remove HTML tags
    local text_content=$(echo "$content" | sed 's/<[^>]*>//g' | tr -d '\n\r' | sed 's/  */ /g')
    
    # Check for matches and show context
    if echo "$text_content" | grep -q "$SEARCH_PARAM"; then
        echo "✓ Found match in: $url"
        echo "Context of match:"
        echo "$text_content" | grep -o -i ".\{0,50\}$SEARCH_PARAM.\{0,50\}" | head -n 2
        echo "$url" >> "$DEPTH_RESULT_FILE"
        ((MATCHES_FOUND++))
    else
        echo "✗ No match found in: $url"
    fi
}

# Clear depth result file if it exists
> "$DEPTH_RESULT_FILE"

# Start scraping from URLs in result.txt
echo "Starting scrape with search parameter: '$SEARCH_PARAM'"
echo "Results will be saved to: $DEPTH_RESULT_FILE"
echo "----------------------------------------"

# Read URLs from result.txt and process them
while IFS= read -r url; do
    if [ -n "$url" ]; then
        ((TOTAL_URLS++))
        echo "Processing URL $TOTAL_URLS: $url"
        
        # Get page content
        echo "Fetching content..."
        content=$(curl -s -L "$url")
        
        # Check content
        check_content "$content" "$url"
    fi
done < "$RESULT_FILE"

echo -e "\n----------------------------------------"
echo "Scraping completed:"
echo "- Total URLs processed: $TOTAL_URLS"
echo "- Matches found: $MATCHES_FOUND"
echo "Results saved in $DEPTH_RESULT_FILE"
