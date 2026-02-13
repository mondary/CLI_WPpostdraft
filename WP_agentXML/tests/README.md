# Test Suite

## Running Tests

### Core Functionality Tests
```bash
# Test basic connectivity
./test_basic_connectivity.sh

# Test credentials
./test_credentials.sh

# Test post permissions
./test_post_permission.sh

# Complete XML-RPC diagnostics
./test_diagnose_xmlrpc.sh
```

### Feature Tests
```bash
# Test rich text formatting
./test_formatting.sh

# Test inline images
./test_inline_images.sh

# Test featured images (comprehensive)
./test_featured_image.sh

# Test local file upload
./test_local_upload.sh

# Test image validation
./test_image_validation.sh

# Test header formatting
./test_headers_fix.sh

# Test excerpt functionality
./test_excerpt_functionality.sh

# Test Jetpack Social integration
./test_jetpack_social_integration.sh
```

### WPCode Integration Tests
```bash
# Test WPCode featured image functionality
./test_wpcode_featured.sh

# Verify WPCode installation
./test_wpcode_verification.sh
```

### Comprehensive Tests
```bash
# Full feature demonstration
./test_demo_usage.sh

# Minimal functionality test
./test_minimal.sh
```

## Running from Main Directory

All tests can be run from the main directory:

```bash
# Example
./tests/test_demo_usage.sh
```

## Test Requirements

Most tests require:
- Active internet connection
- Valid WordPress credentials in `mondary.conf`
- XML-RPC enabled on target WordPress site

## Adding New Tests

When adding new functionality:
1. Create test file with `test_` prefix
2. Make it executable: `chmod +x test_new_feature.sh`
3. Follow existing test patterns
4. Update this README