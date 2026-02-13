#!/bin/bash

# WordPress XML-RPC Draft Poster Script
# Usage: ./wp_post_draft.sh
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
USER_AGENT="${WP_USER_AGENT:-WordPress XML-RPC Client/1.0}"

# Export function for setting defaults
export_defaults() {
    cat << 'EOF'
# WordPress XML-RPC Default Configuration
# Add these lines to your ~/.bashrc or ~/.zshrc to set defaults:

export WP_DEFAULT_USERNAME="your_username_here"
export WP_DEFAULT_PASSWORD="your_password_here"
export WP_USER_AGENT="WordPress XML-RPC Client/1.0 (mondary.design)"

# Then reload your shell: source ~/.bashrc or source ~/.zshrc
EOF
}

# Function to display usage
show_usage() {
    echo -e "${BLUE}WordPress Draft Poster${NC}"
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -i, --interactive   Interactive mode (default)"
    echo "  -c, --config FILE   Setup/update configuration file"
    echo "  -l, --load-config FILE  Load config and create post"
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
    echo "  $0                           # Interactive mode"
    echo ""
    echo -e "${YELLOW}Demo Usage with Echo (Automated):${NC}"
    echo 'echo -e "My Post Title\nmy-post-slug\nhttps://example.com/image.jpg\nFirst paragraph content.\n\nSecond paragraph with more details.\n\nThird paragraph continuing the story.\n\nFourth paragraph conclusion.\nEND" | ./wp_post_draft.sh --load-config mysite.conf'
    echo ""
    echo -e "${YELLOW}Demo Usage Interactive:${NC}"
    echo "./wp_post_draft.sh --load-config mysite.conf"
    echo "# Then follow the prompts for title, slug, image URL, and content"
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

# Function to setup/update configuration
setup_config() {
    local config_file="$1"
    
    echo -e "${BLUE}=== WordPress Configuration Setup ===${NC}"
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
    
    read -p "User Agent [WordPress XML-RPC Client/1.0 (mondary.design)]: " config_user_agent
    config_user_agent=${config_user_agent:-"WordPress XML-RPC Client/1.0 (mondary.design)"}
    
    # Create config file
    cat > "$config_file" << EOF
# WordPress XML-RPC Configuration
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
    echo -e "${GREEN}You can now use: $0 --load-config $config_file${NC}"
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
    
    # Override defaults with config values
    if [ -n "$WP_USERNAME" ]; then
        DEFAULT_WP_USERNAME="$WP_USERNAME"
        DEFAULT_WP_PASSWORD="$WP_PASSWORD"
    fi
    
    if [ -n "$BLOG_URL" ]; then
        XMLRPC_URL="${BLOG_URL}/xmlrpc.php"
    fi
    
    echo -e "${GREEN}Configuration loaded successfully${NC}"
    echo -e "${GREEN}Blog: $BLOG_URL${NC}"
    echo -e "${GREEN}User: $WP_USERNAME${NC}"
}

# Function to get user input for post creation
get_user_input() {
    echo -e "${BLUE}=== WordPress Draft Posting Tool ===${NC}"
    echo -e "${YELLOW}Please provide the following information:${NC}"
    echo ""
    
    # Get WordPress credentials with defaults - only if not already set from config
    if [ -z "$WP_USERNAME" ]; then
        if [ -n "$DEFAULT_WP_USERNAME" ]; then
            read -p "WordPress Username [$DEFAULT_WP_USERNAME]: " WP_USERNAME
            WP_USERNAME=${WP_USERNAME:-$DEFAULT_WP_USERNAME}
        else
            read -p "WordPress Username: " WP_USERNAME
        fi
    else
        echo "Using configured username: $WP_USERNAME"
    fi
    
    if [ -z "$WP_PASSWORD" ]; then
        if [ -n "$DEFAULT_WP_PASSWORD" ] && [ -n "$WP_USERNAME" ] && [ "$WP_USERNAME" = "$DEFAULT_WP_USERNAME" ]; then
            echo "Using saved password for $WP_USERNAME"
            WP_PASSWORD="$DEFAULT_WP_PASSWORD"
        else
            WP_PASSWORD=$(read_password "WordPress Password: ")
        fi
    else
        echo "Using configured password for $WP_USERNAME"
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
    echo -e "${YELLOW}Please enter your post description (4-5 paragraphs).${NC}"
    echo -e "${YELLOW}Type 'END' on a new line when finished:${NC}"
    echo ""
    
    POST_CONTENT=""
    paragraph_count=0
    
    while IFS= read -r line; do
        if [ "$line" = "END" ]; then
            break
        fi
        
        # If line is not empty, treat it as a paragraph
        if [ -n "$line" ]; then
            if [ $paragraph_count -gt 0 ]; then
                POST_CONTENT+="\n\n"
            fi
            POST_CONTENT+="<p>$line</p>"
            ((paragraph_count++))
        fi
    done
    
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

# Function to upload image and get attachment ID
upload_image() {
    local image_url="$1"
    local username="$2"
    local password="$3"
    
    echo -e "${YELLOW}Downloading and uploading featured image...${NC}"
    echo -e "${BLUE}Image URL: $image_url${NC}"
    
    # Download image
    local temp_image="/tmp/wp_image_$(date +%s)"
    if ! curl -s -L --max-filesize 5000000 "$image_url" -o "$temp_image"; then
        echo -e "${RED}Failed to download image from URL (file too large or network error)${NC}"
        return 1
    fi
    
    # Check if file was actually downloaded
    if [ ! -f "$temp_image" ] || [ ! -s "$temp_image" ]; then
        echo -e "${RED}Downloaded file is empty or doesn't exist${NC}"
        rm -f "$temp_image"
        return 1
    fi
    
    # Get file size
    local file_size=$(wc -c < "$temp_image")
    echo -e "${BLUE}Downloaded file size: $file_size bytes${NC}"
    
    # Get file extension and MIME type
    local filename=$(basename "$image_url" | cut -d'?' -f1)  # Remove query parameters
    local extension="${filename##*.}"
    local mime_type="image/jpeg"  # Default
    
    case "${extension,,}" in  # Convert to lowercase
        jpg|jpeg)
            mime_type="image/jpeg"
            extension="jpg"
            ;;
        png)
            mime_type="image/png"
            ;;
        gif)
            mime_type="image/gif"
            ;;
        webp)
            mime_type="image/webp"
            ;;
        *)
            # Detect file type using file command if available
            if command -v file >/dev/null 2>&1; then
                local file_type=$(file -b --mime-type "$temp_image")
                case "$file_type" in
                    image/jpeg)
                        extension="jpg"
                        mime_type="image/jpeg"
                        ;;
                    image/png)
                        extension="png"
                        mime_type="image/png"
                        ;;
                    image/gif)
                        extension="gif"
                        mime_type="image/gif"
                        ;;
                    image/webp)
                        extension="webp"
                        mime_type="image/webp"
                        ;;
                    *)
                        echo -e "${YELLOW}Unknown image type, defaulting to JPEG${NC}"
                        extension="jpg"
                        mime_type="image/jpeg"
                        ;;
                esac
            else
                extension="jpg"
                mime_type="image/jpeg"
            fi
            ;;
    esac
    
    echo -e "${BLUE}File type: $mime_type, Extension: $extension${NC}"
    
    # Check file size limit (5MB)
    if [ "$file_size" -gt 5242880 ]; then
        echo -e "${RED}Image file too large ($file_size bytes > 5MB limit)${NC}"
        rm -f "$temp_image"
        return 1
    fi
    
    # Encode image to base64
    echo -e "${YELLOW}Encoding image to base64...${NC}"
    local image_data
    if ! image_data=$(base64 < "$temp_image"); then
        echo -e "${RED}Failed to encode image to base64${NC}"
        rm -f "$temp_image"
        return 1
    fi
    
    # Clean up temp file early to save space
    rm -f "$temp_image"
    
    local filename_clean="featured_image_$(date +%s).$extension"
    echo -e "${YELLOW}Uploading as: $filename_clean${NC}"
    
    # Escape credentials for XML
    local username_escaped=$(echo "$username" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')
    local password_escaped=$(echo "$password" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')
    
    # Create upload payload
    local upload_payload=$(cat << EOF
<?xml version="1.0"?>
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
                        <value><string>$filename_clean</string></value>
                    </member>
                    <member>
                        <name>type</name>
                        <value><string>$mime_type</string></value>
                    </member>
                    <member>
                        <name>bits</name>
                        <value><base64>$image_data</base64></value>
                    </member>
                </struct>
            </value>
        </param>
    </params>
</methodCall>
EOF
)
    
    # Upload image
    echo -e "${YELLOW}Sending upload request...${NC}"
    local upload_response=$(curl -s -X POST \
        -H "Content-Type: text/xml" \
        -H "User-Agent: $USER_AGENT" \
        --max-time 60 \
        -d "$upload_payload" \
        "$XMLRPC_URL")
    
    # Simple error check for upload
    if echo "$upload_response" | grep -q "<name>faultCode</name>"; then
        echo -e "${RED}Image upload failed${NC}"
        local fault_string=$(echo "$upload_response" | grep -o '<name>faultString</name><value><string>.*</string></value>' | sed 's/<name>faultString<\/name><value><string>//; s/<\/string><\/value>//')
        echo -e "${RED}Error: $fault_string${NC}"
        return 1
    fi
    
    # Extract attachment ID from response
    local attachment_id=$(echo "$upload_response" | grep -o '<name>id</name><value><string>[0-9]*</string></value>' | grep -o '[0-9]*')
    
    if [ -n "$attachment_id" ]; then
        echo -e "${GREEN}Image uploaded successfully!${NC}"
        echo -e "${GREEN}Attachment ID: $attachment_id${NC}"
        echo "$attachment_id"
        return 0
    else
        echo -e "${RED}Failed to upload image - no attachment ID returned${NC}"
        echo -e "${RED}Response (first 500 chars): ${upload_response:0:500}${NC}"
        return 1
    fi
}

# Function to set featured image for post
set_featured_image() {
    local post_id="$1"
    local attachment_id="$2"
    local username="$3"
    local password="$4"
    
    echo -e "${YELLOW}Setting featured image for post ID $post_id...${NC}"
    echo -e "${BLUE}Using attachment ID: $attachment_id${NC}"
    
    # Escape credentials for XML
    local username_escaped=$(echo "$username" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')
    local password_escaped=$(echo "$password" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')
    
    local payload=$(cat << EOF
<?xml version="1.0"?>
<methodCall>
    <methodName>wp.editPost</methodName>
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
            <value><string>$post_id</string></value>
        </param>
        <param>
            <value>
                <struct>
                    <member>
                        <name>post_thumbnail</name>
                        <value><string>$attachment_id</string></value>
                    </member>
                </struct>
            </value>
        </param>
    </params>
</methodCall>
EOF
)
    
    local response=$(curl -s -X POST \
        -H "Content-Type: text/xml" \
        -H "User-Agent: $USER_AGENT" \
        --max-time 30 \
        -d "$payload" \
        "$XMLRPC_URL")
    
    # Simple error check
    if echo "$response" | grep -q "<name>faultCode</name>"; then
        echo -e "${RED}Failed to set featured image${NC}"
        local fault_string=$(echo "$response" | grep -o '<name>faultString</name><value><string>.*</string></value>' | sed 's/<name>faultString<\/name><value><string>//; s/<\/string><\/value>//')
        echo -e "${RED}Error: $fault_string${NC}"
        return 1
    fi
    
    if echo "$response" | grep -q "<boolean>1</boolean>"; then
        echo -e "${GREEN}Featured image set successfully!${NC}"
        return 0
    else
        echo -e "${RED}Failed to set featured image${NC}"
        echo -e "${RED}Response: $response${NC}"
        
        # Try alternative method using meta_value
        echo -e "${YELLOW}Trying alternative method...${NC}"
        
        local alt_payload=$(cat << EOF
<?xml version="1.0"?>
<methodCall>
    <methodName>wp.editPost</methodName>
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
            <value><string>$post_id</string></value>
        </param>
        <param>
            <value>
                <struct>
                    <member>
                        <name>custom_fields</name>
                        <value>
                            <array>
                                <data>
                                    <value>
                                        <struct>
                                            <member>
                                                <name>key</name>
                                                <value><string>_thumbnail_id</string></value>
                                            </member>
                                            <member>
                                                <name>value</name>
                                                <value><string>$attachment_id</string></value>
                                            </member>
                                        </struct>
                                    </value>
                                </data>
                            </array>
                        </value>
                    </member>
                </struct>
            </value>
        </param>
    </params>
</methodCall>
EOF
)
        
        local alt_response=$(curl -s -X POST \
            -H "Content-Type: text/xml" \
            -H "User-Agent: $USER_AGENT" \
            --max-time 30 \
            -d "$alt_payload" \
            "$XMLRPC_URL")
        
        if echo "$alt_response" | grep -q "<boolean>1</boolean>"; then
            echo -e "${GREEN}Featured image set successfully using alternative method!${NC}"
            return 0
        else
            echo -e "${RED}Alternative method also failed${NC}"
            if echo "$alt_response" | grep -q "<name>faultCode</name>"; then
                local alt_fault_string=$(echo "$alt_response" | grep -o '<name>faultString</name><value><string>.*</string></value>' | sed 's/<name>faultString<\/name><value><string>//; s/<\/string><\/value>//')
                echo -e "${RED}Alt Error: $alt_fault_string${NC}"
            fi
            return 1
        fi
    fi
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

# Function to check for XML-RPC errors
check_xmlrpc_error() {
    local response="$1"
    
    if echo "$response" | grep -q "<name>faultCode</name>"; then
        local fault_code=$(echo "$response" | grep -o '<name>faultCode</name><value><int>[0-9]*</int></value>' | grep -o '[0-9]*')
        local fault_string=$(echo "$response" | grep -o '<name>faultString</name><value><string>.*</string></value>' | sed 's/<name>faultString<\/name><value><string>//; s/<\/string><\/value>//')
        
        echo -e "${RED}XML-RPC Error:${NC}"
        echo -e "${RED}Code: $fault_code${NC}"
        echo -e "${RED}Message: $fault_string${NC}"
        return 1
    fi
    
    return 0
}

# Main function
main() {
    echo -e "${GREEN}WordPress Draft Poster Script${NC}"
    echo -e "${GREEN}==============================${NC}"
    echo ""
    
    # Check dependencies
    check_dependencies
    
    local CONFIG_MODE=false
    local LOAD_CONFIG_MODE=false
    local CONFIG_FILE=""
    
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
        echo -e "${YELLOW}Full response: $response${NC}"
        exit 1
    fi
    
    # Extract post ID
    local post_id=$(extract_post_id "$response")
    
    if [ -n "$post_id" ]; then
        echo -e "${GREEN}Draft post created successfully!${NC}"
        echo -e "${GREEN}Post ID: $post_id${NC}"
        echo -e "${GREEN}Edit URL: $BLOG_URL/wp-admin/post.php?post=$post_id&action=edit${NC}"
        
        # Handle featured image if provided
        if [ -n "$IMAGE_URL" ]; then
            echo ""
            echo -e "${BLUE}Processing featured image...${NC}"
            
            # Test image URL first
            if test_image_url "$IMAGE_URL"; then
                local attachment_id=$(upload_image "$IMAGE_URL" "$WP_USERNAME" "$WP_PASSWORD")
                if [ $? -eq 0 ] && [ -n "$attachment_id" ]; then
                    if set_featured_image "$post_id" "$attachment_id" "$WP_USERNAME" "$WP_PASSWORD"; then
                        echo -e "${GREEN}Featured image processing completed successfully!${NC}"
                    else
                        echo -e "${YELLOW}Post created but featured image could not be set.${NC}"
                        echo -e "${YELLOW}You can manually set it in WordPress admin using attachment ID: $attachment_id${NC}"
                    fi
                else
                    echo -e "${YELLOW}Post created but image upload failed.${NC}"
                    echo -e "${YELLOW}You can manually upload and set the featured image in WordPress admin.${NC}"
                fi
            else
                echo -e "${YELLOW}Post created but image URL validation failed.${NC}"
                echo -e "${YELLOW}Please check the image URL and set featured image manually in WordPress admin.${NC}"
            fi
        fi
        
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