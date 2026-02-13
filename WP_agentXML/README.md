# WordPress XML-RPC Draft Poster

Complete WordPress automation script with **Jetpack Social integration** and **working featured image functionality** for seamless blog posting and social media sharing.

## 🚀 Core Files (Root Directory)

### Essential Components
- **[`wp_post_draft.sh`](wp_post_draft.sh)** - Main automation script (34KB)
- **[`wpcode_featured_image.php`](wpcode_featured_image.php)** - WPCode snippet for featured images ✅ **WORKING**
- **[`README.md`](README.md)** - This documentation
- **[`mondary.conf`](mondary.conf)** - WordPress credentials (secure)
- **[`.gitignore`](.gitignore)** - Git security rules

### Organized Directories
- **[`docs/`](docs/)** - Complete documentation and guides
- **[`tests/`](tests/)** - Test suite for verification (21 tests)
- **[`archives/`](archives/)** - Stable archived versions (v1-v6)
- **[`scripts/`](scripts/)** - Utility and diagnostic scripts

## ✅ **WORKING SOLUTION** - Featured Images

**Status**: Featured image functionality is fully operational using hybrid approach:
1. **Script** creates posts with `featured_image_url` custom field
2. **WPCode snippet** automatically downloads and sets WordPress featured images
3. **Integration** works with all themes, plugins, and Jetpack Social

> 📝 **Setup Guide**: See [`docs/FEATURED_IMAGE_SOLUTION.md`](docs/FEATURED_IMAGE_SOLUTION.md) for complete instructions

## ✨ Latest Features

### 🔗 **Jetpack Social Integration**
| **Script Input** | **Jetpack Social Output** |
|------------------|---------------------------|
| **Excerpt** → | **Social Media Message** |
| **Featured Image** → | **Social Media Attachment** |

*Automatically synchronizes your post content with social media sharing!*

### 🎨 **Rich Content Support**
- ✅ **Markdown formatting** (headers, bold, italic, code, bullets, separators)
- ✅ **Inline images** (markdown syntax `![alt](url)` and standalone URLs)
- ✅ **Featured images** (local files and URLs with WPCode integration) 💫 **WORKING**
- ✅ **Excerpt support** (for SEO and social sharing)

### ⚙️ **Smart Automation**
- ✅ **Auto-detection** of config files (mondary.conf, mysite.conf, etc.)
- ✅ **Environment variable** integration for default credentials
- ✅ **Secure configuration** with automatic 600 permissions
- ✅ **Enhanced error handling** with helpful suggestions

## 🚀 Quick Start

### 1. Setup (One Time)
```bash
# Setup WordPress credentials
./wp_post_draft.sh --config mondary.conf
```

### 2. Create Posts
```bash
# Interactive mode (auto-detects config)
./wp_post_draft.sh

# Explicit auto-detection
./wp_post_draft.sh --auto

# Manual config loading
./wp_post_draft.sh --load-config mondary.conf
```

### 3. Verify Featured Image Setup
```bash
# Test the working featured image functionality
./tests/test_featured_image.sh

# Test Jetpack Social integration  
./tests/test_jetpack_social_integration.sh
```

> 📝 **Important**: Install WPCode plugin and add the snippet from [`wpcode_featured_image.php`](wpcode_featured_image.php) - see [`docs/FEATURED_IMAGE_SOLUTION.md`](docs/FEATURED_IMAGE_SOLUTION.md)

## 📆 Version Management

| **Version** | **Status** | **Features** |
|-------------|------------|---------------|
| [`wp_post_draft.sh`](wp_post_draft.sh) | 🟢 **Current Dev** | Jetpack Social + All features |
| [`archives/wp_post_draft_v5.sh`](archives/wp_post_draft_v5.sh) | 🟡 **Stable** | Excerpt functionality |
| [`archives/wp_post_draft_v4.sh`](archives/wp_post_draft_v4.sh) | 🟡 **Stable** | Inline image support |
| [`archives/wp_post_draft_v3.sh`](archives/wp_post_draft_v3.sh) | 🟡 **Stable** | Rich text formatting |
| [`archives/wp_post_draft_v2.sh`](archives/wp_post_draft_v2.sh) | 🟡 **Stable** | Auto-detection |

*Use archived versions for production environments requiring stability*

## 🧪 Testing

### Core Tests
```bash
./tests/test_demo_usage.sh          # Full feature demo
./tests/test_diagnose_xmlrpc.sh     # Connection diagnostics  
./tests/test_credentials.sh         # Credential verification
```

### Feature Tests
```bash
./tests/test_featured_image.sh              # 💫 Featured image functionality (WORKING)
./tests/test_jetpack_social_integration.sh  # Social media integration
./tests/test_formatting.sh                  # Rich text formatting  
./tests/test_excerpt_functionality.sh       # Excerpt support
```

## 🔧 Advanced Configuration

### Environment Variables
```bash
export WP_DEFAULT_USERNAME="your_username"
export WP_DEFAULT_PASSWORD="your_password" 
export WP_USER_AGENT="WordPress XML-RPC Client/2.0"
```

### Featured Image Setup
See **[docs/FEATURED_IMAGE_SOLUTION.md](docs/FEATURED_IMAGE_SOLUTION.md)** for the complete working setup guide.

### Simple Usage Guide  
See **[docs/GUIDE_UTILISATION_SIMPLE.md](docs/GUIDE_UTILISATION_SIMPLE.md)** for step-by-step instructions.

### Jetpack Social Setup
See **[docs/JETPACK_SOCIAL_GUIDE.md](docs/JETPACK_SOCIAL_GUIDE.md)** for complete setup instructions.

---

**🎉 Ready for automated blogging with social media integration and working featured images!**