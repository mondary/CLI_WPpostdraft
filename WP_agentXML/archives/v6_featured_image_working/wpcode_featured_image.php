<?php
/**
 * WPCode Function: Featured Image from URL
 * 
 * This function handles featured images from custom field URLs created by wp_post_draft.sh script.
 * It automatically downloads images and sets them as WordPress featured images.
 * 
 * HOW IT WORKS:
 * 1. The shell script creates posts with a 'featured_image_url' custom field
 * 2. This WPCode snippet detects when posts are saved in WordPress admin
 * 3. It downloads the image from the URL to WordPress media library
 * 4. Sets the downloaded image as the actual WordPress featured image
 * 5. Removes the custom field after successful processing
 * 
 * SETUP REQUIRED:
 * - Install WPCode plugin in WordPress
 * - Add this code as a PHP snippet in WPCode
 * - Activate the snippet
 * 
 * USAGE:
 * After creating a post with wp_post_draft.sh, go to WordPress admin and
 * save/update the post to trigger this automatic processing.
 */

// Hook into post save to process featured image URLs
// This triggers when you save/update a post in WordPress admin
add_action( 'save_post', 'mondary_auto_featured_image_from_url', 10, 2 );
function mondary_auto_featured_image_from_url( $post_id, $post ) {
    // Skip if this is an autosave or revision (prevents unnecessary processing)
    if ( defined( 'DOING_AUTOSAVE' ) && DOING_AUTOSAVE ) {
        return;
    }
    
    // Only process posts (not pages, custom post types, etc.)
    if ( $post->post_type !== 'post' ) {
        return;
    }
    
    // Skip if already has featured image (prevents overwriting existing images)
    if ( has_post_thumbnail( $post_id ) ) {
        return;
    }
    
    // Get the custom field URL created by wp_post_draft.sh
    $image_url = get_post_meta( $post_id, 'featured_image_url', true );
    
    // If no URL found, nothing to do
    if ( empty( $image_url ) ) {
        return;
    }
    
    // Download and set featured image
    $attachment_id = mondary_download_and_set_featured_image( $image_url, $post_id );
    
    // If successful, set as featured image and clean up
    if ( $attachment_id ) {
        set_post_thumbnail( $post_id, $attachment_id );
        // Remove the custom field since it's no longer needed
        delete_post_meta( $post_id, 'featured_image_url' );
    }
}

// Function to download image from URL and add to WordPress media library
function mondary_download_and_set_featured_image( $image_url, $post_id ) {
    // Include WordPress media functions (required for image processing)
    if ( ! function_exists( 'media_handle_sideload' ) ) {
        require_once( ABSPATH . 'wp-admin/includes/media.php' );
        require_once( ABSPATH . 'wp-admin/includes/file.php' );
        require_once( ABSPATH . 'wp-admin/includes/image.php' );
    }
    
    // Download image to temporary file
    $temp_file = download_url( $image_url );
    
    // Check if download was successful
    if ( is_wp_error( $temp_file ) ) {
        return false;
    }
    
    // Prepare file array for WordPress media handling
    $file_array = array(
        'name' => basename( $image_url ),    // Extract filename from URL
        'tmp_name' => $temp_file             // Path to temporary file
    );
    
    // Upload to media library and attach to post
    $attachment_id = media_handle_sideload( $file_array, $post_id );
    
    // Clean up temporary file (important for server storage)
    @unlink( $temp_file );
    
    // Return attachment ID if successful, false if failed
    if ( is_wp_error( $attachment_id ) ) {
        return false;
    }
    
    return $attachment_id;
}

// Fallback: Display image from URL if no featured image is set
// This ensures images show up even if the download process hasn't run yet
add_filter( 'post_thumbnail_html', 'mondary_display_featured_image_fallback', 10, 5 );
function mondary_display_featured_image_fallback( $html, $post_id, $post_thumbnail_id, $size, $attr ) {
    // Only provide fallback if no actual featured image exists
    if ( empty( $html ) ) {
        // Check for our custom field
        $image_url = get_post_meta( $post_id, 'featured_image_url', true );
        
        // If URL exists, display it directly
        if ( ! empty( $image_url ) ) {
            $alt_text = get_the_title( $post_id );
            $html = '<img src="' . esc_url( $image_url ) . '" alt="' . esc_attr( $alt_text ) . '" />';
        }
    }
    
    return $html;
}
?>
?>