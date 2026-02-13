# Jetpack Social Integration Guide

## Overview

The WordPress XML-RPC Draft Poster now includes **automatic Jetpack Social integration**! This feature synchronizes your post excerpt and featured image with Jetpack Social for seamless social media sharing.

## How It Works

### 🔄 **Automatic Synchronization**

| **Script Field** | **Jetpack Social Field** | **Result** |
|------------------|---------------------------|------------|
| **Excerpt** | Custom Message (`_wpas_mess`) | Your excerpt becomes the social media message |
| **Featured Image** | Media Attachment | Featured image is shared as social media image |

## Setup Requirements

### 1. **Jetpack Social Plugin**
```bash
# Install via WP Admin:
# Plugins → Add New → Search "Jetpack Social" → Install & Activate
```

### 2. **Connect Social Networks**
1. Go to **Jetpack → Social** in WordPress Admin
2. Click **"Connect an account"**
3. Connect your social networks (Facebook, Twitter, LinkedIn, etc.)
4. Enable **"Automatically share your posts to social networks"**

## Usage Examples

### Example 1: Basic Social Post
```bash
./wp_post_draft.sh --auto
```
**Input:**
- Title: "New Blog Post"
- Excerpt: "Check out my latest article about WordPress automation! 🚀"
- Featured Image: `https://example.com/image.jpg`

**Result:**
- ✅ Social message: "Check out my latest article about WordPress automation! 🚀"
- ✅ Social image: Featured image from URL

### Example 2: With Local Image
```bash
./wp_post_draft.sh --auto
```
**Input:**
- Title: "Tutorial: Shell Scripting"
- Excerpt: "Learn shell scripting basics in 10 minutes #Tutorial #ShellScript"
- Featured Image: `/path/to/local/image.png`

**Result:**
- ✅ Social message: "Learn shell scripting basics in 10 minutes #Tutorial #ShellScript"
- ✅ Social image: Uploaded local image

## Best Practices

### ✅ **Excerpt Guidelines**
- **Length**: Keep under 255 characters (Jetpack Social limit)
- **Hashtags**: Include relevant hashtags for better reach
- **Emojis**: Use emojis to make posts more engaging
- **Call-to-action**: Include engaging phrases

### ✅ **Featured Image Tips**
- **Size**: Minimum 1200x630px for best social media display
- **Format**: JPG, PNG, or WebP
- **Content**: Clear, high-contrast images work best
- **Text**: Avoid images with too much text (Facebook policy)

## Technical Details

### Custom Fields Created
```xml
<!-- Jetpack Social custom message -->
<member>
    <name>_wpas_mess</name>
    <value><string>Your excerpt here</string></value>
</member>

<!-- Featured image URL (if using URL) -->
<member>
    <name>featured_image_url</name>
    <value><string>https://example.com/image.jpg</string></value>
</member>
```

### Supported Social Networks
- **Facebook** (Pages & Personal)
- **Twitter/X**
- **LinkedIn** (Personal & Company)
- **Instagram** (Business accounts)
- **Tumblr**
- **Mastodon**
- **Threads**
- **Nextdoor**

## Troubleshooting

### ❌ **Social Message Not Appearing**
1. Check if Jetpack Social is activated
2. Verify social networks are connected
3. Ensure auto-sharing is enabled
4. Check if excerpt was provided

### ❌ **Image Not Sharing**
1. Verify featured image is set
2. Check image URL accessibility
3. Ensure image meets platform requirements
4. Try re-uploading the image

### ❌ **Post Not Auto-Sharing**
1. Go to **Jetpack → Social**
2. Check connection status
3. Verify post status (auto-share works on publish, not draft)
4. Check Jetpack Social logs

## Manual Verification

### In WordPress Admin:
1. **Posts → Edit Post**
2. Look for **Jetpack Social** section in sidebar
3. Verify custom message matches excerpt
4. Confirm image is attached

### Advanced Check:
1. **Posts → Screen Options → Custom Fields**
2. Look for `_wpas_mess` field
3. Verify value matches your excerpt

## Migration from Manual Setup

If you were manually setting Jetpack Social messages:
1. **Now**: Just add an excerpt to your script input
2. **Before**: Had to manually edit in WordPress admin
3. **Benefit**: Fully automated workflow

## Integration Benefits

### 🚀 **Workflow Advantages**
- ✅ **One-time setup**: Configure once, works automatically
- ✅ **Consistent branding**: Same message/image across platforms
- ✅ **Time saving**: No manual social media posting needed
- ✅ **SEO boost**: Excerpt improves post snippets and social sharing

### 📊 **Social Media Benefits**
- ✅ **Professional appearance**: Proper images and messages
- ✅ **Better engagement**: Optimized for each platform
- ✅ **Cross-platform consistency**: Same content everywhere
- ✅ **Automated scheduling**: Works with Jetpack Social scheduling

## Next Steps

After setting up Jetpack Social integration:

1. **Test the integration** with the test script:
   ```bash
   ./tests/test_jetpack_social_integration.sh
   ```

2. **Publish a post** (not just draft) to see social sharing in action

3. **Monitor performance** in Jetpack Social analytics

4. **Adjust excerpt strategy** based on social media performance

---

**Happy automated social sharing! 🎉**