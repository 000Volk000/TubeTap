from flask import Flask, request, jsonify, Response, stream_with_context, send_file
import subprocess
import os
import tempfile
import json
import queue
import threading
import time
import re
import io

app = Flask(__name__)

# --- SSE setup ---
class MessageAnnouncer:
    def __init__(self):
        self.listeners = []

    def listen(self):
        q = queue.Queue(maxsize=5) # Buffer for messages
        self.listeners.append(q)
        return q

    def announce(self, msg):
        # Remove disconnected listeners to prevent queue.Full errors
        for i in reversed(range(len(self.listeners))):
            try:
                self.listeners[i].put_nowait(msg)
            except queue.Full:
                del self.listeners[i]

announcer = MessageAnnouncer()

def format_sse(data: str, event=None) -> str:
    msg = f'data: {data}\n\n'
    if event is not None:
        msg = f'event: {event}\n{msg}'
    return msg

@app.route('/progress')
def progress_stream():
    def stream():
        messages = announcer.listen()
        while True:
            msg = messages.get() # Blocks until a new message arrives
            yield msg
    return Response(stream(), mimetype='text/event-stream')

# --- Main Download Endpoint ---
@app.route('/download', methods=['POST'])
def download_video():
    data = request.json
    if not data:
        return jsonify({"error": "Invalid JSON"}), 400

    youtube_url = data.get('url')
    quality_option = data.get('quality') # e.g., "720p", "1080p", "128K", "320K"
    
    if not youtube_url:
        return jsonify({"error": "YouTube URL is required"}), 400

    # Basic URL validation (more robust validation needed for production)
    if not re.match(r'^(https?://)?(www\.)?(youtube\.com|youtu\.be)/.+$', youtube_url):
        return jsonify({"error": "Invalid YouTube URL format"}), 400

    # Start download in a separate thread to avoid blocking the main request
    # and allow progress updates
    thread = threading.Thread(target=perform_download, args=(youtube_url, quality_option))
    thread.start()

    return jsonify({"message": "Download initiated, check /progress for status."}), 202

