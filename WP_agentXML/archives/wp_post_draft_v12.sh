#!/bin/bash

# WordPress XML-RPC Draft Poster Script V3
# Enhanced version with advanced features and optimizations
# Usage: ./wp_post_draft_v2.sh
# This script posts drafts to https://mondary.design via XML-RPC

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BLOG_URL="https://mondary.design"
XMLRPC_URL="${BLOG_URL}/xmlrpc.php"

# Default values from environment variables
DEFAULT_WP_USERNAME="${WP_DEFAULT_USERNAME:-}"
DEFAULT_WP_PASSWORD="${WP_DEFAULT_PASSWORD:-}"
USER_AGENT="${WP_USER_AGENT:-WordPress XML-RPC Client/2.0}"

# Auto-detect config files
AUTO_CONFIG_FILES=("mondary.conf" "mysite.conf" "wordpress.conf" "wp.conf")

# V3 Command Line Options
CMD_TITLE=""
CMD_SLUG=""
CMD_EXCERPT=""
CMD_FEATURED=""
CMD_CONTENT=""
CMD_CONTENT_FILE=""
CMD_URL=""
CMD_PUBLISH=false
CMD_MODE=false

# Export function for setting defaults
export_defaults() {
    cat << 'EOF'
# WordPress XML-RPC Default Configuration V3
# Add these lines to your ~/.bashrc or ~/.zshrc to set defaults:

export WP_DEFAULT_USERNAME="your_username_here"
export WP_DEFAULT_PASSWORD="your_password_here"
export WP_USER_AGENT="WordPress XML-RPC Client/2.0 (mondary.design)"

# Then reload your shell: source ~/.bashrc or source ~/.zshrc
EOF
}

# Function to display usage
show_usage() {
    echo -e "${BLUE}WordPress Draft Poster V3${NC}"
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -i, --interactive   Interactive mode (default)"
    echo "  -c, --config FILE   Setup/update configuration file"
    echo "  -l, --load-config FILE  Load config and create post"
    echo "  -a, --auto          Auto-detect and use available config"
    echo "  -e, --export        Show environment variable setup"
    echo ""
    echo "Post Creation Options (V3 New):"
    echo "  --title TEXT        Post title"
    echo "  --slug TEXT         Post URL slug"
    echo "  --excerpt TEXT      Post excerpt for social media"
    echo "  --feat PATH|URL     Featured image (local file or URL)"
    echo "  --content TEXT      Post content (supports markdown)"
    echo "  --content-file FILE Read content from file"
    echo "  --url URL           Standalone image URL to include"
    echo "  --draft             Create as draft (default)"
    echo "  --publish           Publish immediately"
    echo ""
    echo "Environment Variables:"
    echo "  WP_DEFAULT_USERNAME   Default WordPress username"
    echo "  WP_DEFAULT_PASSWORD   Default WordPress password"
    echo "  WP_USER_AGENT         Custom user agent string"
    echo ""
    echo "Examples:"
    echo "  $0 --config mysite.conf     # Setup configuration only"
    echo "  $0 --load-config mysite.conf # Use config to create post"
    echo "  $0 --auto                   # Auto-detect config and create post"
    echo "  $0                          # Interactive mode with auto-config detection"
    echo ""
    echo "V3 Command Line Examples:"
    echo "  $0 --auto --title \"My Post\" --slug \"my-post\" --feat image.jpg --content \"Hello world\""
    echo "  $0 --auto --title \"News\" --content-file article.txt --excerpt \"Breaking news\""
    echo "  $0 --auto --title \"Gallery\" --url https://example.com/photo.jpg --publish"
    echo ""
    echo -e "${YELLOW}V3 Improvements:${NC}"
    echo "• Auto-detection of config files (mondary.conf, mysite.conf, etc.)"
    echo "• Better credential handling in interactive mode"
    echo "• Preserved authentication when using existing configs"
    echo "• Enhanced error reporting"
    echo "• **Rich text formatting support**"
    echo "• **NEW: Command line automation with --title, --feat, --content options**"
    echo "• **NEW: Batch processing with --content-file support**"
    echo "• **NEW: Direct publish mode with --publish option**"
    echo ""
    echo -e "${YELLOW}Rich Text Formatting:${NC}"
    echo "• **Bold text**: **text** or __text__"
    echo "• *Italic text*: *text* or _text_"
    echo "• Headers: ## H2, ### H3, #### H4, etc."
    echo "• \`Inline code\`: \`code\`"
    echo "• Code blocks: \`\`\`language...\`\`\`"
    echo "• Bullet points: - item or * item"
    echo "• Separators: --- or ==="
    echo "• **Inline images**: ![alt](image_url) or standalone image URL"
    echo "• **Featured image upload**: Local files or URLs supported"
    echo "• **Jetpack Social integration**: Excerpt → Social message, Featured image → Social media attachment"
    echo ""
    echo -e "${YELLOW}Demo Usage with Echo (Automated):${NC}"
    echo 'echo -e "My Post Title\\nmy-post-slug\\nhttps://example.com/image.jpg\\nFirst paragraph content.\\n\\nSecond paragraph with more details.\\n\\nThird paragraph continuing the story.\\n\\nFourth paragraph conclusion.\\nEND" | ./wp_post_draft_v3.sh --auto'
    echo ""
    echo -e "${YELLOW}Demo Usage Interactive:${NC}"
    echo "./wp_post_draft_v2.sh"
    echo "# Auto-detects config and prompts only for missing credentials"
}

# Function to check dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v curl >/dev/null 2>&1; then
        missing_deps+=("curl")
    fi
    
    if ! command -v base64 >/dev/null 2>&1; then
        missing_deps+=("base64")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo -e "${RED}Error: Missing required dependencies:${NC}"
        printf '%s\n' "${missing_deps[@]}"
        echo "Please install the missing dependencies and try again."
        exit 1
    fi
}

