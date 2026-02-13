#!/bin/bash

# WordPress Credential Test Script
BLOG_URL="https://mondary.design"
XMLRPC_URL="${BLOG_URL}/xmlrpc.php"

echo "=== WordPress Credential Test ==="
echo ""

# Load config if provided
if [ "$1" = "--config" ] && [ -n "$2" ]; then
    echo "Loading config from: $2"
    source "$2"
    username="$WP_USERNAME"
    password="$WP_PASSWORD"
    echo "Username from config: $username"
else
    read -p "WordPress Username: " username
    echo -n "WordPress Password: "
    read -s password
    echo ""
fi

echo ""
echo "Testing credentials with system.listMethods..."

# Escape XML special characters in credentials
username_escaped=$(echo "$username" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')
password_escaped=$(echo "$password" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')

# Test with system.listMethods (safer than creating posts)
test_payload="<?xml version=\"1.0\"?>
<methodCall>
    <methodName>system.listMethods</methodName>
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
    </params>
</methodCall>"

response=$(curl -s -X POST \
    -H "Content-Type: text/xml" \
    -H "User-Agent: WordPress XML-RPC Test" \
    --max-time 15 \
    -d "$test_payload" \
    "$XMLRPC_URL")

echo "Response:"
echo "$response" | head -20

if echo "$response" | grep -q "wp.newPost"; then
    echo ""
    echo "✅ Credentials are VALID and user can create posts!"
elif echo "$response" | grep -q "faultCode"; then
    echo ""
    echo "❌ Authentication failed"
    fault_code=$(echo "$response" | grep -o '<name>faultCode</name><value><int>[0-9]*</int></value>' | grep -o '[0-9]*')
    fault_string=$(echo "$response" | grep -o '<name>faultString</name><value><string>.*</string></value>' | sed 's/<name>faultString<\/name><value><string>//; s/<\/string><\/value>//')
    echo "Error Code: $fault_code"
    echo "Error Message: $fault_string"
else
    echo ""
    echo "⚠️  Unexpected response"
fi

echo ""
echo "=== Suggestions ==="
echo "1. Verify username and password in WordPress admin"
echo "2. Check if user has 'edit_posts' capability"
echo "3. Look for security plugins blocking XML-RPC"
echo "4. Try creating an Application Password in WordPress (if WP 5.6+)"