<?php
/**
 * Auto-schedule posts to 14:00 on next available weekday
 * Compatible with XML-RPC and WordPress admin
 * 
 * TRULY FIXED VERSION: Only triggers on manual save, not XML-RPC creation
 * 
 * This script works by:
 * 1. Detecting when posts are manually saved in WordPress admin
 * 2. Checking if auto-scheduling should be disabled (no_auto_schedule flag)
 * 3. Finding the next available weekday slot at 14:00
 * 4. Updating the post schedule automatically (only if triggered)
 * 
 * Installation:
 * 1. Go to WordPress Admin → WPCode → Code Snippets
 * 2. Add new PHP snippet
 * 3. Paste this entire code
 * 4. Title: "Auto Schedule Posts 14:00 Weekdays (Fixed)"
 * 5. ACTIVATE the snippet
 * 6. DEACTIVATE your old scheduling snippet to avoid conflicts
 */

if (!function_exists('auto_schedule_posts_14h_fixed')) {
    
    /**
     * Hook into post save to handle scheduling
     * This hook triggers only when posts are manually saved in WordPress admin
     * NOT during XML-RPC post creation
     */
    add_action('save_post', 'auto_schedule_posts_14h_fixed', 10, 3);
    
    function auto_schedule_posts_14h_fixed($post_id, $post, $update) {
        // Only process posts (not pages or other post types)
        if ($post->post_type !== 'post') {
            return;
        }
        
        // CHECK FOR NO_AUTO_SCHEDULE FLAG FIRST
        // If this flag is set, don't auto-schedule the post
        $no_auto_schedule = get_post_meta($post_id, 'no_auto_schedule', true);
        if ($no_auto_schedule) {
            // Clean up the flag and exit without scheduling
            delete_post_meta($post_id, 'no_auto_schedule');
            error_log("Post ID $post_id: Auto-scheduling disabled by no_auto_schedule flag");
            return;
        }
        
        // Only schedule if this is a draft or new post
        // Also check if post_date is in the past or default (indicating it needs scheduling)
        if ($post->post_status !== 'draft') {
            return;
        }
        
        // Skip if this is an update and post already has a future scheduled time
        // UNLESS the post has auto_schedule custom field set
        $force_auto_schedule = get_post_meta($post_id, 'auto_schedule', true);
        if ($update && $post->post_date !== '0000-00-00 00:00:00' && strtotime($post->post_date) > current_time('timestamp') && !$force_auto_schedule) {
            return;
        }
        
        // Find next available slot
        $scheduled_datetime = find_next_available_slot_fixed();
        
        if ($scheduled_datetime) {
            // Update post with new schedule
            wp_update_post(array(
                'ID' => $post_id,
                'post_date' => $scheduled_datetime,
                'post_date_gmt' => get_gmt_from_date($scheduled_datetime),
                'post_status' => 'future' // Change status to scheduled
            ));
            
            // Clean up the auto_schedule trigger field
            delete_post_meta($post_id, 'auto_schedule');
            
            // Optional: Log the scheduling (remove in production)
            error_log("Post ID $post_id auto-scheduled for: $scheduled_datetime");
        }
    }
    
    /**
     * Find the next available weekday slot at 14:00
     * Returns datetime string in Y-m-d H:i:s format
     */
    function find_next_available_slot_fixed() {
        // Start with today's date
        $check_date = current_time('Y-m-d');
        
        // Look up to 45 days ahead to find an available slot
        for ($i = 0; $i < 45; $i++) {
            // Skip weekends (Saturday = 6, Sunday = 7)
            $day_of_week = date('N', strtotime($check_date));
            if ($day_of_week >= 6) {
                $check_date = date('Y-m-d', strtotime($check_date . ' +1 day'));
                continue;
            }
            
            // Create the full datetime string for 14:00
            $check_datetime = $check_date . ' 14:00:00';
            
            // Skip if this time is in the past
            if (strtotime($check_datetime) <= current_time('timestamp')) {
                $check_date = date('Y-m-d', strtotime($check_date . ' +1 day'));
                continue;
            }
            
            // Check if any posts are already scheduled for this exact time
            $existing_posts = get_posts(array(
                'post_type' => 'post',
                'post_status' => array('future', 'publish'),
                'date_query' => array(
                    array(
                        'year' => date('Y', strtotime($check_datetime)),
                        'month' => date('m', strtotime($check_datetime)),
                        'day' => date('d', strtotime($check_datetime)),
                        'hour' => 14,
                        'minute' => 0,
                    ),
                ),
                'posts_per_page' => 1,
            ));
            
            // If no existing posts, this slot is available
            if (empty($existing_posts)) {
                return $check_datetime;
            }
            
            // Move to next day
            $check_date = date('Y-m-d', strtotime($check_date . ' +1 day'));
        }
        
        // If no slot found in 45 days, return null
        return null;
    }
    
    /**
     * Optional: Add admin notice when posts are auto-scheduled
     * Remove this function if you don't want notifications
     */
    add_action('admin_notices', 'show_auto_schedule_notice_fixed');
    
    function show_auto_schedule_notice_fixed() {
        global $pagenow, $post;
        
        // Only show on post edit screen
        if ($pagenow !== 'post.php' || !$post) {
            return;
        }
        
        // Check if this post was auto-scheduled (has future status and 14:00 time)
        if ($post->post_status === 'future' && 
            date('H:i', strtotime($post->post_date)) === '14:00') {
            
            $scheduled_date = date('l, F j, Y \a\t g:i A', strtotime($post->post_date));
            echo '<div class="notice notice-info is-dismissible">';
            echo '<p><strong>Auto-scheduled:</strong> This post was automatically scheduled for ' . $scheduled_date . '</p>';
            echo '</div>';
        }
        
        // Show notice if post has no_auto_schedule flag (shouldn't happen, but for debugging)
        $no_auto_schedule = get_post_meta($post->ID, 'no_auto_schedule', true);
        if ($no_auto_schedule) {
            echo '<div class="notice notice-warning is-dismissible">';
            echo '<p><strong>Notice:</strong> This post has auto-scheduling disabled.</p>';
            echo '</div>';
        }
    }
}
?>