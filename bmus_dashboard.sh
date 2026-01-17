#!/bin/bash
# Dashboard Generator v.25.1
# This script generates the dashboard with Dark/Light mode support.

generate_dashboard() {
    out="$1"
    backup_size="$2"
    file_count="$3"
    dir_count="$4"
    backup_pfad="$5"
    nas_ip="$6"
    master_ip="$7"
    deleted_count="$8"
    copy_errors="$9"
    verify_errors="${10}"
    start_ts="${11}"
    end_ts="${12}"
    duration_s="${13}"
    logfile="${14}"
    dedup_logfile="${15}"
    deleted_folders="${16}"
    kept_folders="${17}"
    resource_logfile="${18}"
    ram_total_mb="${19}"
    dedup_saved_space="${20}"
    avg_duration="${21}"      
    success_rate="${22}"       
    max_spike="${23}" 
    max_new_dirs="${24:-50}" 
    raw_bytes="${25:-0}" 
    retention_days="${26:-0}"
    enc_retention_days="${27:-0}"  
    cloud_backup_enabled="${28:-0}"
    cloud_status="${29:-}"

# --- [ CLOUD WIDGET LOGIC ] ---
    CLOUD_WIDGET_HTML=""
    if [ "$cloud_backup_enabled" -eq 1 ]; then
        case "$cloud_status" in
            "SUCCESS")
                c_val="$DASH_CLOUD_SUCCESS"
                c_class="success"
                ;;
            "SKIPPED_DRYRUN")
                c_val="$DASH_CLOUD_DRYRUN"
                c_class="" 
                ;;
            "ERROR_SPACE")
                c_val="$DASH_CLOUD_SPACE"
                c_class="error"  
                ;;
            "ERROR_CONFIG")
                c_val="$DASH_CLOUD_CONFIG_ERROR"
                c_class="error"
                ;;
            *)
                c_val="$DASH_CLOUD_ERROR"
                c_class="error"
                ;;
        esac
        # CSS class .stat-card is already defined in your template
        CLOUD_WIDGET_HTML="<div class=\"stat-card $c_class\"><div class=\"label\">$DASH_CLOUD_TITLE</div><div class=\"value\">$c_val</div></div>"
    fi

    # Convert Epoch times to human-readable format
    start_human=$(date -d "@$start_ts" '+%d.%m.%Y %H:%M:%S')
    end_human=$(date -d "@$end_ts" '+%d.%m.%Y %H:%M:%S')

    # Determine status color
    if [ "$copy_errors" -gt 0 ] || [ "$verify_errors" -gt 0 ]; then
        status_color="#ef4444"
        status_text="$DASH_STATUS_ERROR"
    else
        status_color="#10b981"
        status_text="$DASH_STATUS_SUCCESS"
    fi

    HISTORY_CSV="$HISTORY_PATH"
    DASHBOARD_MODE="${DASHBOARD_MODE:-simple}"

      
    # Extract changed files from logfile
    CHANGED_FILES_HTML=""
    NEW_DIRS_HTML=""

    if [ -f "$logfile" ]; then
         # 1. Normalize variable names (fallback if _START is missing)
        HEADER_DIFF="${LOG_HEADER_DIFF_START:-$LOG_HEADER_DIFF}"
        HEADER_DIRS="${LOG_HEADER_NEW_DIRS_START:-$LOG_HEADER_NEW_DIRS}"

        # 2. Prepare regex escaping for sed
        ESCAPED_NEW_FILE_PATTERN=$(echo "$LOG_PREFIX_NEW_FILE" | sed 's/[]\/$*.^[]/\\&/g')
        ESCAPED_MOD_FILE_PATTERN=$(echo "$LOG_PREFIX_MOD_FILE" | sed 's/[]\/$*.^[]/\\&/g')
        ESCAPED_NEW_DIR_PATTERN=$(echo "$LOG_PREFIX_NEW_DIR" | sed 's/[]\/$*.^[]/\\&/g')

         # 3. Extract section “Changed files”
         # grep -F -e ... ensures that brackets [] in the search text are not a problem
        CHANGED_SECTION=$(sed -n "/$HEADER_DIFF/,/$HEADER_DIRS/p" "$logfile" | grep -F -e "$LOG_PREFIX_NEW_FILE" -e "$LOG_PREFIX_MOD_FILE")
        
        if [ -n "$CHANGED_SECTION" ]; then
            CHANGED_FILES_HTML="<div class=\"file-list\">"
            while IFS= read -r line; do
                if echo "$line" | grep -F -q "$LOG_PREFIX_NEW_FILE"; then
                    FILE_PATH=$(echo "$line" | sed "s/^$ESCAPED_NEW_FILE_PATTERN \(.*\) (\(.*\))/\1/")
                    FILE_SIZE=$(echo "$line" | sed "s/^$ESCAPED_NEW_FILE_PATTERN \(.*\) (\(.*\))/\2/")
                    CHANGED_FILES_HTML+="<div class=\"file-item new\"><span class=\"icon\">✓</span><span class=\"path\">$FILE_PATH</span><span class=\"size\">$FILE_SIZE</span></div>"
                elif echo "$line" | grep -F -q "$LOG_PREFIX_MOD_FILE"; then
                    FILE_PATH=$(echo "$line" | sed "s/^$ESCAPED_MOD_FILE_PATTERN \(.*\) (\(.*\))/\1/")
                    FILE_SIZE=$(echo "$line" | sed "s/^$ESCAPED_MOD_FILE_PATTERN \(.*\) (\(.*\))/\2/")
                    CHANGED_FILES_HTML+="<div class=\"file-item modified\"><span class=\"icon\">↻</span><span class=\"path\">$FILE_PATH</span><span class=\"size\">$FILE_SIZE</span></div>"
                fi
            done <<< "$(echo "$CHANGED_SECTION" | head -n "${max_new_dirs:-50}")"
            CHANGED_FILES_HTML+="</div>"
        fi
        
        # 4. Extract section “New directories”
        # We read to the end of the file ($p), as the end marker is often missing
        DIRS_SECTION=$(sed -n "/$HEADER_DIRS/,\$p" "$logfile" | grep -F "$LOG_PREFIX_NEW_DIR")
        
        if [ -n "$DIRS_SECTION" ]; then
            NEW_DIRS_HTML="<div class=\"dir-list\">"
            while IFS= read -r line; do
                DIR_PATH=$(echo "$line" | sed "s/^$ESCAPED_NEW_DIR_PATTERN //")
                NEW_DIRS_HTML+="<div class=\"dir-item\"><span class=\"icon\">📁</span><span class=\"path\">$DIR_PATH</span></div>"
            done <<< "$(echo "$DIRS_SECTION" | head -n "${max_new_dirs:-50}")"
            NEW_DIRS_HTML+="</div>"
        fi
    fi
    # --- ---

    # Generate HTML document
    {
        cat <<'EOF'
<!doctype html>
<html lang="DASH_LANG_PLACEHOLDER">
<head>
    <meta charset='utf-8'>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DASH_TITLE_PLACEHOLDER</title>
    <style>
        /* ========================================= */
        /* THEME VARIABLES (CSS Custom Properties)   */
        /* ========================================= */
        :root {
            /* Dark Mode (Default) */
            --bg-body: #1a1a1a;
            --bg-container: #2d2d2d;
            --bg-card: #252525;
            --bg-hover: #202020;
            --text-main: #e5e5e5;
            --text-muted: #9ca3af; /* Gray-400 */
            --text-heading: #f5f5f5;
            --border-color: #404040;
            --border-accent: #525252;
            --shadow: rgba(0, 0, 0, 0.3);
            
            /* Chart Colors for Dark Mode */
            --chart-grid: #404040;
            --chart-text: #9ca3af;
        }

       
        [data-theme="light"] {
            /* Light Mode Overrides */
            --bg-body: #d3d6de;       
            --bg-container: #f3f4f6;  
            --bg-card: #E5E7EB;       
            --bg-hover: #e5e7eb;      
            --text-main: #1f2937;     
            --text-muted: #4b5563;    
            --text-heading: #000000; 
            --border-color: #e5e7eb;  
            --border-accent: #d1d5db;
            --bg-log: #E5E7EB;
            --text-log: #000000; 
            --shadow: rgba(0, 0, 0, 0.1);

            /* Chart Colors for Light Mode */
            --chart-grid: #d1d5db;
            --chart-text: #000000;
        }

        /* Reset & basic layout */
        * { margin: 0; padding: 0; box-sizing: border-box; transition: background-color 0.3s, color 0.3s, border-color 0.3s; }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            background: var(--bg-body);
            color: var(--text-main);
            line-height: 1.6;
            padding: 20px;
            font-size: 15px;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: var(--bg-container);
            border-radius: 12px;
            padding: 30px;
            box-shadow: 0 4px 6px var(--shadow);
            position: relative;
        }

        /* Theme Toggle Button */
        .theme-toggle {
            position: absolute;
            top: 30px;
            right: 30px;
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            color: var(--text-main);
            width: 40px;
            height: 40px;
            border-radius: 50%;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 20px;
            transition: transform 0.2s;
            z-index: 10;
        }
        .theme-toggle:hover {
            transform: scale(1.1);
            background: var(--bg-hover);
        }
        
        /* Headings */
        h1 {
            color: var(--text-heading);
            font-size: 28px;
            font-weight: 600;
            margin-bottom: 10px;
            padding-bottom: 15px;
            border-bottom: 2px solid var(--border-color);
        }
        
        h2 {
            color: var(--text-heading);
            font-size: 20px;
            font-weight: 600;
            margin-top: 30px;
            margin-bottom: 15px;
        }
        
        /* Status Banner */
        .status-banner {
            background: STATUS_COLOR_PLACEHOLDER;
            color: white;
            padding: 15px 20px;
            border-radius: 8px;
            font-size: 18px;
            font-weight: 600;
            text-align: center;
            margin: 20px 0;
        }
        
        /* Info Sections */
        .info-section {
            background: var(--bg-card);
            padding: 20px;
            border-radius: 8px;
            margin: 20px 0;
            border-left: 3px solid var(--border-accent);
        }
        
        .info-section p {
            color: var(--text-muted);
            margin: 8px 0;
            font-size: 14px;
        }
        
        .info-section strong {
            color: var(--text-main);
            font-weight: 600;
        }
        
        /* Statistics Cards */
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin: 20px 0;
        }
        
        .stat-card {
            background: var(--bg-card);
            padding: 18px;
            border-radius: 8px;
            border-left: 3px solid var(--border-accent);
        }
        
        .stat-card .label {
            color: var(--text-muted);
            font-size: 12px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin-bottom: 8px;
        }
        
        .stat-card .value {
            color: var(--text-heading);
            font-size: 24px;
            font-weight: 600;
        }
        
        .stat-card.error .value { color: #ef4444; }
        .stat-card.success .value { color: #10b981; }
        
        /* Scrolling enabled */
        .file-list, .dir-list {
            background: var(--bg-card);
            padding: 15px;
            border-radius: 8px;
            margin: 15px 0;
            max-height: 350px;      
            overflow-y: auto;        
            border: 1px solid var(--border-color);
        }

        /* Scrollbar Styling (match Dark Mode) */
        .file-list::-webkit-scrollbar, .dir-list::-webkit-scrollbar { width: 8px; }
        .file-list::-webkit-scrollbar-track, .dir-list::-webkit-scrollbar-track { background: var(--bg-card); border-radius: 4px; }
        .file-list::-webkit-scrollbar-thumb, .dir-list::-webkit-scrollbar-thumb { background: var(--border-accent); border-radius: 4px; }
        .file-list::-webkit-scrollbar-thumb:hover, .dir-list::-webkit-scrollbar-thumb:hover { background: var(--text-muted); }
       
        
        .file-item, .dir-item {
            display: flex;
            align-items: center;
            padding: 12px;
            margin: 8px 0;
            background: var(--bg-body);
            border-radius: 6px;
            border-left: 3px solid var(--border-accent);
            transition: all 0.2s;
        }
        
        .file-item:hover, .dir-item:hover {
            background: var(--bg-hover);
            transform: translateX(5px);
        }
        
        .file-item.new { border-left-color: #10b981; }
        .file-item.modified { border-left-color: #3b82f6; }
        
        .file-item .icon, .dir-item .icon {
            font-size: 20px;
            margin-right: 12px;
            min-width: 30px;
            text-align: center;
        }
        
        .file-item.new .icon { color: #10b981; }
        .file-item.modified .icon { color: #3b82f6; }
        .dir-item .icon { color: #f59e0b; }
        
        .file-item .path, .dir-item .path {
            flex: 1;
            color: var(--text-main);
            font-family: 'Courier New', Courier, monospace;
            font-size: 13px;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
        }
        
        .file-item .size {
            color: var(--text-muted);
            font-size: 12px;
            font-weight: 600;
            margin-left: 15px;
            min-width: 80px;
            text-align: right;
        }
         
        /* Deduplicated files styling */
        .file-item.dedup { border-left-color: #a855f7; }
        .file-item.dedup .icon { color: #a855f7; }
        
        .file-item .dedup-info {
            color: #a855f7;
            font-size: 11px;
            font-weight: 600;
            margin-left: 10px;
            margin-right: 10px;
            min-width: 60px;
        }
        
        .dedup-info {
            background: var(--bg-card);
            padding: 10px 15px;
            border-radius: 6px;
            margin: 10px 0;
            border-left: 3px solid #a855f7;
        }
        
        .dedup-info p {
            color: var(--text-heading);
            margin: 0;
            font-size: 14px;
        }
        
        .dedup-note {
            background: var(--bg-body);
            padding: 12px;
            border-radius: 6px;
            margin-top: 10px;
            border: 1px solid var(--border-color);
        }
        
        .dedup-note p {
            color: var(--text-muted);
            margin: 0;
            font-size: 13px;
            font-style: italic;
        }
 
        /* Log Output */
        pre {
            background: var(--bg-log);
            color: var(--text-log);  
            padding: 20px;
            border-radius: 8px;
            overflow-x: auto;
            font-family: 'Courier New', Courier, monospace;
            font-size: 13px;
            line-height: 1.5;
            border: 1px solid var(--border-color);
            max-height: 500px;
            overflow-y: auto;
        }
        
        pre::-webkit-scrollbar { width: 10px; height: 10px; }
        pre::-webkit-scrollbar-track { background: var(--bg-card); border-radius: 5px; }
        pre::-webkit-scrollbar-thumb { background: var(--border-accent); border-radius: 5px; }
        pre::-webkit-scrollbar-thumb:hover { background: #666666; }
        
        /* Timestamp */
        .timestamp {
            text-align: center;
            color: var(--text-muted);
            font-size: 13px;
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid var(--border-color);
        }

        a.donate-link {
        color: var(--text-heading) !important;   /* Black in Light mode, white in Dark mode */
        text-decoration: none;
        font-weight: 600;
        }

         a.donate-link:hover {
         text-decoration: underline;
        }

        .donate-wrapper {
         margin-top: 30px;
         display: flex;
         align-items: center;
         justify-content: center;   
         gap: 8px;                 
         font-size: 16px;
         }
        </style>
EOF

        
        # HTML Body
        cat <<EOF
</head>
<body>
    <div class="container">
        <button id="themeToggle" class="theme-toggle" title="Toggle Dark/Light Mode">
            🌙
        </button>

        <h1>$DASH_H1_TITLE</h1>

        <div class="status-banner">STATUS_TEXT_PLACEHOLDER</div>

        <div class="info-section">
            <p>$DASH_INFO_MASTER_SYSTEM MASTER_IP_PLACEHOLDER</p>
            <p>$DASH_INFO_NAS_TARGET NAS_IP_PLACEHOLDER</p>
            <p>$DASH_INFO_BACKUP_PATH BACKUP_PFAD_PLACEHOLDER</p>
        </div>

        <h2>$DASH_H2_STATS</h2>
        <div class="stats-grid">
            <div class="stat-card">
                <div class="label">$DASH_STAT_BACKUP_SIZE</div>
                <div class="value">BACKUP_SIZE_PLACEHOLDER</div>
            </div>
            <div class="stat-card success">
                <div class="label">$DASH_STAT_NEW_FILES</div>
                <div class="value">FILE_COUNT_PLACEHOLDER</div>
            </div>
            <div class="stat-card success">
                <div class="label">$DASH_STAT_NEW_DIRS</div>
                <div class="value">DIR_COUNT_PLACEHOLDER</div>
            </div>
            <div class="stat-card">
                <div class="label">$DASH_STAT_DELETED_BACKUPS</div>
                <div class="value">DELETED_COUNT_PLACEHOLDER</div>
            </div>
            <div class="stat-card error">
                <div class="label">$DASH_STAT_COPY_ERRORS</div>
                <div class="value">COPY_ERRORS_PLACEHOLDER</div>
            </div>
            <div class="stat-card error">
                <div class="label">$DASH_STAT_VERIFY_ERRORS</div>
                <div class="value">VERIFY_ERRORS_PLACEHOLDER</div>
            </div>
        </div>
EOF

        # Display Top 10 Changes
        if [ -n "$CHANGED_FILES_HTML" ]; then
            cat <<EOF

        <h2>$DASH_H2_TOP10_CHANGES</h2>
        $CHANGED_FILES_HTML
EOF
        fi

        # Display New Directories
        if [ -f "$logfile" ] && grep -q "$LOG_HEADER_NEW_DIRS_START" "$logfile"; then
            if [ -n "$NEW_DIRS_HTML" ]; then
                cat <<EOF

        <h2>$DASH_H2_NEW_DIRS</h2>
        $NEW_DIRS_HTML
EOF
            else
                cat <<EOF

        <h2>$DASH_H2_NEW_DIRS</h2>
        $(printf "$DASH_MSG_NO_NEW_DIRS")
EOF
            fi
        fi
 
        # Log Section
        DASH_H2_LOG_EXCERPT_FORMATTED=$(printf "$DASH_H2_LOG_EXCERPT" "$DASHBOARD_LINE_LOGS")
        
        cat <<EOF

        <h2>$DASH_H2_TIMESTAMPS</h2>
        <div class="info-section">
            <p>$DASH_INFO_START START_HUMAN_PLACEHOLDER</p>
            <p>$DASH_INFO_END END_HUMAN_PLACEHOLDER</p>
            <p>$(printf "$DASH_INFO_DURATION" "DURATION_S_PLACEHOLDER")</p>
        </div>

        <h2>$DASH_H2_LOG_EXCERPT_FORMATTED</h2>
EOF

        if [ -f "$logfile" ]; then
            echo "        <pre>$(tail -n "$DASHBOARD_LINE_LOGS" "$logfile" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')</pre>"
        else
            echo "        $(printf "$DASH_MSG_LOGFILE_NOT_FOUND" "$logfile")"
        fi

        cat <<EOF

        <div class="timestamp">
            $(printf "$DASH_MSG_GENERATED_AT" "GENERATED_AT_PLACEHOLDER")
        </div>
         <div class="donate-wrapper">
       <span class="icon" aria-hidden="true">
        <svg viewBox="0 0 24 24" width="1.4em" height="1.4em"
             xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Herz">
            <path d="M12 21s-7.5-4.93-9.16-8.04C1.83 9.94 4.27 6 7.99 6c1.74 0 3.33.87 4.01 2.18C12.68 6.87 
                     14.27 6 16.01 6 19.73 6 22.17 9.94 21.16 12.96 19.5 16.07 12 21 12 21z" fill="#E53935"/>
        </svg>
        </span>
       <a class="donate-link" href="https://www.back-me-up-scotty.com/docs/what-is-bmus/support/">Donate</a>if you found this useful.<br>
       <a class="donate-link" href="https://www.back-me-up-scotty.com/docs/what-is-bmus/buy-pro-dashboard/">Buy Pro</a>&nbsp;for more stats und graphs.
       </div>
        
        <div class="timestamp">
            עַם יִשְׂרָאֵל חַי 🇮🇱 | 🇺🇦 Slava Ukraini
        </div>
    </div>
    
    <script>
        // Theme Toggle Logic
        const toggleBtn = document.getElementById('themeToggle');
        const html = document.documentElement;

        // Load saved theme
        const savedTheme = localStorage.getItem('theme') || 'dark';
        html.setAttribute('data-theme', savedTheme);
        updateIcon(savedTheme);

        toggleBtn.addEventListener('click', () => {
            const currentTheme = html.getAttribute('data-theme');
            const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
            
            html.setAttribute('data-theme', newTheme);
            localStorage.setItem('theme', newTheme);
            updateIcon(newTheme);
        });

        function updateIcon(theme) {
            toggleBtn.textContent = theme === 'dark' ? '🌙' : '☀️';
        }
    </script>
</body>
</html>
EOF
    } > "$out"

    # Replace placeholders
    sed -i "s|DASH_LANG_PLACEHOLDER|$DASH_LANG|g" "$out"
    sed -i "s|DASH_TITLE_PLACEHOLDER|$DASH_TITLE|g" "$out"
    sed -i "s|STATUS_COLOR_PLACEHOLDER|$status_color|g" "$out"
    sed -i "s|STATUS_TEXT_PLACEHOLDER|$status_text|g" "$out"
    sed -i "s|MASTER_IP_PLACEHOLDER|$master_ip|g" "$out"
    sed -i "s|NAS_IP_PLACEHOLDER|$nas_ip|g" "$out"
    sed -i "s|BACKUP_PFAD_PLACEHOLDER|$backup_pfad|g" "$out"
    sed -i "s|BACKUP_SIZE_PLACEHOLDER|$backup_size|g" "$out"
    sed -i "s|FILE_COUNT_PLACEHOLDER|$file_count|g" "$out"
    sed -i "s|DIR_COUNT_PLACEHOLDER|$dir_count|g" "$out"
    sed -i "s|DELETED_COUNT_PLACEHOLDER|$deleted_count|g" "$out"
    sed -i "s|COPY_ERRORS_PLACEHOLDER|$copy_errors|g" "$out"
    sed -i "s|VERIFY_ERRORS_PLACEHOLDER|$verify_errors|g" "$out"
    sed -i "s|START_HUMAN_PLACEHOLDER|$start_human|g" "$out"
    sed -i "s|END_HUMAN_PLACEHOLDER|$end_human|g" "$out"
    sed -i "s|DURATION_S_PLACEHOLDER|$duration_s|g" "$out"
    sed -i "s|GENERATED_AT_PLACEHOLDER|$(date '+%d.%m.%Y %H:%M:%S')|g" "$out"
    # Use # as delimiter for HTML content (safer)
    sed -i "s#CLOUD_WIDGET_PLACEHOLDER#$CLOUD_WIDGET_HTML#g" "$out"
    return 0
}
