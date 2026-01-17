#!/bin/bash

# Simplified Spotify Downloader & ISO Creator with Zenity GUI
# Refactored for reliability while keeping all features

# Remove exit on error for better control
set +e

# Simple check for zenity
if ! command -v zenity >/dev/null 2>&1; then
    echo "Installing zenity..."
    sudo apt update && sudo apt install -y zenity
fi

WINDOW_TITLE="🎵 Spotify Downloader Enhanced"

# Simple notification function
notify() {
    local message="$1"
    local is_success="${2:-false}"
    echo "$message"
    notify-send "Spotify Downloader" "$message" 2>/dev/null || true
    if [[ "$is_success" == true ]]; then
        play_success_sound
    fi
}

# Simple info dialog
show_info() {
    local message="$1"
    local timeout="${2:-0}"
    if [[ $timeout -gt 0 ]]; then
        zenity --info --title="$WINDOW_TITLE" --text="$message" --timeout="$timeout" 2>/dev/null || echo "$message"
    else
        zenity --info --title="$WINDOW_TITLE" --text="$message" 2>/dev/null || echo "$message"
    fi
}

# Simple question dialog
ask_question() {
    local question="$1"
    zenity --question --title="$WINDOW_TITLE" --text="$question" 2>/dev/null
    return $?

}

# Simple error dialog
show_error() {
    local message="$1"
    echo "ERROR: $message"
    zenity --error --title="$WINDOW_TITLE" --text="$message" 2>/dev/null || true
}

# Simple warning dialog
show_warning() {
    local message="$1"
    echo "WARNING: $message"
    zenity --warning --title="$WINDOW_TITLE" --text="$message" 2>/dev/null || true
}

# Ask user about sound feedback at the beginning
SOUND_ENABLED=true
if ask_question "Enable sound feedback for success notifications?"; then
    SOUND_ENABLED=true
else
    SOUND_ENABLED=false
fi

# Enhanced sound function with multiple fallbacks
play_success_sound() {
    if [[ "$SOUND_ENABLED" == true ]]; then
        echo "🔊 Playing success sound..."
        
        # Try multiple sound files and players
        SOUND_FILES=(
            "/usr/share/sounds/alsa/Front_Left.wav"
            "/usr/share/sounds/sound-icons/prompt.wav"
            "/usr/share/sounds/generic.wav"
            "/usr/share/sounds/KDE-Sys-App-Positive.ogg"
            "/usr/share/sounds/freedesktop/stereo/complete.oga"
        )
        
        SOUND_PLAYERS=(
            "paplay"
            "aplay"
            "play"
            "ffplay -nodisp -autoexit"
            "mplayer"
        )
        
        for sound_file in "${SOUND_FILES[@]}"; do
            if [[ -f "$sound_file" ]]; then
                for player in "${SOUND_PLAYERS[@]}"; do
                    if command -v "${player%% *}" >/dev/null 2>&1; then
                        echo "Trying: $player $sound_file"
                        timeout 3 "$player" "$sound_file" >/dev/null 2>&1 && return 0
                    fi
                done
            fi
        done
        
        # Fallback: system beep
        echo -e "\a" 2>/dev/null || echo "🔔 BEEP!"
    fi
}

