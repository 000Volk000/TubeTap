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
    progress_stop_event = threading.Event()  # Event to stop fake progress
    
    try:
        # Determine if it's audio or video download and prepare command
        is_audio_download = False
        cmd = []
        
        if quality_option:
            if 'p' in quality_option: # Video quality (e.g., "720p")
                height = quality_option.replace('p', '')
                cmd = ["/opt/my_youtube_downloader/tubetapVideoDownloader", youtube_url, height]
            elif 'K' in quality_option: # Audio bitrate (e.g., "128K")
                is_audio_download = True
                bitrate = quality_option.replace('K', '')
                cmd = ["/opt/my_youtube_downloader/tubetapAudioDownloader", youtube_url, bitrate]
            else:
                # Default to video 720p if format is unrecognized
                cmd = ["/opt/my_youtube_downloader/tubetapVideoDownloader", youtube_url, "720"]
        else:
            # Default to video 720p if no quality option is provided
            cmd = ["/opt/my_youtube_downloader/tubetapVideoDownloader", youtube_url, "720"]

        print(f"Executing command: {' '.join(cmd)}")

        # Announce start of download
        announcer.announce(format_sse(json.dumps({"status": "downloading", "progress": 0, "message": "Starting download..."}), event="progress"))

        # Start the fake progress update in a separate thread
        fake_progress_thread = threading.Thread(target=update_fake_progress, args=(progress_stop_event,))
        fake_progress_thread.daemon = True
        fake_progress_thread.start()

        # Execute the C++ program
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )

        stdout, stderr = process.communicate()
        
        # Stop the fake progress immediately
        progress_stop_event.set()
        
        print(f"Return code: {process.returncode}")
        print(f"STDOUT: {stdout}")
        print(f"STDERR: {stderr}")
        
        if process.returncode == 0:
            # Parse the output to get the downloaded file path
            downloaded_file_path = None
            for line in stdout.split('\n'):
                line = line.strip()
                if line.startswith('DOWNLOADED_FILE:'):
                    downloaded_file_path = line.replace('DOWNLOADED_FILE:', '').strip()
                    print(f"Found downloaded file path: {downloaded_file_path}")
                    break
            
            # If we didn't find the DOWNLOADED_FILE line, try to find the file manually
            if not downloaded_file_path:
                print("DOWNLOADED_FILE line not found, searching for files...")
                # Search in the appropriate directory
                search_dir = "/tmp/Videos/" if not is_audio_download else "/tmp/Audios/"
                try:
                    if os.path.exists(search_dir):
                        files = os.listdir(search_dir)
                        if files:
                            # Get the most recent file
                            files_with_time = []
                            for f in files:
                                if f.endswith(('.mp4', '.mp3')):
                                    file_path = os.path.join(search_dir, f)
                                    if os.path.isfile(file_path):
                                        files_with_time.append((f, os.path.getmtime(file_path)))
                            
                            if files_with_time:
                                files_with_time.sort(key=lambda x: x[1], reverse=True)  # Sort by modification time, newest first
                                downloaded_file_path = os.path.join(search_dir, files_with_time[0][0])
                                print(f"Found most recent file: {downloaded_file_path}")
                except Exception as e:
                    print(f"Error searching for files: {e}")
            
            # Verify the file exists (handle potential encoding issues)
            if downloaded_file_path:
                if not os.path.exists(downloaded_file_path):
                    print(f"File not found at exact path: {downloaded_file_path}")
                    # Try to find similar files in case of encoding differences
                    try:
                        search_dir = os.path.dirname(downloaded_file_path)
                        expected_basename = os.path.basename(downloaded_file_path)
                        
                        if os.path.exists(search_dir):
                            for file in os.listdir(search_dir):
                                if file.endswith(('.mp4', '.mp3')):
                                    # Check if it's a recent file (within last minute)
                                    file_path = os.path.join(search_dir, file)
                                    if os.path.getmtime(file_path) > time.time() - 60:
                                        downloaded_file_path = file_path
                                        print(f"Found recent file instead: {downloaded_file_path}")
                                        break
                    except Exception as e:
                        print(f"Error finding alternative file: {e}")
            
            if downloaded_file_path and os.path.exists(downloaded_file_path):
                # Set progress to 100% and announce completion
                announcer.announce(format_sse(json.dumps({
                    "status": "downloading", 
                    "progress": 100, 
                    "message": "Download complete!"
                }), event="progress"))
                
                time.sleep(0.5)  # Small delay to ensure 100% is shown
                
                # URL encode the filename for safe HTTP transmission
                import urllib.parse
                safe_filename = urllib.parse.quote(os.path.basename(downloaded_file_path), safe='')
                
                announcer.announce(format_sse(json.dumps({
                    "status": "download_complete", 
                    "file_path": safe_filename,  # Send URL-encoded filename
                    "original_filename": os.path.basename(downloaded_file_path),  # Original for display
                    "full_path": downloaded_file_path,
                    "message": "Download complete. Ready for streaming."
                }), event="progress"))
            else:
                error_msg = f"Downloaded file not found. Expected path: {downloaded_file_path if downloaded_file_path else 'unknown'}"
                print(error_msg)
                announcer.announce(format_sse(json.dumps({
                    "status": "error", 
                    "message": error_msg
                }), event="progress"))
        else:
            error_msg = f"Download failed (exit code {process.returncode})"
            if stderr.strip():
                if "403" in stderr or "Forbidden" in stderr:
                    error_msg = "Download failed: YouTube access forbidden (rate limited). Please try again later."
                else:
                    error_msg += f": {stderr.strip()}"
            
            print(f"Download failed: {error_msg}")
            announcer.announce(format_sse(json.dumps({
                "status": "error", 
                "message": error_msg
            }), event="progress"))

    except Exception as e:
        # Stop the fake progress in case of exception
        if 'progress_stop_event' in locals():
            progress_stop_event.set()
            
        error_msg = f"Server error during download: {str(e)}"
        print(error_msg)
        announcer.announce(format_sse(json.dumps({
            "status": "error", 
            "message": error_msg
        }), event="progress"))

