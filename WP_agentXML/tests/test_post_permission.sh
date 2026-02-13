#!/bin/bash

# Test wp.newPost permissions specifically
source mondary.conf

echo "=== Testing wp.newPost Permission ==="
echo "User: $WP_USERNAME"
echo ""

# Escape credentials
username_escaped=$(echo "$WP_USERNAME" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')
password_escaped=$(echo "$WP_PASSWORD" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')

# Create minimal test post payload
test_payload="<?xml version=\"1.0\"?>
<methodCall>
    <methodName>wp.newPost</methodName>
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
                        <name>post_type</name>
                        <value><string>post</string></value>
                    </member>
                    <member>
                        <name>post_status</name>
                        <value><string>draft</string></value>
                    </member>
                    <member>
                        <name>post_title</name>
                        <value><string>Test Permission</string></value>
                    </member>
                    <member>
                        <name>post_content</name>
                        <value><string>Test content</string></value>
                    </member>
                </struct>
            </value>
        </param>
    </params>
</methodCall>"

echo "Testing wp.newPost method..."
response=$(curl -s -X POST \
    -H "Content-Type: text/xml" \
    -H "User-Agent: WordPress XML-RPC Test" \
    --max-time 15 \
    -d "$test_payload" \
    "https://mondary.design/xmlrpc.php")

echo "Response:"
echo "$response"

if echo "$response" | grep -q "<string>[0-9]*</string>"; then
    post_id=$(echo "$response" | grep -o '<string>[0-9]*</string>' | head -1 | grep -o '[0-9]*')
    echo ""
    echo "✅ SUCCESS! Post created with ID: $post_id"
    echo "URL: https://mondary.design/wp-admin/post.php?post=$post_id&action=edit"
elif echo "$response" | grep -q "faultCode"; then
    fault_code=$(echo "$response" | grep -o '<name>faultCode</name><value><int>[0-9]*</int></value>' | grep -o '[0-9]*')
    fault_string=$(echo "$response" | grep -o '<name>faultString</name><value><string>.*</string></value>' | sed 's/<name>faultString<\/name><value><string>//; s/<\/string><\/value>//')
    echo ""
    echo "❌ FAILED"
    echo "Error Code: $fault_code"
    echo "Error Message: $fault_string"
    
    case "$fault_code" in
        "403")
            echo ""
            echo "🔍 Error 403 suggestions:"
            echo "- Check user capabilities in WordPress admin"
            echo "- Verify user can create posts manually"
            echo "- Check security plugins settings"
            ;;
        "401")
            echo ""
            echo "🔍 Error 401 suggestions:"
            echo "- Username or password incorrect"
            echo "- Try resetting password"
            ;;
    esac
fi