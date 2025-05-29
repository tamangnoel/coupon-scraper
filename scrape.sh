#!/bin/bash

# Check if parameters are provided
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <search_parameter1> <search_parameter2>"
    exit 1
fi

SEARCH_PARAM1="$1"
SEARCH_PARAM2="$2"
MAIN_URL="https://coupons-greatclips.com/"
RESULT_FILE="result.txt"
VISITED_FILE="visited.txt"
PROCESSED_OFFERS_FILE="processed_offers.txt"
IGNORE_FILE="ignore.txt"
SKIP_FILE="skip.txt"

# Create necessary files if they don't exist
touch "$VISITED_FILE"
touch "$PROCESSED_OFFERS_FILE"
touch "$IGNORE_FILE"
touch "$SKIP_FILE"

# Initialize counters
TOTAL_LINKS=0
UNIQUE_LINKS=0
MATCHES_FOUND=0
SKIPPED_LINKS=0

# Function to check if URL should be ignored
should_ignore_url() {
    local url="$1"
    while IFS= read -r ignore_pattern; do
        if [[ -n "$ignore_pattern" && "$url" == *"$ignore_pattern"* ]]; then
            echo "$url" >> "$SKIP_FILE"
            ((SKIPPED_LINKS++))
            return 0
        fi
    done < "$IGNORE_FILE"
    return 1
}

# Function to extract links from HTML content
extract_links() {
    local html_content="$1"
    local base_url="$2"
    echo "$html_content" | grep -o 'href="[^"]*"' | sed 's/href="//g' | sed 's/"//g' | while read -r link; do
        # Convert relative URLs to absolute
        if [[ $link == /* ]]; then
            echo "${base_url%/}/$link"
        elif [[ $link == http* ]]; then
            echo "$link"
        else
            echo "${base_url%/}/$link"
        fi
    done | sort -u
}

# Function to check if content contains search parameters
check_content() {
    local content="$1"
    local url="$2"
    
    # Skip if already processed
    if grep -q "^$url$" "$PROCESSED_OFFERS_FILE"; then
        echo "Skipping already processed offer: $url"
        return
    fi
    
    # Mark as processed
    echo "$url" >> "$PROCESSED_OFFERS_FILE"
    
    echo "Checking offer URL: $url"
    
    # Extract text content and remove HTML tags
    local text_content=$(echo "$content" | sed 's/<[^>]*>//g' | tr -d '\n\r' | sed 's/  */ /g')
    
    # Check for matches and show context
    local has_param1=$(echo "$text_content" | grep -q "$SEARCH_PARAM1" && echo "yes" || echo "no")
    local has_param2=$(echo "$text_content" | grep -q "$SEARCH_PARAM2" && echo "yes" || echo "no")
    
    if [ "$has_param1" = "yes" ] || [ "$has_param2" = "yes" ]; then
        echo "✓ Found match in: $url"
        echo "Context of matches:"
        if [ "$has_param1" = "yes" ]; then
            echo "Parameter 1 ($SEARCH_PARAM1):"
            echo "$text_content" | grep -o -i ".\{0,50\}$SEARCH_PARAM1.\{0,50\}" | head -n 2
        fi
        if [ "$has_param2" = "yes" ]; then
            echo "Parameter 2 ($SEARCH_PARAM2):"
            echo "$text_content" | grep -o -i ".\{0,50\}$SEARCH_PARAM2.\{0,50\}" | head -n 2
        fi
        echo "$url" >> "$RESULT_FILE"
        ((MATCHES_FOUND++))
    else
        echo "✗ No match found in: $url"
    fi
}

# Function to scrape links recursively
scrape_links() {
    local url="$1"
    local depth="$2"
    
    # Skip if already visited or max depth reached
    if [ "$depth" -gt 3 ] || grep -q "^$url$" "$VISITED_FILE"; then
        return
    fi
    
    # Check if URL should be ignored
    if should_ignore_url "$url"; then
        echo "Skipping ignored URL: $url"
        return
    fi
    
    # Mark URL as visited
    echo "$url" >> "$VISITED_FILE"
    ((UNIQUE_LINKS++))
    
    # Show progress
    echo -e "\n[Depth $depth] Checking URL: $url (Link $UNIQUE_LINKS)"
    
    # Get page content
    echo "Fetching content..."
    content=$(curl -s -L "$url")
    
    # Extract and process links
    echo "Extracting links..."
    local links=$(extract_links "$content" "$url")
    local link_count=$(echo "$links" | wc -l)
    ((TOTAL_LINKS+=link_count))
    
    echo "Found $link_count links on this page"
    
    echo "$links" | while read -r link; do
        # Check if link should be ignored
        if should_ignore_url "$link"; then
            continue
        fi
        
        if [[ $link == *"offers.greatclips.com"* ]]; then
            # Check content for search parameter
            offer_content=$(curl -s -L "$link")
            check_content "$offer_content" "$link"
        elif [[ $link == *"coupons-greatclips.com"* ]]; then
            # Recursively scrape next level
            scrape_links "$link" $((depth + 1))
        fi
    done
}

# Start scraping from main URL
echo "Starting scrape with search parameters: '$SEARCH_PARAM1' or '$SEARCH_PARAM2'"
echo "Results will be saved to: $RESULT_FILE"
echo "----------------------------------------"
scrape_links "$MAIN_URL" 1

echo -e "\n----------------------------------------"
echo "Scraping completed:"
echo "- Total links found: $TOTAL_LINKS"
echo "- Unique pages visited: $UNIQUE_LINKS"
echo "- Matches found: $MATCHES_FOUND"
echo "- Links skipped: $SKIPPED_LINKS"
echo "Results saved in $RESULT_FILE"
echo "Skipped URLs saved in $SKIP_FILE"
