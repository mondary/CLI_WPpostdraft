#!/bin/bash

# XML-RPC Diagnostic Script
# This script helps diagnose WordPress XML-RPC connection issues

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

BLOG_URL="https://mondary.design"
XMLRPC_URL="${BLOG_URL}/xmlrpc.php"

echo -e "${BLUE}=== WordPress XML-RPC Diagnostic Tool ===${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

echo -e "${YELLOW}Testing: $XMLRPC_URL${NC}"
echo ""

# Test 1: Basic connectivity
echo -e "${BLUE}1. Testing basic connectivity...${NC}"
if curl -s --max-time 10 "$BLOG_URL" > /dev/null; then
    echo -e "${GREEN}✓ Blog URL accessible${NC}"
else
    echo -e "${RED}✗ Blog URL not accessible${NC}"
    exit 1
fi

# Test 2: XML-RPC endpoint accessibility
echo -e "${BLUE}2. Testing XML-RPC endpoint...${NC}"
xmlrpc_response=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" "$XMLRPC_URL")
if [ "$xmlrpc_response" = "405" ] || [ "$xmlrpc_response" = "200" ]; then
    echo -e "${GREEN}✓ XML-RPC endpoint accessible (HTTP $xmlrpc_response)${NC}"
else
    echo -e "${RED}✗ XML-RPC endpoint issue (HTTP $xmlrpc_response)${NC}"
    echo -e "${YELLOW}Note: 405 Method Not Allowed is normal for GET requests to XML-RPC${NC}"
fi

# Test 3: XML-RPC availability check
echo -e "${BLUE}3. Testing XML-RPC availability...${NC}"
availability_test='<?xml version="1.0"?>
<methodCall>
    <methodName>demo.sayHello</methodName>
    <params></params>
</methodCall>'

availability_response=$(curl -s -X POST \
    -H "Content-Type: text/xml" \
    -H "User-Agent: WordPress XML-RPC Diagnostic" \
    --max-time 15 \
    -d "$availability_test" \
    "$XMLRPC_URL")

if echo "$availability_response" | grep -q "Hello"; then
    echo -e "${GREEN}✓ XML-RPC is working${NC}"
elif echo "$availability_response" | grep -q "faultCode"; then
    echo -e "${YELLOW}⚠ XML-RPC responds but demo method not available (normal)${NC}"
else
    echo -e "${RED}✗ XML-RPC might be disabled${NC}"
    echo -e "${YELLOW}Response: ${availability_response:0:200}...${NC}"
fi

# Test 4: Authentication test (if credentials provided)
echo ""
echo -e "${BLUE}4. Authentication test${NC}"
read -p "WordPress Username (or press Enter to skip auth test): " test_username
if [ -n "$test_username" ]; then
    echo -n "WordPress Password: "
    read -s test_password
    echo ""
    
    # Test with system.listMethods (safer than posting)
    auth_test="<?xml version=\"1.0\"?>
<methodCall>
    <methodName>system.listMethods</methodName>
    <params>
        <param>
            <value><string>1</string></value>
        </param>
        <param>
            <value><string>$test_username</string></value>
        </param>
        <param>
            <value><string>$test_password</string></value>
        </param>
    </params>
</methodCall>"
    
    echo -e "${YELLOW}Testing authentication...${NC}"
    auth_response=$(curl -s -X POST \
        -H "Content-Type: text/xml" \
        -H "User-Agent: WordPress XML-RPC Diagnostic" \
        --max-time 15 \
        -d "$auth_test" \
        "$XMLRPC_URL")
    
    if echo "$auth_response" | grep -q "wp.newPost"; then
        echo -e "${GREEN}✓ Authentication successful${NC}"
        echo -e "${GREEN}✓ wp.newPost method available${NC}"
    elif echo "$auth_response" | grep -q "faultCode"; then
        fault_code=$(echo "$auth_response" | grep -o '<name>faultCode</name><value><int>[0-9]*</int></value>' | grep -o '[0-9]*')
        fault_string=$(echo "$auth_response" | grep -o '<name>faultString</name><value><string>.*</string></value>' | sed 's/<name>faultString<\/name><value><string>//; s/<\/string><\/value>//')
        echo -e "${RED}✗ Authentication failed${NC}"
        echo -e "${RED}Error Code: $fault_code${NC}"
        echo -e "${RED}Error Message: $fault_string${NC}"
    else
        echo -e "${RED}✗ Unexpected response${NC}"
        echo -e "${YELLOW}Response: ${auth_response:0:300}...${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Skipping authentication test${NC}"
fi

echo ""
echo -e "${BLUE}5. Common solutions:${NC}"
echo "• Check if WordPress XML-RPC is enabled"
echo "• Verify username and password are correct"
echo "• Check for security plugins blocking XML-RPC"
echo "• Verify SSL/TLS certificate if using HTTPS"
echo "• Check WordPress user permissions"
echo "• Look for rate limiting or firewall blocks"

echo ""
echo -e "${BLUE}6. WordPress XML-RPC settings to check:${NC}"
echo "• Settings > Writing > Remote Publishing (should be enabled)"
echo "• Security plugins (Wordfence, etc.) - check XML-RPC settings"
echo "• .htaccess rules that might block /xmlrpc.php"
echo ""
echo -e "${GREEN}Diagnostic complete!${NC}"