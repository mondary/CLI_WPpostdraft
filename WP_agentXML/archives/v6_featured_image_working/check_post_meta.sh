#!/bin/bash

# Check post meta for featured image debugging
source mondary.conf

echo "=== Checking Post Meta for Featured Image Debug ==="
echo "Post ID: 39201"
echo ""

# Check post details including custom fields
curl -s -X POST "https://mondary.design/xmlrpc.php" \
-H "Content-Type: application/xml" \
-d "<?xml version='1.0'?>
<methodCall>
<methodName>wp.getPost</methodName>
<params>
<param><value><string>$username</string></value></param>
<param><value><string>$password</string></value></param>
<param><value><string>39201</string></value></param>
<param><value><array>
<data>
<value><string>custom_fields</string></value>
</data>
</array></value></param>
</params>
</methodCall>" | xmllint --format - | grep -A 20 -B 5 "custom_fields\|_jetpack_featured_image_url"

echo ""
echo "=== End Debug ==="