def update_fake_progress(stop_event):
    """Update fake progress from 0 to 95% over about 4.5 minutes"""
    progress = 0
    while progress < 95 and not stop_event.is_set():
        time.sleep(1.5)  # Update every 3 seconds
        if stop_event.is_set():  # Check again after sleep
            break
        progress += 1  # Increment by 1% each time
        announcer.announce(format_sse(json.dumps({
            "status": "downloading",
            "progress": progress,
            "message": f"Downloading: {progress}%"
        }), event="progress"))

# --- Endpoint to serve the downloaded file ---
@app.route('/serve_video/<path:filename>')
def serve_video(filename):
    # URL decode the filename to handle special characters
    import urllib.parse
    decoded_filename = urllib.parse.unquote(filename)
    
    print(f"Original filename: {filename}")
    print(f"Decoded filename: {decoded_filename}")
    
    # Security: Ensure filename is within expected directories
    # Check in both /tmp/Videos/ and /tmp/Audios/ directories
    
    possible_paths = [
        os.path.join("/tmp/Videos", decoded_filename),
        os.path.join("/tmp/Audios", decoded_filename)
    ]
    
    full_path = None
    for path in possible_paths:
        print(f"Checking exact path: {path}")
        if os.path.exists(path) and os.path.isfile(path):
            # Additional security check: ensure the path is actually within the expected directories
            real_path = os.path.realpath(path)
            if (real_path.startswith("/tmp/Videos/") or real_path.startswith("/tmp/Audios/")) and \
               (decoded_filename.endswith(".mp4") or decoded_filename.endswith(".mp3") or decoded_filename.endswith(".m4a")):
                full_path = path
                print(f"Found exact file at: {full_path}")
                break
    
    # If exact path not found, try to find a similar file (handle encoding issues)
    if not full_path:
        print("Exact file not found, searching for similar files...")
        for search_dir in ["/tmp/Videos", "/tmp/Audios"]:
            if os.path.exists(search_dir):
                try:
                    files = os.listdir(search_dir)
                    print(f"Files in {search_dir}: {files}")
                    
                    # Look for files that match the base name (without path)
                    target_basename = os.path.basename(decoded_filename)
                    
                    for file in files:
                        if file.endswith(('.mp4', '.mp3', '.m4a')):
                            file_path = os.path.join(search_dir, file)
                            
                            # Check if filenames are similar or if it's a recent file
                            is_similar = (file == target_basename or 
                                        file.replace(' ', '_') == target_basename.replace(' ', '_') or
                                        file.replace('｜', '|') == target_basename.replace('｜', '|'))
                            is_recent = os.path.getmtime(file_path) > time.time() - 300  # Within last 5 minutes
                            
                            if is_similar or is_recent:
                                real_path = os.path.realpath(file_path)
                                if real_path.startswith(f"{search_dir}/"):
                                    full_path = file_path
                                    print(f"Found similar/recent file: {full_path}")
                                    break
                    
                    if full_path:
                        break
                except Exception as e:
                    print(f"Error searching in {search_dir}: {e}")
    
    if not full_path:
        print(f"File not found anywhere: {decoded_filename}")
        return jsonify({"error": "File not found or unauthorized access"}), 404

    # Read the file into memory and delete it immediately
    try:
        print(f"Reading file: {full_path}")
        with open(full_path, 'rb') as f:
            file_data = f.read()
        
        print(f"File size: {len(file_data)} bytes")
        
        # Delete the file after reading it
        os.unlink(full_path)
        print(f"Deleted temporary file: {full_path}")
        
        # Determine content type based on file extension
        if decoded_filename.endswith('.mp4'):
            mimetype = 'video/mp4'
        elif decoded_filename.endswith('.mp3'):
            mimetype = 'audio/mpeg'
        elif decoded_filename.endswith('.m4a'):
            mimetype = 'audio/mp4'
        else:
            mimetype = 'application/octet-stream'
        
        # Create safe filename for download (encode if necessary)
        safe_filename = os.path.basename(decoded_filename)
        # Replace problematic characters for Content-Disposition header
        safe_filename = safe_filename.replace('"', '\\"')
        
        print(f"Serving file with mimetype: {mimetype}")
        
        return Response(
            file_data,
            mimetype=mimetype,
            headers={
                'Content-Disposition': f'attachment; filename*=UTF-8\'\'{urllib.parse.quote(safe_filename)}',
                'Content-Length': str(len(file_data)),
                'Cache-Control': 'no-cache',
                'Connection': 'close'
            }
        )
        
    except Exception as e:
        print(f"Error serving file {full_path}: {e}")
        return jsonify({"error": "Error reading file"}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)

