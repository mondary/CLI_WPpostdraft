#!/bin/bash

# WordPress XML-RPC Draft Poster Script V2
# Enhanced version with improved credential handling
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

# Export function for setting defaults
export_defaults() {
    cat << 'EOF'
# WordPress XML-RPC Default Configuration V2
# Add these lines to your ~/.bashrc or ~/.zshrc to set defaults:

export WP_DEFAULT_USERNAME="your_username_here"
export WP_DEFAULT_PASSWORD="your_password_here"
export WP_USER_AGENT="WordPress XML-RPC Client/2.0 (mondary.design)"

# Then reload your shell: source ~/.bashrc or source ~/.zshrc
EOF
}

# Function to display usage
show_usage() {
    echo -e "${BLUE}WordPress Draft Poster V2${NC}"
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
    echo -e "${YELLOW}V2 Improvements:${NC}"
    echo "• Auto-detection of config files (mondary.conf, mysite.conf, etc.)"
    echo "• Better credential handling in interactive mode"
    echo "• Preserved authentication when using existing configs"
    echo "• Enhanced error reporting"
    echo "• **Rich text formatting support**"
    echo ""
    echo -e "${YELLOW}Rich Text Formatting:${NC}"
    echo "• **Bold text**: **text** or __text__"
    echo "• *Italic text*: *text* or _text_"
    echo "• \`Inline code\`: \`code\`"
    echo "• Code blocks: \`\`\`language...\`\`\`"
    echo "• Bullet points: - item or * item"
    echo "• Separators: --- or ==="
    echo ""
    echo -e "${YELLOW}Demo Usage with Echo (Automated):${NC}"
    echo 'echo -e "My Post Title\\nmy-post-slug\\nhttps://example.com/image.jpg\\nFirst paragraph content.\\n\\nSecond paragraph with more details.\\n\\nThird paragraph continuing the story.\\n\\nFourth paragraph conclusion.\\nEND" | ./wp_post_draft_v2.sh --auto'
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

# Function to setup/update configuration
setup_config() {
    local config_file="$1"
    
    echo -e "${BLUE}=== WordPress Configuration Setup V2 ===${NC}"
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
# WordPress XML-RPC Configuration V2
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

# Function to get user input for post creation
get_user_input() {
    echo -e "${BLUE}=== WordPress Draft Posting Tool V2 ===${NC}"
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
    echo -e "${YELLOW}Featured Image URL (optional, press Enter to skip):${NC}"
    read -p "Image URL: " IMAGE_URL
    
    # Validate image URL if provided
    if [ -n "$IMAGE_URL" ] && ! validate_url "$IMAGE_URL"; then
        echo -e "${RED}Warning: Invalid image URL format. Continuing without image.${NC}"
        IMAGE_URL=""
    fi
    
    echo ""
    echo -e "${YELLOW}Please enter your post content with formatting support.${NC}"
    echo -e "${BLUE}Formatting options:${NC}"
    echo -e "${BLUE}  **bold** or __bold__     -> Bold text${NC}"
    echo -e "${BLUE}  *italic* or _italic_     -> Italic text${NC}"
    echo -e "${BLUE}  \`code\`                  -> Inline code${NC}"
    echo -e "${BLUE}  \`\`\`code block\`\`\`        -> Code block${NC}"
    echo -e "${BLUE}  - bullet point          -> Bullet list${NC}"
    echo -e "${BLUE}  ---                     -> Horizontal separator${NC}"
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
    
    # Escape XML special characters properly
    title=$(echo "$title" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')
    content=$(echo -e "$content" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
    slug=$(echo "$slug" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')
    username=$(echo "$username" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')
    password=$(echo "$password" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')
    
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
                        <value><string>draft</string></value>
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
                    </member>
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
    echo -e "${GREEN}WordPress Draft Poster Script V2${NC}"
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
    
    # Get user input for post creation
    get_user_input
    
    echo ""
    echo -e "${YELLOW}Creating post...${NC}"
    
    # Create XML-RPC payload
    local payload=$(create_post_payload "$POST_TITLE" "$POST_CONTENT" "$POST_SLUG" "$WP_USERNAME" "$WP_PASSWORD")
    
    # Send request
    local response=$(send_xmlrpc_request "$payload")
    
    # Check for errors - simplified version
    if echo "$response" | grep -q "<name>faultCode</name>"; then
        local fault_code=$(echo "$response" | grep -o '<name>faultCode</name><value><int>[0-9]*</int></value>' | grep -o '[0-9]*')
        local fault_string=$(echo "$response" | grep -o '<name>faultString</name><value><string>.*</string></value>' | sed 's/<name>faultString<\/name><value><string>//; s/<\/string><\/value>//')
        
        echo -e "${RED}XML-RPC Error:${NC}"
        echo -e "${RED}Code: $fault_code${NC}"
        echo -e "${RED}Message: $fault_string${NC}"
        
        # V2 improvement: Better error suggestions
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
        echo -e "${GREEN}Draft post created successfully!${NC}"
        echo -e "${GREEN}Post ID: $post_id${NC}"
        echo -e "${GREEN}Edit URL: $BLOG_URL/wp-admin/post.php?post=$post_id&action=edit${NC}"
        
        echo ""
        echo -e "${BLUE}Summary:${NC}"
        echo -e "${BLUE}--------${NC}"
        echo "Title: $POST_TITLE"
        echo "Slug: $POST_SLUG"
        echo "Status: Draft"
        if [ -n "$IMAGE_URL" ]; then
            echo "Featured Image: $IMAGE_URL"
        fi
        echo ""
        echo -e "${GREEN}Your draft is ready for review in WordPress admin!${NC}"
        
    else
        echo -e "${RED}Failed to create post${NC}"
        echo -e "${RED}Response: $response${NC}"
        exit 1
    fi
}

# Run main function
main "$@"