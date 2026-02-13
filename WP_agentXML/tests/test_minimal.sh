#!/bin/bash

# Minimal test to check what's happening with XML-RPC
BLOG_URL="https://mondary.design"
XMLRPC_URL="${BLOG_URL}/xmlrpc.php"

echo "Testing basic XML-RPC connectivity..."

# Test 1: Simple method call
echo "1. Testing demo.sayHello..."
response1=$(curl -s -X POST \
    -H "Content-Type: text/xml" \
    -H "User-Agent: WordPress XML-RPC Test" \
    --max-time 15 \
    -d '<?xml version="1.0"?><methodCall><methodName>demo.sayHello</methodName><params></params></methodCall>' \
    "$XMLRPC_URL")

echo "Response: ${response1:0:200}..."
echo ""

# Test 2: Check if we get any response at all
echo "2. Testing with system.listMethods (no auth)..."
response2=$(curl -s -X POST \
    -H "Content-Type: text/xml" \
    -H "User-Agent: WordPress XML-RPC Test" \
    --max-time 15 \
    -d '<?xml version="1.0"?><methodCall><methodName>system.listMethods</methodName><params></params></methodCall>' \
    "$XMLRPC_URL")

echo "Response: ${response2:0:200}..."
echo ""

# Test 3: HTTP response check
echo "3. Testing HTTP response code..."
http_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    -H "Content-Type: text/xml" \
    -d '<?xml version="1.0"?><methodCall><methodName>demo.sayHello</methodName><params></params></methodCall>' \
    "$XMLRPC_URL")

echo "HTTP Code: $http_code"
echo ""

if [ "$http_code" = "200" ]; then
    echo "✓ XML-RPC endpoint is responding correctly"
else
    echo "✗ XML-RPC endpoint issue (HTTP $http_code)"
fi