# Enhanced mount point content analyzer
analyze_mount_point() {
    local mount_path="$1"
    local analysis_result=""
    
    echo "📋 Analyzing mount point: $mount_path"
    
    # Basic existence check
    if [[ ! -d "$mount_path" ]]; then
        analysis_result="❌ Directory does not exist"
        echo "$analysis_result"
        show_info "$analysis_result" 3
        return 1
    fi
    
    # Check if mounted (multiple methods)
    local is_mounted=false
    
    # Method 1: Check /proc/mounts
    if grep -q "$(readlink -f "$mount_path")" /proc/mounts 2>/dev/null; then
        is_mounted=true
        echo "✅ Mount detected in /proc/mounts"
        show_info "✅ Mount detected in /proc/mounts" 2
    fi
    
    # Method 2: Check mount command output
    if mount | grep -q "$(readlink -f "$mount_path")" 2>/dev/null; then
        is_mounted=true
        echo "✅ Mount detected in mount output"
        show_info "✅ Mount detected in mount output" 2
    fi
    
    # Method 3: Check if directory has filesystem info
    if timeout 5 stat -f "$mount_path" >/dev/null 2>&1; then
        local fs_type
        fs_type=$(stat -f -c %T "$mount_path" 2>/dev/null)
        if [[ -n "$fs_type" ]]; then
            echo "📁 Filesystem type: $fs_type"
            show_info "📁 Filesystem type: $fs_type" 2
        fi
    fi
    
    # Analyze contents
    local file_count=0
    local dir_count=0
    local total_size=0
    local content_preview=""
    
    echo "🔍 Scanning contents..."
    show_info "🔍 Scanning contents of $mount_path..." 3
    
    # Count files and directories with timeout
    if timeout 10 find "$mount_path" -maxdepth 1 -type f 2>/dev/null | wc -l > /tmp/file_count; then
        file_count=$(cat /tmp/file_count)
        rm -f /tmp/file_count
        echo "📁 Found $file_count files"
    fi
    
    if timeout 10 find "$mount_path" -maxdepth 1 -type d 2>/dev/null | wc -l > /tmp/dir_count; then
        dir_count=$(cat /tmp/dir_count)
        rm -f /tmp/dir_count
        # Subtract 1 for the mount point itself
        if [[ $dir_count -gt 0 ]]; then
            ((dir_count--))
        fi
        echo "📂 Found $dir_count directories"
    fi
    
    # Get directory size with timeout
    if timeout 10 du -sh "$mount_path" 2>/dev/null | cut -f1 > /tmp/dir_size; then
        total_size=$(cat /tmp/dir_size)
        rm -f /tmp/dir_size
        echo "💾 Total size: $total_size"
    fi
    
    # Get content preview with timeout
    if timeout 10 ls -la "$mount_path"/ 2>/dev/null > /tmp/content_list; then
        content_preview=$(head -15 /tmp/content_list)
        rm -f /tmp/content_list
        echo "📋 Content preview generated"
    fi
    
    # Build analysis result
    analysis_result="📊 MOUNT POINT ANALYSIS: $mount_path

🔗 Resolved Path: $(readlink -f "$mount_path")
📁 Total Files: $file_count
📂 Total Directories: $dir_count
💾 Total Size: $total_size
🔧 Mounted: $(if [[ "$is_mounted" == true ]]; then echo "YES"; else echo "NO"; fi)"

    # Build summary without detailed contents for main dialog
    local summary_result="$analysis_result"
    
    # Add detailed contents to full analysis
    analysis_result="$analysis_result

📋 DETAILED CONTENTS:
$content_preview"

    echo "$analysis_result"
    
    # Show summary first
    show_info "Mount Point Analysis Complete!

$summary_result" 5
    
    # Show detailed contents in separate dialog if there are contents
    if [[ -n "$content_preview" ]]; then
        if ask_question "View detailed directory contents?"; then
            zenity --text-info \
                --title="$WINDOW_TITLE - Detailed Contents: $mount_path" \
                --width=800 --height=600 \
                --filename=<(echo "📋 DETAILED CONTENTS OF: $mount_path

$content_preview") 2>/dev/null || \
            show_info "📋 DETAILED CONTENTS:

$content_preview" 10
        fi
    fi
    
    # Also send to notification system
    notify "Mount point analyzed: $file_count files, $dir_count directories, $total_size total" true
    
    # Export for use in dialogs
    export MOUNT_ANALYSIS="$analysis_result"
    export MOUNT_SUMMARY="$summary_result"
    export MOUNT_CONTENT_PREVIEW="$content_preview"
    export MOUNT_FILE_COUNT="$file_count"
    export MOUNT_DIR_COUNT="$dir_count"
    export MOUNT_IS_MOUNTED="$is_mounted"
    
    return 0
}

# Enhanced mount point selector with detailed analysis
select_mount_point() {
    local mount_type="$1"  # "SMB" or "SSH"
    local default_path="$2"
    local selected_path=""
    
    echo "🎯 Starting mount point selection for $mount_type"
    show_info "🎯 Starting mount point selection for $mount_type" 2
    
    while true; do
        # Get mount point from user
        selected_path=$(zenity --entry \
            --title="$WINDOW_TITLE - $mount_type Mount Point" \
            --text="Enter local mount point for $mount_type:

📁 Default: $default_path
💡 Tip: Use ~ for home directory
🔧 Path will be resolved and analyzed

Enter path:" \
            --entry-text="$default_path" \
            --width=600 2>/dev/null)
        
        # Check if user canceled
        if [[ -z "$selected_path" ]]; then
            echo "❌ User canceled mount point selection"
            show_info "❌ Mount point selection canceled" 3
            return 1
        fi
        
        echo "📍 User selected: $selected_path"
        show_info "📍 Selected path: $selected_path" 2
        
        # Expand ~ to home directory
        selected_path="${selected_path/#\~/$HOME}"
        echo "🏠 Expanded path: $selected_path"
        
        # Resolve symbolic links
        if [[ -e "$selected_path" ]]; then
            selected_path=$(readlink -f "$selected_path")
            echo "🔗 Resolved path: $selected_path"
            show_info "🔗 Resolved to: $selected_path" 2
        fi
        
        # Create directory if it doesn't exist
        if [[ ! -d "$selected_path" ]]; then
            echo "📁 Creating directory: $selected_path"
            show_info "📁 Creating directory: $selected_path" 2
            if mkdir -p "$selected_path" 2>/dev/null; then
                echo "✅ Directory created successfully"
                show_info "✅ Directory created successfully" 2
                play_success_sound
            else
                echo "❌ Failed to create directory"
                show_error "Failed to create directory: $selected_path
                
Please check permissions or choose a different location."
                continue
            fi
        fi
        
        # Analyze the mount point
        echo "🔍 Analyzing mount point..."
        show_info "🔍 Starting mount point analysis..." 2
        
        if analyze_mount_point "$selected_path"; then
            echo "✅ Mount point analysis completed"
            
            # Show analysis to user and ask for confirmation
            local user_choice
            user_choice=$(zenity --list --radiolist \
                --title="$WINDOW_TITLE - Mount Point Analysis" \
                --text="$MOUNT_SUMMARY

🤔 What would you like to do?" \
                --width=800 --height=600 \
                --column="Select" --column="Action" --column="Description" \
                TRUE "use_existing" "Use this mount point as-is" \
                FALSE "mount_new" "Mount $mount_type filesystem here" \
                FALSE "view_contents" "View detailed contents first" \
                FALSE "choose_different" "Choose a different mount point" 2>/dev/null)
            
            case "$user_choice" in
                "use_existing")
                    echo "✅ User chose to use existing mount point"
                    show_info "✅ Using existing mount point: $selected_path

$MOUNT_SUMMARY" 5
                    export SELECTED_MOUNT_PATH="$selected_path"
                    export MOUNT_ACTION="use_existing"
                    export NEED_UNMOUNT=false
                    play_success_sound
                    return 0
                    ;;
                "mount_new")
                    echo "🔧 User chose to mount new filesystem"
                    show_info "🔧 Preparing to mount $mount_type filesystem at: $selected_path" 3
                    export SELECTED_MOUNT_PATH="$selected_path"
                    export MOUNT_ACTION="mount_new"
                    return 0
                    ;;
                "view_contents")
                    echo "👁️ User wants to view detailed contents"
                    if [[ -n "$MOUNT_CONTENT_PREVIEW" ]]; then
                        zenity --text-info \
                            --title="$WINDOW_TITLE - Detailed Contents: $selected_path" \
                            --width=900 --height=700 \
                            --filename=<(echo "📋 DETAILED CONTENTS OF: $selected_path

$MOUNT_CONTENT_PREVIEW") 2>/dev/null || \
                        show_info "📋 DETAILED CONTENTS:

$MOUNT_CONTENT_PREVIEW" 15
                    else
                        show_info "No detailed contents available" 3
                    fi
                    continue  # Go back to choice dialog
                    ;;
                "choose_different")
                    echo "🔄 User chose to select different mount point"
                    show_info "🔄 Selecting different mount point..." 2
                    continue
                    ;;
                *)
                    echo "❌ Invalid choice or user canceled"
                    show_info "❌ Mount point selection canceled" 3
                    return 1
                    ;;
            esac
        else
            echo "❌ Mount point analysis failed"
            show_error "Failed to analyze mount point: $selected_path
            