def perform_download(youtube_url, quality_option):
    # This function will run in a separate thread
    try:
        # Generate a unique filename for the temporary video file
        temp_file_prefix = f"yt-dlp_download_{int(time.time())}_"
        temp_file = tempfile.NamedTemporaryFile(delete=False, prefix=temp_file_prefix, suffix=".tmp")
        temp_file_path = temp_file.name
        temp_file.close() # Close the file handle immediately, yt-dlp will open it

        # Construct yt-dlp command
        yt_dlp_cmd = [
            "yt-dlp",
            "--output", temp_file_path,
            "--progress",
            "--progress-template", "%(progress.downloaded_bytes)s/%(progress.total_bytes)s %(progress._percent_str)s %(progress._eta_str)s",
        ]

        # Determine yt-dlp format selection based on quality_option
        is_audio_download = False
        if quality_option:
            if 'p' in quality_option: # Video quality (e.g., "720p")
                height = quality_option.replace('p', '')
                format_selector = f"bestvideo[height<={height}][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<={height}]+bestaudio/best[height<={height}]"
                yt_dlp_cmd.extend(["--format", format_selector, "--merge-output-format", "mp4"])
            elif 'K' in quality_option: # Audio bitrate (e.g., "128K")
                is_audio_download = True
                bitrate = quality_option.replace('K', '')
                format_selector = f"bestaudio[abr<={bitrate}]/bestaudio"
                # For audio, let yt-dlp determine the final extension.
                # We remove the explicit --output with .tmp and let it generate the .mp3
                # We will need to find the file later.
                # A better approach is to specify the output without extension
                base_output_path, _ = os.path.splitext(temp_file_path)
                yt_dlp_cmd = [
                    "yt-dlp",
                    "--output", base_output_path + ".%(ext)s",
                    "--progress",
                    "--progress-template", "%(progress.downloaded_bytes)s/%(progress.total_bytes)s %(progress._percent_str)s %(progress._eta_str)s",
                ]
                yt_dlp_cmd.extend(["--format", format_selector, "--extract-audio", "--audio-format", "mp3"])
            else:
                # Default to best quality if format is unrecognized
                format_selector = "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best"
                yt_dlp_cmd.extend(["--format", format_selector, "--merge-output-format", "mp4"])
        else:
            # Default format if no quality option is provided
            format_selector = "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best"
            yt_dlp_cmd.extend(["--format", format_selector, "--merge-output-format", "mp4"])

        yt_dlp_cmd.append(youtube_url)

        # Announce start of download
        announcer.announce(format_sse(json.dumps({"status": "downloading", "progress": 0, "message": "Starting download..."}), event="progress"))

        process = subprocess.Popen(
            yt_dlp_cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, # Merge stderr into stdout for simpler parsing
            bufsize=1, # Line-buffered output
            text=True # Decode output as text
        )

        total_bytes = None
        downloaded_bytes = 0

        for line in process.stdout:
            # Parse progress line from yt-dlp output
            match = re.search(r'(\d+)/(\d+)\s+([\d.]+%)', line)
            if match:
                downloaded_bytes = int(match.group(1))
                total_bytes = int(match.group(2))
                percent_str = match.group(3)
                
                progress_percent = 0
                if total_bytes > 0:
                    progress_percent = int((downloaded_bytes / total_bytes) * 100)

                announcer.announce(format_sse(json.dumps({
                    "status": "downloading",
                    "progress": progress_percent,
                    "downloaded": downloaded_bytes,
                    "total": total_bytes,
                    "message": f"Downloading: {percent_str}"
                }), event="progress"))
            else:
                # Log other output lines for debugging
                print(f"YT-DLP Output: {line.strip()}")

        process.wait() # Wait for the process to complete
        
        if process.returncode == 0:
            final_file_path = ""
            if is_audio_download:
                # yt-dlp replaces the original extension with .mp3
                base_name, _ = os.path.splitext(temp_file_path)
                final_file_path = base_name + ".mp3"
            else:
                # yt-dlp adds .mp4 extension to the final merged file
                final_file_path = temp_file_path

            # In case of video, yt-dlp might merge and create a new file without the .tmp
            if not is_audio_download and not os.path.exists(final_file_path):
                 final_file_path = final_file_path.replace(".tmp", "")


            if os.path.exists(final_file_path):
                announcer.announce(format_sse(json.dumps({"status": "download_complete", "file_path": os.path.basename(final_file_path), "message": "Download complete. Ready for streaming."}), event="progress"))
            else:
                # Fallback to original path if expected final file doesn't exist
                # This might happen if the download was a single file that didn't need merging/conversion
                if os.path.exists(temp_file_path):
                     announcer.announce(format_sse(json.dumps({"status": "download_complete", "file_path": os.path.basename(temp_file_path), "message": "Download complete. Ready for streaming."}), event="progress"))
                else:
                    announcer.announce(format_sse(json.dumps({"status": "error", "message": f"Downloaded file not found at expected path: {final_file_path}"}), event="progress"))
        else:
            # Capture stderr for more detailed error messages
            error_output = ""
            for line in process.stdout:
                error_output += line
            announcer.announce(format_sse(json.dumps({"status": "error", "message": f"yt-dlp failed with code {process.returncode}: {error_output.strip()}"}), event="progress"))
            if os.path.exists(temp_file_path):
                os.unlink(temp_file_path) # Clean up partial file
            # Also check for .mp4 or .mp3 version
            mp4_path = temp_file_path + ".mp4"
            if os.path.exists(mp4_path):
                os.unlink(mp4_path)
            base_name, _ = os.path.splitext(temp_file_path)
            mp3_path = base_name + ".mp3"
            if os.path.exists(mp3_path):
                os.unlink(mp3_path)
            return

        # --- Stream the file back to the client ---
        # This part assumes the Flutter app will make a separate GET request to fetch the file
        # The path is sent via SSE, and the Flutter app then requests it.
        # This is a simplified approach. For direct streaming, the /download endpoint
        # would need to handle the streaming directly after download.

    except Exception as e:
        announcer.announce(format_sse(json.dumps({"status": "error", "message": f"Server error during download: {str(e)}"}), event="progress"))
        if 'temp_file_path' in locals() and os.path.exists(temp_file_path):
            os.unlink(temp_file_path) # Clean up partial file
        # Also check for .mp4 version
        if 'temp_file_path' in locals():
            mp4_path = temp_file_path + ".mp4"
            if os.path.exists(mp4_path):
                os.unlink(mp4_path)

# --- Endpoint to serve the downloaded file ---
@app.route('/serve_video/<path:filename>')
def serve_video(filename):
    # Security: Ensure filename is within expected temporary directory
    # This is a critical security measure to prevent directory traversal attacks.
    
    # For demonstration, assume files are in a specific temp directory
    base_temp_dir = tempfile.gettempdir() # Get system's temporary directory
    full_path = os.path.join(base_temp_dir, filename)

    # Check if the file exists and has the expected prefix
    if not os.path.exists(full_path) or not os.path.isfile(full_path) or not filename.startswith("yt-dlp_download_"):
        return jsonify({"error": "File not found or unauthorized access"}), 404

    # Read the file into memory and delete it immediately
    try:
        with open(full_path, 'rb') as f:
            file_data = f.read()
        
        # Delete the file after reading it
        os.unlink(full_path)
        print(f"Deleted temporary file: {full_path}")
        
        # Create a BytesIO object to serve the file
        file_io = io.BytesIO(file_data)
        
        # Determine content type based on file extension
        if filename.endswith('.mp4'):
            mimetype = 'video/mp4'
        elif filename.endswith('.mp3'):
            mimetype = 'audio/mpeg'
        elif filename.endswith('.m4a'):
            mimetype = 'audio/mp4'
        else:
            mimetype = 'application/octet-stream'
        
        return Response(
            file_io.getvalue(),
            mimetype=mimetype,
            headers={
                'Content-Disposition': f'attachment; filename="{os.path.basename(filename)}"',
                'Content-Length': str(len(file_data))
            }
        )
        
    except Exception as e:
        print(f"Error serving file {full_path}: {e}")
        return jsonify({"error": "Error reading file"}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
