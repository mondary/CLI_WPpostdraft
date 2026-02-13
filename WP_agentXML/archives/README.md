# Archive Management

## Creating New Archives

To create a new archived version when the main script is stable:

```bash
# From the main directory
./archives/archive_version.sh v5
```

This will:
1. Copy `wp_post_draft.sh` to `archives/wp_post_draft_v5.sh`
2. Display all current versions
3. Preserve the main development script

## Current Archived Versions

- **v6**: Jetpack Social integration (excerpt → social message, featured image → social media attachment)
- **v5**: Excerpt functionality for SEO and post previews
- **v4**: Inline image support with markdown syntax
- **v3**: Rich text formatting support
- **v2**: Auto-detection and enhanced UX

## Usage

Use archived versions for production environments where stability is critical:

```bash
# Use stable v4 for production
./archives/wp_post_draft_v4.sh --auto

# Continue development with main version
./wp_post_draft.sh --auto
```