This could indicate permission issues or the path is not accessible."
            continue
        fi
    done
}

# Welcome message
show_info "🎵 Spotify Downloader & ISO Creator Enhanced 🎵

Features:
• Download Spotify playlists
• Create ISO files
• File management options
• Remote storage upload
• Smart cleanup options

Ready to start?" 5

# Load SPOTIPY environment

sudo chmod +rwx ./SPOTIPY
. ./SPOTIPY

echo "Setting up environment..."

# Create venv if needed
if [[  -d ".venv" ]]; then

    ./clean_dir

fi

echo "Creating Python virtual environment..."

sleep 2

echo "Set Permissions: "

sleep 1

sudo chown -hR "$USER":"$USER" ./
sudo chown -hR "$USER":"$USER" "$HOME"/Music

sleep 1

echo "Continuing... "

sleep 2

sudo apt install python3.*-venv -y
python3 -m venv venv
notify "Virtual environment created" true


# Check and install dependencies
echo "Checking dependencies..."
NEED_INSTALL=false

if ! venv/bin/pip show spotify_dl >/dev/null 2>&1; then
    NEED_INSTALL=true
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
    if ask_question "ffmpeg is required but not installed. Install it now?"; then
        echo "Installing ffmpeg..."
        sudo apt update && sudo apt install -y ffmpeg
    else
        show_warning "ffmpeg is required for audio processing!"
    fi