# Function to validate URL format
validate_url() {
    local url=$1
    if [[ $url =~ ^https?:// ]]; then
        return 0
    else
        return 1
    fi
}

# Function to test image URL before upload
test_image_url() {
    local image_url="$1"
    
    echo -e "${YELLOW}Testing image URL accessibility...${NC}"
    
    # Test if URL is accessible and get content info
    local response=$(curl -s -I -L --max-time 10 "$image_url")
    local http_code=$(echo "$response" | grep -i "^HTTP" | tail -1 | awk '{print $2}')
    local content_type=$(echo "$response" | grep -i "content-type:" | cut -d' ' -f2- | tr -d '\r')
    local content_length=$(echo "$response" | grep -i "content-length:" | cut -d' ' -f2 | tr -d '\r')
    
    echo -e "${BLUE}HTTP Status: $http_code${NC}"
    echo -e "${BLUE}Content Type: $content_type${NC}"
    echo -e "${BLUE}Content Length: $content_length bytes${NC}"
    
    # Check HTTP status
    if [ "$http_code" != "200" ]; then
        echo -e "${RED}Image URL not accessible (HTTP $http_code)${NC}"
        return 1
    fi
    
    # Check content type
    if [[ ! $content_type =~ image/ ]]; then
        echo -e "${YELLOW}Warning: Content type is not an image ($content_type)${NC}"
        echo -e "${YELLOW}Continuing anyway...${NC}"
    fi
    
    # Check file size (if available)
    if [ -n "$content_length" ] && [ "$content_length" -gt 5242880 ]; then
        echo -e "${RED}Image too large: $content_length bytes (max 5MB)${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Image URL validation passed${NC}"
    return 0
}

# Function to upload image file to WordPress and get media ID
upload_featured_image() {
    local image_path="$1"
    local username="$2"
    local password="$3"
    
    # Check if file exists
    if [ ! -f "$image_path" ]; then
        echo -e "${RED}Error: Image file not found: $image_path${NC}"
        return 1
    fi
    
    # Get file info
    local filename=$(basename "$image_path")
    local extension="${filename##*.}"
    local content_type=""
    
    # Determine content type based on extension
    case "$(echo "$extension" | tr '[:upper:]' '[:lower:]')" in
        jpg|jpeg) content_type="image/jpeg" ;;
        png) content_type="image/png" ;;
        gif) content_type="image/gif" ;;
        webp) content_type="image/webp" ;;
        avif) content_type="image/avif" ;;
        *) 
            echo -e "${RED}Unsupported image format: $extension${NC}"
            return 1
            ;;
    esac
    
    echo -e "${YELLOW}Uploading featured image: $filename${NC}"
    
    # Encode image to base64
    local image_data=$(base64 -i "$image_path")
    
    # Escape credentials for XML
    local username_escaped=$(echo "$username" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')
    local password_escaped=$(echo "$password" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')
    local filename_escaped=$(echo "$filename" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')
    
    # Create XML-RPC payload for media upload
    local upload_payload="<?xml version=\"1.0\"?>
<methodCall>
    <methodName>wp.uploadFile</methodName>
    <params>
        <param>
            <value><string>1</string></value>
        </param>
        <param>
            <value><string>$username_escaped</string></value>
        </param>
        <param>
            <value><string>$password_escaped</string></value>
        </param>
        <param>
            <value>
                <struct>
                    <member>
                        <name>name</name>
                        <value><string>$filename_escaped</string></value>
                    </member>
                    <member>
                        <name>type</name>
                        <value><string>$content_type</string></value>
                    </member>
                    <member>
                        <name>bits</name>
                        <value><base64>$image_data</base64></value>
                    </member>
                </struct>
            </value>
        </param>
    </params>
</methodCall>"
    
    # Send upload request
    local response=$(curl -s -X POST \
        -H "Content-Type: text/xml" \
        -H "User-Agent: $USER_AGENT" \
        -d "$upload_payload" \
        "$XMLRPC_URL")
    
    # Check for errors
    if echo "$response" | grep -q "<name>faultCode</name>"; then
        local fault_string=$(echo "$response" | grep -o '<name>faultString</name><value><string>.*</string></value>' | sed 's/<name>faultString<\/name><value><string>//; s/<\/string><\/value>//')
        echo -e "${RED}Image upload failed: $fault_string${NC}"
        return 1
    fi
    
    # Extract media ID from response
    local media_id=$(echo "$response" | grep -o '<name>id</name><value><string>[0-9]*</string></value>' | grep -o '[0-9]*')
    
    if [ -n "$media_id" ]; then
        echo -e "${GREEN}Featured image uploaded! Media ID: $media_id${NC}"
        echo "$media_id"
        return 0
    else
        echo -e "${RED}Failed to extract media ID from response${NC}"
        echo -e "${RED}Response: $response${NC}"
        return 1
    fi
}

# Function to securely read password
read_password() {
    local prompt=$1
    local password
    echo -n "$prompt"
    read -s password
    echo
    echo "$password"
}

# Function to auto-detect config file
auto_detect_config() {
    for config_file in "${AUTO_CONFIG_FILES[@]}"; do
        if [ -f "$config_file" ]; then
            echo -e "${GREEN}Auto-detected config file: $config_file${NC}"
            load_config "$config_file"
            return 0
        fi
    done
    
    echo -e "${YELLOW}No config file auto-detected. Using interactive mode.${NC}"
    return 1
}

# Function to read content from file
read_content_file() {
    local file_path="$1"
    
    if [ ! -f "$file_path" ]; then
        echo -e "${RED}Error: Content file not found: $file_path${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Reading content from: $file_path${NC}"
    
    # Read the entire file content
    local content=$(cat "$file_path")
    
    # Process the content through the same formatting pipeline
    local processed_content=""
    local paragraph_count=0
    local in_code_block=false
    local in_list=false
    local current_list=""
    
    while IFS= read -r line; do
        # Handle empty lines
        if [ -z "$line" ]; then
            # Close any open list
            if [ "$in_list" = true ]; then
                processed_content+="$current_list</ul>\n\n"
                in_list=false
                current_list=""
            fi
            continue
        fi
        
        # Process the line for special formatting
        formatted_content=$(format_content_block "$line")
        format_result=$?
        
        # Check if we're starting/ending a code block
        if [[ "$line" =~ ^\`\`\` ]]; then
            if [ "$in_code_block" = false ]; then
                in_code_block=true
                # Close any open list
                if [ "$in_list" = true ]; then
                    processed_content+="$current_list</ul>\n"
                    in_list=false
                    current_list=""
                fi
                processed_content+="$formatted_content\n"
            else
                in_code_block=false
                processed_content+="$formatted_content\n\n"
            fi
            continue
        fi
        
        # If we're in a code block, just add the line as-is
        if [ "$in_code_block" = true ]; then
            processed_content+="$line\n"
            continue
        fi
        
        # Handle bullet points
        if [ $format_result -eq 0 ] && [[ "$formatted_content" =~ ^\<li\> ]]; then
            if [ "$in_list" = false ]; then
                in_list=true
                current_list="<ul>\n"
            fi
            current_list+="$formatted_content\n"
            continue
        fi
        
        # Close list if we were in one
        if [ "$in_list" = true ]; then
            processed_content+="$current_list</ul>\n\n"
            in_list=false
            current_list=""
        fi
        
        # Handle separators
        if [[ "$formatted_content" =~ ^\<hr ]]; then
            processed_content+="$formatted_content\n\n"
            continue
        fi
        
        # Handle standalone images
        if [[ "$formatted_content" =~ ^\<figure\ class=\"wp-block-image ]]; then
            processed_content+="$formatted_content\n\n"
            continue
        fi
        
        # Handle headers (don't wrap in <p> tags)
        if [[ "$formatted_content" =~ ^\<h[1-6]\> ]]; then
            processed_content+="$formatted_content\n\n"
            continue
        fi
        
        # Regular paragraph
        if [ -n "$formatted_content" ]; then
            if [ $paragraph_count -gt 0 ]; then
                processed_content+="\n\n"
            fi
            processed_content+="<p>$formatted_content</p>"
            ((paragraph_count++))
        fi
    done < "$file_path"
    
    # Close any remaining open list
    if [ "$in_list" = true ]; then
        processed_content+="$current_list</ul>"
    fi
    
    echo "$processed_content"
}

# Function to setup/update configuration
setup_config() {
    local config_file="$1"
    
    echo -e "${BLUE}=== WordPress Configuration Setup V3 ===${NC}"
    echo -e "${YELLOW}This will save your WordPress credentials for future use.${NC}"
    echo ""
    
    # Get WordPress credentials
    read -p "WordPress Username: " config_username
    echo -n "WordPress Password: "
    read -s config_password
    echo  # Add newline after hidden input
    
    # Get optional settings
    echo ""
    echo -e "${YELLOW}Optional settings (press Enter for defaults):${NC}"
    read -p "Blog URL [https://mondary.design]: " config_blog_url
    config_blog_url=${config_blog_url:-"https://mondary.design"}
    
    read -p "User Agent [WordPress XML-RPC Client/2.0 (mondary.design)]: " config_user_agent
    config_user_agent=${config_user_agent:-"WordPress XML-RPC Client/2.0 (mondary.design)"}
    
    # Create config file
    cat > "$config_file" << EOF
# WordPress XML-RPC Configuration V3
# Generated on $(date)

# WordPress Credentials
WP_USERNAME="$config_username"
WP_PASSWORD="$config_password"

# Blog Settings
BLOG_URL="$config_blog_url"
XMLRPC_URL="\${BLOG_URL}/xmlrpc.php"

# Client Settings
USER_AGENT="$config_user_agent"

# Post Defaults
DEFAULT_POST_STATUS="draft"
DEFAULT_POST_TYPE="post"

# Image Settings
IMAGE_MAX_SIZE="2048x2048"
ALLOWED_IMAGE_TYPES="jpg,jpeg,png,gif,webp"
EOF
    
    echo ""
    echo -e "${GREEN}Configuration saved to: $config_file${NC}"
    echo -e "${GREEN}You can now use: $0 --auto (auto-detect) or $0 --load-config $config_file${NC}"
    echo ""
    echo -e "${YELLOW}Security note: This file contains your password in plain text.${NC}"
    echo -e "${YELLOW}Consider setting file permissions: chmod 600 $config_file${NC}"
    
    # Set secure permissions
    chmod 600 "$config_file" 2>/dev/null || true
    
    echo ""
    echo -e "${BLUE}Configuration complete!${NC}"
}

# Function to load configuration from file
load_config() {
    local config_file="$1"
    
    if [ ! -f "$config_file" ]; then
        echo -e "${RED}Error: Configuration file '$config_file' not found${NC}"
        echo -e "${YELLOW}Use: $0 --config $config_file to create it${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Loading configuration from: $config_file${NC}"
    
    # Source the config file
    source "$config_file"
    
    # Set the credentials directly
    WP_USERNAME="$WP_USERNAME"
    WP_PASSWORD="$WP_PASSWORD"
    
    if [ -n "$BLOG_URL" ]; then
        XMLRPC_URL="${BLOG_URL}/xmlrpc.php"
    fi
    
    echo -e "${GREEN}Configuration loaded successfully${NC}"
    echo -e "${GREEN}Blog: $BLOG_URL${NC}"
    echo -e "${GREEN}User: $WP_USERNAME${NC}"
    
    # Mark as loaded
    CONFIG_LOADED=true
}

# Function to process rich text formatting
process_formatting() {
    local text="$1"
    
    # Process inline images first (before other formatting)
    # Markdown style: ![alt](url) -> WordPress figure block
    text=$(echo "$text" | sed 's/!\[\([^]]*\)\](\([^)]*\))/<figure class="wp-block-image size-large"><img src="\2" alt="\1" class="wp-image-auto"\/>\<\/figure>/g')
    
    # Process headers (must be done before other formatting)
    # H6: ###### text -> <h6>text</h6>
    text=$(echo "$text" | sed 's/^###### \(.*\)$/<h6>\1<\/h6>/')
    # H5: ##### text -> <h5>text</h5>
    text=$(echo "$text" | sed 's/^##### \(.*\)$/<h5>\1<\/h5>/')
    # H4: #### text -> <h4>text</h4>
    text=$(echo "$text" | sed 's/^#### \(.*\)$/<h4>\1<\/h4>/')
    # H3: ### text -> <h3>text</h3>
    text=$(echo "$text" | sed 's/^### \(.*\)$/<h3>\1<\/h3>/')
    # H2: ## text -> <h2>text</h2>
    text=$(echo "$text" | sed 's/^## \(.*\)$/<h2>\1<\/h2>/')
    # H1: # text -> <h1>text</h1>
    text=$(echo "$text" | sed 's/^# \(.*\)$/<h1>\1<\/h1>/')
    
    # Convert markdown-style formatting to HTML
    # Bold: **text** or __text__ -> <strong>text</strong>
    text=$(echo "$text" | sed 's/\*\*\([^*]*\)\*\*/<strong>\1<\/strong>/g')
    text=$(echo "$text" | sed 's/__\([^_]*\)__/<strong>\1<\/strong>/g')
    
    # Italic: *text* or _text_ -> <em>text</em>
    text=$(echo "$text" | sed 's/\*\([^*]*\)\*/<em>\1<\/em>/g')
    text=$(echo "$text" | sed 's/_\([^_]*\)_/<em>\1<\/em>/g')
    
    # Code: `text` -> <code>text</code>
    text=$(echo "$text" | sed 's/`\([^`]*\)`/<code>\1<\/code>/g')
    
    # Bullet points: - text or * text -> <li>text</li>
    # This will be handled in the paragraph processing
    
    echo "$text"
}

# Function to detect and format special content blocks
format_content_block() {
    local line="$1"
    
    # Check for headers (should not be wrapped in <p> tags)
    if [[ "$line" =~ ^#{1,6}[[:space:]] ]]; then
        local formatted_line=$(process_formatting "$line")
        echo "$formatted_line"
        return 0
    fi
    
    # Check for standalone image URLs (line contains only a URL to an image)
    if [[ "$line" =~ ^https?://.*\.(jpg|jpeg|png|gif|webp|avif)$ ]]; then
        echo "<figure class=\"wp-block-image size-large\"><img src=\"$line\" alt=\"\" class=\"wp-image-auto\"/></figure>"
        return 0
    fi
    
    # Check for separators
    if [[ "$line" =~ ^---+$ ]] || [[ "$line" =~ ^===+$ ]]; then
        echo "<hr />"
        return 0
    fi
    
    # Check for code blocks
    if [[ "$line" =~ ^\`\`\`(.*)$ ]]; then
        local lang="${BASH_REMATCH[1]}"
        if [ -n "$lang" ]; then
            echo "<pre><code class=\"language-$lang\">"
        else
            echo "<pre><code>"
        fi
        return 0
    fi
    
    if [[ "$line" =~ ^\`\`\`$ ]]; then
        echo "</code></pre>"
        return 0
    fi
    
    # Check for bullet points
    if [[ "$line" =~ ^[[:space:]]*[-*][[:space:]]+(.*)$ ]]; then
        local bullet_text="${BASH_REMATCH[1]}"
        bullet_text=$(process_formatting "$bullet_text")
        echo "<li>$bullet_text</li>"
        return 0
    fi
    
    # Regular text with formatting
    local formatted_line=$(process_formatting "$line")
    echo "$formatted_line"
    return 1
}

# Function to handle command line mode input
get_cmdline_input() {
    echo -e "${BLUE}=== WordPress Draft Posting Tool V3 (Command Line Mode) ===${NC}"
    echo -e "${YELLOW}Processing command line arguments...${NC}"
    echo ""
    
    # Handle WordPress credentials
    if [ "$CONFIG_LOADED" != "true" ]; then
        if ! auto_detect_config; then
            echo -e "${RED}Error: No configuration found. Use --config to create one first.${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}Using configured credentials for: $WP_USERNAME${NC}"
    fi
    
    # Validate required parameters
    if [ -z "$CMD_TITLE" ]; then
        echo -e "${RED}Error: --title is required in command line mode${NC}"
        exit 1
    fi
    
    if [ -z "$CMD_CONTENT" ] && [ -z "$CMD_CONTENT_FILE" ]; then
        echo -e "${RED}Error: Either --content or --content-file is required${NC}"
        exit 1
    fi
    
    # Set post values from command line
    POST_TITLE="$CMD_TITLE"
    
    # Generate slug from title if not provided
    if [ -n "$CMD_SLUG" ]; then
        POST_SLUG="$CMD_SLUG"
    else
        # Auto-generate slug from title
        POST_SLUG=$(echo "$POST_TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g')
        echo -e "${YELLOW}Auto-generated slug: $POST_SLUG${NC}"
    fi
    
    POST_EXCERPT="$CMD_EXCERPT"
    
    # Handle content
    if [ -n "$CMD_CONTENT_FILE" ]; then
        echo -e "${YELLOW}Reading content from file: $CMD_CONTENT_FILE${NC}"
        POST_CONTENT=$(read_content_file "$CMD_CONTENT_FILE")
    else
        echo -e "${YELLOW}Processing inline content...${NC}"
        # Process inline content through formatting
        POST_CONTENT=$(echo -e "$CMD_CONTENT" | while IFS= read -r line; do
            if [ -n "$line" ]; then
                formatted_content=$(format_content_block "$line")
                echo "<p>$formatted_content</p>"
            fi
        done)
    fi
    
    # Add URL image if provided
    if [ -n "$CMD_URL" ]; then
        if validate_url "$CMD_URL"; then
            POST_CONTENT+="\n\n<figure class=\"wp-block-image size-large\"><img src=\"$CMD_URL\" alt=\"\" class=\"wp-image-auto\"/></figure>"
            echo -e "${GREEN}Added image URL to content: $CMD_URL${NC}"
        else
            echo -e "${RED}Invalid URL provided: $CMD_URL${NC}"
            exit 1
        fi
    fi
    
    # Initialize featured image variables
    FEATURED_IMAGE_ID=""
    IMAGE_URL=""
    
    # Process featured image if provided
    if [ -n "$CMD_FEATURED" ]; then
        if validate_url "$CMD_FEATURED"; then
            # It's a URL
            IMAGE_URL="$CMD_FEATURED"
            echo -e "${GREEN}Featured image URL set: $IMAGE_URL${NC}"
            echo -e "${YELLOW}⚠️  NEXT STEP: After creating the post, go to WordPress admin and SAVE the post${NC}"
            echo -e "${YELLOW}   to trigger WPCode snippet that will download and set the featured image.${NC}"
        elif [ -f "$CMD_FEATURED" ]; then
            # It's a local file
            echo -e "${YELLOW}Uploading local featured image...${NC}"
            FEATURED_IMAGE_ID=$(upload_featured_image "$CMD_FEATURED" "$WP_USERNAME" "$WP_PASSWORD")
            if [ $? -eq 0 ] && [ -n "$FEATURED_IMAGE_ID" ]; then
                echo -e "${GREEN}Featured image uploaded successfully! Media ID: $FEATURED_IMAGE_ID${NC}"
            else
                echo -e "${RED}Failed to upload featured image. Continuing without it.${NC}"
                FEATURED_IMAGE_ID=""
            fi
        else
            echo -e "${RED}Invalid featured image: Not a valid URL or file path: $CMD_FEATURED${NC}"
            exit 1
        fi
    fi
    
    echo ""
    echo -e "${GREEN}Command line input processed successfully!${NC}"
    echo -e "${BLUE}Title: $POST_TITLE${NC}"
    echo -e "${BLUE}Slug: $POST_SLUG${NC}"
    if [ -n "$POST_EXCERPT" ]; then
        echo -e "${BLUE}Excerpt: $POST_EXCERPT${NC}"
    fi
    if [ -n "$IMAGE_URL" ]; then
        echo -e "${BLUE}Featured Image URL: $IMAGE_URL${NC}"
    fi
    if [ -n "$FEATURED_IMAGE_ID" ]; then
        echo -e "${BLUE}Featured Image ID: $FEATURED_IMAGE_ID${NC}"
    fi
    echo ""
}

# Function to get user input for post creation
get_user_input() {
    echo -e "${BLUE}=== WordPress Draft Posting Tool V3 ===${NC}"
    echo -e "${YELLOW}Please provide the following information:${NC}"
    echo ""
    
    # Handle WordPress credentials intelligently
    if [ "$CONFIG_LOADED" != "true" ]; then
        # Try auto-detection first if not explicitly loaded
        if ! auto_detect_config; then
            # No config found, ask for credentials
            if [ -n "$DEFAULT_WP_USERNAME" ]; then
                read -p "WordPress Username [$DEFAULT_WP_USERNAME]: " WP_USERNAME
                WP_USERNAME=${WP_USERNAME:-$DEFAULT_WP_USERNAME}
            else
                read -p "WordPress Username: " WP_USERNAME
            fi
            
            if [ -n "$DEFAULT_WP_PASSWORD" ] && [ -n "$WP_USERNAME" ] && [ "$WP_USERNAME" = "$DEFAULT_WP_USERNAME" ]; then
                echo "Using saved password for $WP_USERNAME"
                WP_PASSWORD="$DEFAULT_WP_PASSWORD"
            else
                WP_PASSWORD=$(read_password "WordPress Password: ")
            fi
        fi
    else
        echo -e "${GREEN}Using configured credentials for: $WP_USERNAME${NC}"
    fi
    
    echo ""
    
    # Get post details
    read -p "Post Title: " POST_TITLE
    
    echo ""
    echo -e "${YELLOW}Post URL (slug - will be used for permalink):${NC}"
    read -p "URL Slug: " POST_SLUG
    
    echo ""
    echo -e "${YELLOW}Post Excerpt (optional, press Enter to skip):${NC}"
    echo -e "${BLUE}  • Brief summary of your post content${NC}"
    echo -e "${BLUE}  • Used for post previews and SEO${NC}"
    read -p "Excerpt: " POST_EXCERPT
    
    echo ""
    echo -e "${YELLOW}Featured Image (optional, press Enter to skip):${NC}"
    echo -e "${BLUE}  • Enter a local file path (e.g., /path/to/image.jpg)${NC}"
    echo -e "${BLUE}  • Or enter an image URL (e.g., https://site.com/image.jpg)${NC}"
    echo -e "${GREEN}  ⚠️  IMPORTANT: For URL images, you MUST install WPCode plugin in WordPress${NC}"
    echo -e "${GREEN}  ⚠️  and add the snippet from wpcode_featured_image.php${NC}"
    read -p "Featured Image: " FEATURED_IMAGE
    
    # Initialize featured image variables
    FEATURED_IMAGE_ID=""
    IMAGE_URL=""
    
    # Process featured image if provided
    if [ -n "$FEATURED_IMAGE" ]; then
        if validate_url "$FEATURED_IMAGE"; then
            # It's a URL, store it for later use (existing behavior)
            IMAGE_URL="$FEATURED_IMAGE"
            echo -e "${GREEN}Featured image URL set: $IMAGE_URL${NC}"
            echo -e "${YELLOW}⚠️  NEXT STEP: After creating the post, go to WordPress admin and SAVE the post${NC}"
            echo -e "${YELLOW}   to trigger WPCode snippet that will download and set the featured image.${NC}"
        elif [ -f "$FEATURED_IMAGE" ]; then
            # It's a local file, upload it
            echo -e "${YELLOW}Uploading local featured image...${NC}"
            FEATURED_IMAGE_ID=$(upload_featured_image "$FEATURED_IMAGE" "$WP_USERNAME" "$WP_PASSWORD")
            if [ $? -eq 0 ] && [ -n "$FEATURED_IMAGE_ID" ]; then
                echo -e "${GREEN}Featured image uploaded successfully! Media ID: $FEATURED_IMAGE_ID${NC}"
            else
                echo -e "${RED}Failed to upload featured image. Continuing without it.${NC}"
                FEATURED_IMAGE_ID=""
            fi
        else
            echo -e "${RED}Invalid featured image: Not a valid URL or file path${NC}"
            echo -e "${YELLOW}Continuing without featured image...${NC}"
        fi
    fi
    
    echo ""
    echo -e "${YELLOW}Please enter your post content with formatting support.${NC}"
    echo -e "${BLUE}Formatting options:${NC}"
    echo -e "${BLUE}  ## Header 2 or ### Header 3 -> HTML headers${NC}"
    echo -e "${BLUE}  **bold** or __bold__     -> Bold text${NC}"
    echo -e "${BLUE}  *italic* or _italic_     -> Italic text${NC}"
    echo -e "${BLUE}  \`code\`                  -> Inline code${NC}"
    echo -e "${BLUE}  \`\`\`code block\`\`\`        -> Code block${NC}"
    echo -e "${BLUE}  - bullet point          -> Bullet list${NC}"
    echo -e "${BLUE}  ---                     -> Horizontal separator${NC}"
    echo -e "${BLUE}  ![alt](image_url)       -> Inline image with alt text${NC}"
    echo -e "${BLUE}  https://site.com/img.jpg -> Standalone image${NC}"
    echo -e "${YELLOW}Type 'END' on a new line when finished:${NC}"
    echo ""
    
    POST_CONTENT=""
    paragraph_count=0
    in_code_block=false
    in_list=false
    current_list=""
    
    while IFS= read -r line; do
        if [ "$line" = "END" ]; then
            break
        fi
        
        # Handle empty lines
        if [ -z "$line" ]; then
            # Close any open list
            if [ "$in_list" = true ]; then
                POST_CONTENT+="$current_list</ul>\n\n"
                in_list=false
                current_list=""
            fi
            continue
        fi
        
        # Process the line for special formatting
        formatted_content=$(format_content_block "$line")
        format_result=$?
        
        # Check if we're starting/ending a code block
        if [[ "$line" =~ ^\`\`\` ]]; then
            if [ "$in_code_block" = false ]; then
                in_code_block=true
                # Close any open list
                if [ "$in_list" = true ]; then
                    POST_CONTENT+="$current_list</ul>\n"
                    in_list=false
                    current_list=""
                fi
                POST_CONTENT+="$formatted_content\n"
            else
                in_code_block=false
                POST_CONTENT+="$formatted_content\n\n"
            fi
            continue
        fi
        
        # If we're in a code block, just add the line as-is
        if [ "$in_code_block" = true ]; then
            POST_CONTENT+="$line\n"
            continue
        fi
        
        # Handle bullet points
        if [ $format_result -eq 0 ] && [[ "$formatted_content" =~ ^\<li\> ]]; then
            if [ "$in_list" = false ]; then
                in_list=true
                current_list="<ul>\n"
            fi
            current_list+="$formatted_content\n"
            continue
        fi
        
        # Close list if we were in one
        if [ "$in_list" = true ]; then
            POST_CONTENT+="$current_list</ul>\n\n"
            in_list=false
            current_list=""
        fi
        
        # Handle separators
        if [[ "$formatted_content" =~ ^\<hr ]]; then
            POST_CONTENT+="$formatted_content\n\n"
            continue
        fi
        
        # Handle standalone images
        if [[ "$formatted_content" =~ ^\<figure\ class=\"wp-block-image ]]; then
            POST_CONTENT+="$formatted_content\n\n"
            continue
        fi
        
        # Handle headers (don't wrap in <p> tags)
        if [[ "$formatted_content" =~ ^\<h[1-6]\> ]]; then
            POST_CONTENT+="$formatted_content\n\n"
            continue
        fi
        
        # Regular paragraph
        if [ -n "$formatted_content" ]; then
            if [ $paragraph_count -gt 0 ]; then
                POST_CONTENT+="\n\n"
            fi
            POST_CONTENT+="<p>$formatted_content</p>"
            ((paragraph_count++))
        fi
    done
    
    # Close any remaining open list
    if [ "$in_list" = true ]; then
        POST_CONTENT+="$current_list</ul>"
    fi
    
    if [ $paragraph_count -lt 4 ]; then
        echo -e "${YELLOW}Note: You entered $paragraph_count paragraphs. Consider adding more content for better SEO.${NC}"
    fi
}

# Function to create XML-RPC payload for new post
create_post_payload() {
    local title="$1"
    local content="$2"
    local slug="$3"
    local username="$4"
    local password="$5"
    local featured_image_id="$6"
    local featured_image_url="$7"
    local excerpt="$8"
    local post_status="${9:-draft}"  # V3: Allow custom status
    
    # Escape XML special characters properly
    title=$(echo "$title" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')
    content=$(echo -e "$content" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
    slug=$(echo "$slug" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')
    username=$(echo "$username" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')
    password=$(echo "$password" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')
    
    if [ -n "$featured_image_url" ]; then
        featured_image_url=$(echo "$featured_image_url" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')
    fi
    
    if [ -n "$excerpt" ]; then
        excerpt=$(echo "$excerpt" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')
    fi
    
    cat << EOF
<?xml version="1.0"?>
<methodCall>
    <methodName>wp.newPost</methodName>
    <params>
        <param>
            <value><string>1</string></value>
        </param>
        <param>
            <value><string>$username</string></value>
        </param>
        <param>
            <value><string>$password</string></value>
        </param>
        <param>
            <value>
                <struct>
                    <member>
                        <name>post_type</name>
                        <value><string>post</string></value>
                    </member>
                    <member>
                        <name>post_status</name>
                        <value><string>$post_status</string></value>
                    </member>
                    <member>
                        <name>post_title</name>
                        <value><string>$title</string></value>
                    </member>
                    <member>
                        <name>post_content</name>
                        <value><string>$content</string></value>
                    </member>
                    <member>
                        <name>post_name</name>
                        <value><string>$slug</string></value>
                    </member>$([ -n "$excerpt" ] && echo "
                    <member>
                        <name>post_excerpt</name>
                        <value><string>$excerpt</string></value>
                    </member>")$([ -n "$featured_image_id" ] && echo "
                    <member>
                        <name>wp_post_thumbnail</name>
                        <value><string>$featured_image_id</string></value>
                    </member>")
                    $(if [ -n "$featured_image_url" ] || [ -n "$excerpt" ]; then echo "
                    <member>
                        <name>custom_fields</name>
                        <value>
                            <array>
                                <data>
                                    <value>
                                        <struct>
                                            <member>
                                                <name>key</name>
                                                <value><string>auto_schedule</string></value>
                                            </member>
                                            <member>
                                                <name>value</name>
                                                <value><string>1</string></value>
                                            </member>
                                        </struct>
                                    </value>"; fi)$([ -n "$featured_image_url" ] && echo "
                                    <value>
                                        <struct>
                                            <member>
                                                <name>key</name>
                                                <value><string>featured_image_url</string></value>
                                            </member>
                                            <member>
                                                <name>value</name>
                                                <value><string>$featured_image_url</string></value>
                                            </member>
                                        </struct>
                                    </value>")$([ -n "$excerpt" ] && echo "
                                    <value>
                                        <struct>
                                            <member>
                                                <name>key</name>
                                                <value><string>_wpas_mess</string></value>
                                            </member>
                                            <member>
                                                <name>value</name>
                                                <value><string>$excerpt</string></value>
                                            </member>
                                        </struct>
                                    </value>")$(if [ -n "$featured_image_url" ] || [ -n "$excerpt" ]; then echo "
                                </data>
                            </array>
                        </value>
                    </member>"; else echo "
                    <member>
                        <name>custom_fields</name>
                        <value>
                            <array>
                                <data>
                                    <value>
                                        <struct>
                                            <member>
                                                <name>key</name>
                                                <value><string>auto_schedule</string></value>
                                            </member>
                                            <member>
                                                <name>value</name>
                                                <value><string>1</string></value>
                                            </member>
                                        </struct>
                                    </value>
                                </data>
                            </array>
                        </value>
                    </member>"; fi)
                </struct>
            </value>
        </param>
    </params>
</methodCall>
EOF
}

# Function to send XML-RPC request
send_xmlrpc_request() {
    local payload="$1"
    
    echo -e "${YELLOW}Sending request to WordPress...${NC}"
    
    local response=$(curl -s -X POST \
        -H "Content-Type: text/xml" \
        -H "User-Agent: $USER_AGENT" \
        -d "$payload" \
        "$XMLRPC_URL")
    
    echo "$response"
}

# Function to parse post ID from response
extract_post_id() {
    local response="$1"
    echo "$response" | grep -o '<string>[0-9]*</string>' | head -1 | grep -o '[0-9]*'
}

# Main function
main() {
    echo -e "${GREEN}WordPress Draft Poster Script V3${NC}"
    echo -e "${GREEN}===================================${NC}"
    echo ""
    
    # Check dependencies
    check_dependencies
    
    local CONFIG_MODE=false
    local LOAD_CONFIG_MODE=false
    local AUTO_MODE=false
    local CONFIG_FILE=""
    CONFIG_LOADED=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -e|--export)
                export_defaults
                exit 0
                ;;
            -i|--interactive)
                INTERACTIVE_MODE=true
                shift
                ;;
            -c|--config)
                CONFIG_MODE=true
                CONFIG_FILE="$2"
                if [ -z "$CONFIG_FILE" ]; then
                    echo -e "${RED}Error: --config requires a filename${NC}"
                    show_usage
                    exit 1
                fi
                shift 2
                ;;
            -l|--load-config)
                LOAD_CONFIG_MODE=true
                CONFIG_FILE="$2"
                if [ -z "$CONFIG_FILE" ]; then
                    echo -e "${RED}Error: --load-config requires a filename${NC}"
                    show_usage
                    exit 1
                fi
                shift 2
                ;;
            -a|--auto)
                AUTO_MODE=true
                shift
                ;;
            --title)
                CMD_TITLE="$2"
                CMD_MODE=true
                if [ -z "$CMD_TITLE" ]; then
                    echo -e "${RED}Error: --title requires a value${NC}"
                    exit 1
                fi
                shift 2
                ;;
            --slug)
                CMD_SLUG="$2"
                CMD_MODE=true
                if [ -z "$CMD_SLUG" ]; then
                    echo -e "${RED}Error: --slug requires a value${NC}"
                    exit 1
                fi
                shift 2
                ;;
            --excerpt)
                CMD_EXCERPT="$2"
                CMD_MODE=true
                if [ -z "$CMD_EXCERPT" ]; then
                    echo -e "${RED}Error: --excerpt requires a value${NC}"
                    exit 1
                fi
                shift 2
                ;;
            --feat)
                CMD_FEATURED="$2"
                CMD_MODE=true
                if [ -z "$CMD_FEATURED" ]; then
                    echo -e "${RED}Error: --feat requires a path or URL${NC}"
                    exit 1
                fi
                shift 2
                ;;
            --content)
                CMD_CONTENT="$2"
                CMD_MODE=true
                if [ -z "$CMD_CONTENT" ]; then
                    echo -e "${RED}Error: --content requires text${NC}"
                    exit 1
                fi
                shift 2
                ;;
            --content-file)
                CMD_CONTENT_FILE="$2"
                CMD_MODE=true
                if [ -z "$CMD_CONTENT_FILE" ]; then
                    echo -e "${RED}Error: --content-file requires a filename${NC}"
                    exit 1
                fi
                shift 2
                ;;
            --url)
                CMD_URL="$2"
                CMD_MODE=true
                if [ -z "$CMD_URL" ]; then
                    echo -e "${RED}Error: --url requires a URL${NC}"
                    exit 1
                fi
                shift 2
                ;;
            --draft)
                CMD_PUBLISH=false
                CMD_MODE=true
                shift
                ;;
            --publish)
                CMD_PUBLISH=true
                CMD_MODE=true
                shift
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Handle config setup mode
    if [ "$CONFIG_MODE" = true ]; then
        setup_config "$CONFIG_FILE"
        exit 0
    fi
    
    # Handle load config mode
    if [ "$LOAD_CONFIG_MODE" = true ]; then
        load_config "$CONFIG_FILE"
        echo ""
    fi
    
    # Handle auto mode
    if [ "$AUTO_MODE" = true ]; then
        auto_detect_config
        echo ""
    fi
    
    # Determine input mode and get post data
    if [ "$CMD_MODE" = true ]; then
        # Command line mode
        get_cmdline_input
    else
        # Interactive mode
        get_user_input
    fi
    
    echo ""
    echo -e "${YELLOW}Creating post...${NC}"
    
    # Determine post status
    local post_status="draft"
    if [ "$CMD_PUBLISH" = true ]; then
        post_status="publish"
        echo -e "${YELLOW}Publishing post immediately...${NC}"
    else
        echo -e "${YELLOW}Creating as draft...${NC}"
    fi
    
    # Create XML-RPC payload
    local payload=$(create_post_payload "$POST_TITLE" "$POST_CONTENT" "$POST_SLUG" "$WP_USERNAME" "$WP_PASSWORD" "$FEATURED_IMAGE_ID" "$IMAGE_URL" "$POST_EXCERPT" "$post_status")
    
    # Send request
    local response=$(send_xmlrpc_request "$payload")
    
    # Check for errors - simplified version
    if echo "$response" | grep -q "<name>faultCode</name>"; then
        local fault_code=$(echo "$response" | grep -o '<name>faultCode</name><value><int>[0-9]*</int></value>' | grep -o '[0-9]*')
        local fault_string=$(echo "$response" | grep -o '<name>faultString</name><value><string>.*</string></value>' | sed 's/<name>faultString<\/name><value><string>//; s/<\/string><\/value>//')
        
        echo -e "${RED}XML-RPC Error:${NC}"
        echo -e "${RED}Code: $fault_code${NC}"
        echo -e "${RED}Message: $fault_string${NC}"
        
        # V3 improvement: Better error suggestions
        case "$fault_code" in
            "403")
                echo -e "${YELLOW}Suggestion: Check username/password or try: $0 --config mysite.conf${NC}"
                ;;
            "401")
                echo -e "${YELLOW}Suggestion: Invalid credentials. Try: $0 --config mysite.conf${NC}"
                ;;
        esac
        exit 1
    fi
    
    # Extract post ID
    local post_id=$(extract_post_id "$response")
    
    if [ -n "$post_id" ]; then
        if [ "$post_status" = "publish" ]; then
            echo -e "${GREEN}Post published successfully!${NC}"
            echo -e "${GREEN}Post ID: $post_id${NC}"
            echo -e "${GREEN}View URL: $BLOG_URL/?p=$post_id${NC}"
            echo -e "${GREEN}Edit URL: $BLOG_URL/wp-admin/post.php?post=$post_id&action=edit${NC}"
        else
            echo -e "${GREEN}Draft post created successfully!${NC}"
            echo -e "${GREEN}Post ID: $post_id${NC}"
            echo -e "${GREEN}Edit URL: $BLOG_URL/wp-admin/post.php?post=$post_id&action=edit${NC}"
        fi
        
        echo ""
        echo -e "${BLUE}Summary:${NC}"
        echo -e "${BLUE}--------${NC}"
        echo "Title: $POST_TITLE"
        echo "Slug: $POST_SLUG"
        if [ -n "$POST_EXCERPT" ]; then
            echo "Excerpt: $POST_EXCERPT"
        fi
        echo "Status: $(echo $post_status | tr '[:lower:]' '[:upper:]')"
        if [ -n "$IMAGE_URL" ]; then
            echo "Featured Image URL: $IMAGE_URL"
            echo -e "${YELLOW}⚠️  REQUIRED ACTION: Go to WordPress admin and SAVE the post to activate featured image${NC}"
        fi
        if [ -n "$FEATURED_IMAGE_ID" ]; then
            echo "Featured Image ID: $FEATURED_IMAGE_ID (uploaded)"
        fi
        
        # Jetpack Social integration info
        if [ -n "$POST_EXCERPT" ]; then
            echo ""
            echo -e "${YELLOW}🔗 Jetpack Social Integration:${NC}"
            echo "• Social Message: \"$POST_EXCERPT\""
            if [ -n "$IMAGE_URL" ] || [ -n "$FEATURED_IMAGE_ID" ]; then
                echo "• Social Media Attachment: Featured image will be used"
            fi
        fi
        echo ""
        if [ "$post_status" = "publish" ]; then
            echo -e "${GREEN}Your post is now live and published!${NC}"
        else
            echo -e "${GREEN}Your draft is ready for review in WordPress admin!${NC}"
        fi
        
        # Add specific instructions for featured images
        if [ -n "$IMAGE_URL" ]; then
            echo ""
            echo -e "${YELLOW}📝 FEATURED IMAGE SETUP REQUIRED:${NC}"
            echo -e "${YELLOW}1. Install WPCode plugin in WordPress (if not already done)${NC}"
            echo -e "${YELLOW}2. Add the PHP snippet from wpcode_featured_image.php${NC}"
            echo -e "${YELLOW}3. Go to the post edit page and click 'Update' to trigger image download${NC}"
            echo -e "${YELLOW}4. Featured image will then appear in the sidebar and be ready for use${NC}"
        fi
        
    else
        echo -e "${RED}Failed to create post${NC}"
        echo -e "${RED}Response: $response${NC}"
        exit 1
    fi
}

# Run main function
main "$@"