fi

if [[ "$NEED_INSTALL" == true ]]; then
    echo "Installing Python dependencies..."

    python3 -m venv ./venv
    venv/bin/pip install --upgrade pip
    venv/bin/pip install spotify_dl
    show_info "Dependencies installed!" 5
    notify "Dependencies installed" true
else
    show_info "All dependencies ready!" 5
    notify "All dependencies ready" true
fi

# Get output directory
CURRENT_USER=$(whoami)
USER_MUSIC_DIR="$HOME/Music"

if ask_question "Use default music directory ($USER_MUSIC_DIR)?"; then
    echo "I will need to santize to make sure...sorry."
    sleep 3
    OUTPUT_DIR="$USER_MUSIC_DIR"
    COMMAND=$(sudo chown -hR "$USER":"$USER" "$USER_MUSIC_DIR"/)
    echo "This is happening next: $COMMAND"
    echo "$COMMAND"
    sleep 2
else
    OUTPUT_DIR=$(zenity --file-selection --directory --title="Select Output Directory" 2>/dev/null)
    if [[ -z "$OUTPUT_DIR" ]]; then
        OUTPUT_DIR="$USER_MUSIC_DIR"
        show_info "Using default directory: $USER_MUSIC_DIR" 3;
        echo "Done... it/'s your/'s"
        sleep 2
    fi
fi

notify "Output directory: $OUTPUT_DIR"

# Get playlist URLs
echo "Getting playlist URLs..."
PLAYLIST_URLS=()

while true; do
    URL_INPUT=$(zenity --entry --title="$WINDOW_TITLE" --text="Enter Spotify playlist URL(s):

You can enter multiple URLs separated by spaces.
Each URL should start with: https://open.spotify.com/playlist/

Click OK when done, Cancel to skip." --width=800 2>/dev/null)

    if [[ -z "$URL_INPUT" ]]; then
        break
    fi

    # Split the input by spaces and process each URL
    read -ra URL_ARRAY <<< "$URL_INPUT"
    INVALID_URLS=()
    
    for URL in "${URL_ARRAY[@]}"; do
        # Skip empty entries
        [[ -z "$URL" ]] && continue
        
        if [[ "$URL" =~ ^https://open\.spotify\.com/playlist/ ]]; then
            PLAYLIST_URLS+=("$URL")
            echo "Added playlist: $URL"
        else
            INVALID_URLS+=("$URL")
        fi
    done
    
    if [[ ${#INVALID_URLS[@]} -gt 0 ]]; then
        INVALID_LIST=$(printf '%s\n' "${INVALID_URLS[@]}")
        show_error "Invalid Spotify URL(s):
$INVALID_LIST

Must start with: https://open.spotify.com/playlist/

Please enter valid URLs."
        # Continue the loop to ask for new URLs
    else
        # All URLs were valid, show success and break
        show_info "Added ${#PLAYLIST_URLS[@]} playlist(s) successfully!" 5
        notify "Added ${#PLAYLIST_URLS[@]} playlist(s) successfully" true
        break
    fi
done

if [[ ${#PLAYLIST_URLS[@]} -eq 0 ]]; then
    show_error "No playlists provided. Exiting."
    exit 1
fi

# Get download options
echo "Getting download options..."
OPTIONS=""
if ask_question "Use -w option and keep files already downloaded?"; then
    OPTIONS="$OPTIONS -w"
fi

if ask_question "Show verbose download output?"; then
    OPTIONS="$OPTIONS --verbose"
fi

# Setup output directory
echo "Setting up output directory..."
if [[ ! -d "$OUTPUT_DIR" ]]; then
    mkdir -p "$OUTPUT_DIR"
    notify "Created directory: $OUTPUT_DIR" true
fi

# Ensure correct permissions
sudo chown -R "$CURRENT_USER" "$OUTPUT_DIR" 2>/dev/null || true
sudo chmod +rwx "$OUTPUT_DIR" 2>/dev/null || true

# Download playlists
echo "Starting downloads..."
notify "Starting downloads..." true

TOTAL_PLAYLISTS=${#PLAYLIST_URLS[@]}
CURRENT_PLAYLIST=0

for URL in "${PLAYLIST_URLS[@]}"; do
    ((CURRENT_PLAYLIST++))
    echo "Processing playlist $CURRENT_PLAYLIST/$TOTAL_PLAYLISTS"
    
    show_info "Downloading playlist $CURRENT_PLAYLIST/$TOTAL_PLAYLISTS
    
This may take several minutes..." 3
    
    # Simple, direct download command
    DOWNLOAD_CMD="venv/bin/spotify_dl -l '$URL' -o '$OUTPUT_DIR' -s y -k $OPTIONS"
    
    echo "Executing: $DOWNLOAD_CMD"
    
    if eval "$DOWNLOAD_CMD"; then
        echo "Download $CURRENT_PLAYLIST completed successfully"
        notify "Playlist $CURRENT_PLAYLIST/$TOTAL_PLAYLISTS completed" true
        show_info "✅ Playlist $CURRENT_PLAYLIST completed!" 5
    else
        echo "Download $CURRENT_PLAYLIST failed"
        show_error "Failed to download playlist $CURRENT_PLAYLIST. Check connection and credentials."
    fi
done

show_info "All downloads completed!" 5
notify "All downloads completed" true

# Create ISOs
echo "Checking for directories to create ISOs..."
ISO_CREATED=0
ISO_DIRS=()

# Find directories with MP3 files
for SUBDIR in "$OUTPUT_DIR"/*/; do
    if [[ -d "$SUBDIR" ]]; then
        MP3_COUNT=$(find "$SUBDIR" -name "*.mp3" 2>/dev/null | wc -l)
        if [[ $MP3_COUNT -gt 0 ]]; then
            ISO_DIRS+=("$SUBDIR")
        fi
    fi
done

echo "Found ${#ISO_DIRS[@]} directories with music files"

if [[ ${#ISO_DIRS[@]} -gt 0 ]]; then
    if ask_question "Create ISO files for ${#ISO_DIRS[@]} playlist folder(s)?"; then
        echo "Creating ISO files..."
        
        for SUBDIR in "${ISO_DIRS[@]}"; do
            SUBDIR_NAME=$(basename "${SUBDIR%/}")
            ISO_NAME="$SUBDIR/${SUBDIR_NAME}.iso"
            
            if [[ -f "$ISO_NAME" ]]; then
                echo "ISO already exists: $SUBDIR_NAME.iso"
                continue
            fi
            
            echo "Creating ISO for: $SUBDIR_NAME"
            show_info "Creating ISO: $SUBDIR_NAME" 2
            
            if command -v genisoimage >/dev/null 2>&1; then
                if genisoimage -quiet -o "$ISO_NAME" -R -J "$SUBDIR"; then
                    ((ISO_CREATED++))
                    echo "ISO created: $ISO_NAME"
                    notify "ISO created: $SUBDIR_NAME.iso" true
                else
                    echo "Failed to create ISO: $ISO_NAME"
                    show_error "Failed to create ISO for: $SUBDIR_NAME"
                fi
            else
                show_error "genisoimage not found. Install with: sudo apt install genisoimage"
                break
            fi
        done
        
        show_info "ISO creation completed! Created $ISO_CREATED ISO files." 5
        notify "ISO creation completed" true
    fi
fi

# File transfer options
if ask_question "Copy files to another location?"; then
    echo "Setting up file transfer..."
    
    # Simple destination selection
    DEST_TYPE=$(zenity --list --radiolist --title="$WINDOW_TITLE" --text="Choose destination:" \
        --width=500 --height=300 \
        --column="Select" --column="Type" \
        TRUE "Local directory" \
        FALSE "SMB share" \
        FALSE "SSH filesystem" 2>/dev/null)
    
    DESTINATION_PATH=""
    NEED_UNMOUNT=false
    
    case "$DEST_TYPE" in
    "Local directory")
        DESTINATION_PATH=$(zenity --file-selection --directory --title="Select Destination" 2>/dev/null)
        ;;
    "SMB share")
        if select_mount_point "SMB" "/tmp/smb_mount"; then
            if [[ "$MOUNT_ACTION" == "use_existing" ]]; then
                DESTINATION_PATH="$SELECTED_MOUNT_PATH"
                NEED_UNMOUNT=false
            elif [[ "$MOUNT_ACTION" == "mount_new" ]]; then
                # Get SMB credentials and mount
                SMB_SERVER=$(zenity --entry --title="SMB Server" --text="Enter server (//server/share):" 2>/dev/null)
                SMB_USER=$(zenity --entry --title="SMB Username" --text="Enter username:" 2>/dev/null)
                SMB_PASS=$(zenity --password --title="SMB Password" 2>/dev/null)
                
                if [[ -n "$SMB_SERVER" && -n "$SMB_USER" && -n "$SMB_PASS" ]]; then
                    if sudo mount -t cifs "$SMB_SERVER" "$SELECTED_MOUNT_PATH" -o username="$SMB_USER",password="$SMB_PASS"; then
                        # Verify mount worked by checking contents
                        if analyze_mount_point "$SELECTED_MOUNT_PATH"; then
                            DESTINATION_PATH="$SELECTED_MOUNT_PATH"
                            NEED_UNMOUNT=true
                            show_info "SMB share mounted successfully!"

Mount point: "$SELECTED_MOUNT_PATH"
"$MOUNT_ANALYSIS" 5
                            notify "SMB share mounted successfully" true
                        else
                            show_error "Mount succeeded but contents not accessible"
                        fi
                    else
                        show_error "Failed to mount SMB share"
                    fi
                fi
            fi
        fi
        ;;
    "SSH filesystem")
        if select_mount_point "SSH" "/tmp/ssh_mount"; then
            if [[ "$MOUNT_ACTION" == "use_existing" ]]; then
                DESTINATION_PATH="$SELECTED_MOUNT_PATH"
                NEED_UNMOUNT=false
            elif [[ "$MOUNT_ACTION" == "mount_new" ]]; then
                # Get SSH credentials and mount
                SSH_REMOTE=$(zenity --entry --title="SSH Remote" --text="Enter remote (user@host:/path):" 2>/dev/null)
                
                if [[ -n "$SSH_REMOTE" ]]; then
                    if sshfs "$SSH_REMOTE $SELECTED_MOUNT_PATH"; then
                        # Verify mount worked by checking contents
                        if analyze_mount_point "$SELECTED_MOUNT_PATH"; then
                            DESTINATION_PATH="$SELECTED_MOUNT_PATH"
                            NEED_UNMOUNT=true
                            show_info "SSH filesystem mounted successfully!

Mount point: $SELECTED_MOUNT_PATH
$MOUNT_ANALYSIS" 5
                            notify "SSH filesystem mounted successfully" true
                        else
                            show_error "Mount succeeded but contents not accessible"
                        fi
                    else
                        show_error "Failed to mount SSH filesystem"
                    fi
                fi
            fi
        fi
        ;;
    esac
    
    if [[ -n "$DESTINATION_PATH" ]]; then
        # Show what will be transferred before asking for confirmation
        echo "Scanning files for transfer..."
        TRANSFER_PREVIEW=""
        
        # Count and list what's available
        ISO_COUNT=$(find "$OUTPUT_DIR" -name "*.iso" 2>/dev/null | wc -l)
        MP3_DIRS=$(find "$OUTPUT_DIR" -type d -name "*" 2>/dev/null | grep -c "^$OUTPUT_DIR$" )
        
        if [[ $ISO_COUNT -gt 0 ]]; then
            TRANSFER_PREVIEW="$TRANSFER_PREVIEW
📀 ISO Files Available: $ISO_COUNT"
            ISO_LIST=$(find "$OUTPUT_DIR" -name "*.iso" -exec basename {} \; 2>/dev/null | head -5)
            TRANSFER_PREVIEW="$TRANSFER_PREVIEW
$ISO_LIST"
            if [[ $ISO_COUNT -gt 5 ]]; then
                TRANSFER_PREVIEW="$TRANSFER_PREVIEW
... and $((ISO_COUNT - 5)) more"
            fi
        fi
        
        if [[ $MP3_DIRS -gt 0 ]]; then
            TRANSFER_PREVIEW="$TRANSFER_PREVIEW

🎵 Music Directories Available: $MP3_DIRS"
            DIR_LIST=$(find "$OUTPUT_DIR" -maxdepth 1 -type d ! -path "$OUTPUT_DIR" -exec basename {} \; 2>/dev/null | head -5)
            TRANSFER_PREVIEW="$TRANSFER_PREVIEW
$DIR_LIST"
            if [[ $MP3_DIRS -gt 5 ]]; then
                TRANSFER_PREVIEW="$TRANSFER_PREVIEW
... and $((MP3_DIRS - 5)) more"
            fi
        fi
        
        # Simple transfer type selection with preview
        TRANSFER_WHAT=$(zenity --list --radiolist --title="$WINDOW_TITLE" --text="What to transfer to: $DESTINATION_PATH
        
Files will be kept in their subdirectories.
$TRANSFER_PREVIEW" \
            --width=700 --height=500 \
            --column="Select" --column="Type" \
            FALSE "ISO files only" \
            FALSE "MP3 files only" \
            TRUE "Both ISO and MP3" 2>/dev/null)
        
        echo "Transferring files to: $DESTINATION_PATH"
        show_info "Transferring files with directory structure..." 5
        
        case "$TRANSFER_WHAT" in
        "ISO files only")
            # Copy ISO files keeping directory structure
            if rsync -haruv --include="*/" --include="*.iso" --exclude="*" "$OUTPUT_DIR"/ "$DESTINATION_PATH"/ 2>/dev/null; then
                echo "ISO files transferred successfully with directory structure"
                notify "ISO files transferred successfully" true
            else
                echo "Transfer failed, trying with sudo..."
                if ! sudo rsync -haruv --include="*/" --include="*.iso" --exclude="*" "$OUTPUT_DIR"/ "$DESTINATION_PATH"/ 2>/dev/null; then
                    show_error "Failed to transfer ISO files even with sudo privileges"
                fi
            fi
            ;;
        "MP3 files only")
            # Copy MP3 files keeping directory structure
            if rsync -haruv --include="*/" --include="*.mp3" --exclude="*" "$OUTPUT_DIR"/ "$DESTINATION_PATH"/ 2>/dev/null; then
                echo "MP3 files transferred successfully with directory structure"
                notify "MP3 files transferred successfully" true
            else
                echo "Transfer failed, trying with sudo..."
                if ! sudo rsync -haruv --include="*/" --include="*.mp3" --exclude="*" "$OUTPUT_DIR"/ "$DESTINATION_PATH"/ 2>/dev/null; then
                    show_error "Failed to transfer MP3 files even with sudo privileges"
                fi
            fi
            ;;
        "Both ISO and MP3")
            # Copy both keeping directory structure
            if rsync -haruv --include="*/" --include="*.iso" --include="*.mp3" --exclude="*" "$OUTPUT_DIR"/ "$DESTINATION_PATH"/ 2>/dev/null; then
                echo "Files synchronized successfully with directory structure"
                notify "Files synchronized successfully" true
            else
                echo "Transfer failed, trying with sudo..."
                if ! sudo rsync -haruv --include="*/" --include="*.iso" --include="*.mp3" --exclude="*" "$OUTPUT_DIR"/ "$DESTINATION_PATH"/ 2>/dev/null; then
                    show_error "Failed to synchronize files even with sudo privileges"
                fi
            fi
            ;;
        esac
        
        show_info "File transfer completed!" 5
        notify "Files transferred successfully" true
        
        # Unmount if needed
        if [[ "$NEED_UNMOUNT" == true ]]; then
            if ask_question "Unmount $DESTINATION_PATH?"; then
                if sudo umount "$DESTINATION_PATH" 2>/dev/null || umount "$DESTINATION_PATH" 2>/dev/null; then
                    show_info "Successfully unmounted" 5
                    notify "Successfully unmounted" true
                else
                    show_warning "Could not unmount $DESTINATION_PATH"
                fi
            fi
        fi
    fi
fi

# Final cleanup
CLEANUP=$(zenity --list --radiolist --title="$WINDOW_TITLE" --text="Final cleanup:" \
    --width=500 --height=300 \
    --column="Select" --column="Action" \
    TRUE "Keep all files" \
    FALSE "Delete everything" \
    FALSE "Secure wipe" 2>/dev/null)

case "$CLEANUP" in
"Delete everything")
    if ask_question "⚠️ DELETE everything in $OUTPUT_DIR?"; then
        echo "Cleaning up directory..."
        rm -rf "$OUTPUT_DIR"
        show_info "Directory cleaned!" 5
        notify "Directory cleaned" true
    fi
    ;;
"Secure wipe")
    if ask_question "🔥 SECURE WIPE $OUTPUT_DIR? THIS CANNOT BE UNDONE!"; then
        CONFIRM=$(zenity --entry --title="Confirm" --text="Type 'WIPE' to confirm:" --hide-text 2>/dev/null)
        if [[ "$CONFIRM" == "WIPE" ]]; then
            echo "Secure wiping... This will take a long time!"
            show_info "Secure wipe in progress..." 5
            find "$OUTPUT_DIR" -type f -exec shred -vz -n 3 -u {} +
            rm -rf "$OUTPUT_DIR"
            show_info "Secure wipe completed!" 5
            notify "Secure wipe completed" true
        fi
    fi
    ;;
"Keep all files")
    show_info "Files preserved in: $OUTPUT_DIR" 5
    ;;
esac

# Final summary
SUMMARY="🎉 Process Complete! 🎉

Summary:
• Playlists processed: ${#PLAYLIST_URLS[@]}
• ISO files created: $ISO_CREATED
• Output directory: $OUTPUT_DIR

Thank you for using Spotify Downloader Enhanced!"

show_info "$SUMMARY" 5
notify "All operations completed successfully!" true

# Final success sound for completion
play_success_sound

echo "🎵 Spotify Downloader Enhanced - Process completed! 🎵"
