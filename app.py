from flask import Flask, request, jsonify, Response
import subprocess
import os
import json
import queue
import threading
import time
import re
import urllib.parse

app = Flask(__name__)

# --- SSE setup ---
class MessageAnnouncer:
    def __init__(self):
        self.listeners = []

    def listen(self):
        q = queue.Queue(maxsize=10)
        self.listeners.append(q)
        return q

    def announce(self, msg):
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
            msg = messages.get()
            yield msg
    return Response(stream(), mimetype='text/event-stream')

# --- Main Download Endpoint ---
@app.route('/download', methods=['POST'])
def download_video():
    data = request.json
    if not data:
        return jsonify({"error": "Invalid JSON"}), 400

    youtube_url = data.get('url')
    quality_option = data.get('quality')
    
    if not youtube_url:
        return jsonify({"error": "YouTube URL is required"}), 400

    if not re.match(r'^(https?://)?(www\.)?(youtube\.com|youtu\.be)/.+$', youtube_url):
        return jsonify({"error": "Invalid YouTube URL format"}), 400

    thread = threading.Thread(target=perform_download, args=(youtube_url, quality_option))
    thread.start()

    return jsonify({"message": "Download initiated, check /progress for status."}), 202

def perform_download(youtube_url, quality_option):
    progress_stop_event = threading.Event()
    
    try:
        is_audio_download = 'K' in quality_option
        cmd = []
        
        if 'p' in quality_option:
            height = quality_option.replace('p', '')
            cmd = ["/opt/my_youtube_downloader/tubetapVideoDownloader", youtube_url, height]
        elif 'K' in quality_option:
            bitrate = quality_option.replace('K', '')
            cmd = ["/opt/my_youtube_downloader/tubetapAudioDownloader", youtube_url, bitrate]
        else:
            cmd = ["/opt/my_youtube_downloader/tubetapVideoDownloader", youtube_url, "720"]

        print(f"Executing command: {' '.join(cmd)}")
        announcer.announce(format_sse(json.dumps({"status": "downloading", "progress": 0, "message": "Starting download..."}), event="progress"))

        fake_progress_thread = threading.Thread(target=update_fake_progress, args=(progress_stop_event,))
        fake_progress_thread.daemon = True
        fake_progress_thread.start()

        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding='utf-8'
        )

        stdout, stderr = process.communicate()
        progress_stop_event.set()
        
        print(f"Return code: {process.returncode}")
        print(f"STDOUT: {stdout}")
        print(f"STDERR: {stderr}")
        
        if process.returncode == 0:
            downloaded_file_path = None
            for line in stdout.split('\n'):
                if line.startswith('DOWNLOADED_FILE:'):
                    downloaded_file_path = line.replace('DOWNLOADED_FILE:', '').strip()
                    print(f"Found downloaded file path: {downloaded_file_path}")
                    break
            
            if downloaded_file_path and os.path.exists(downloaded_file_path):
                announcer.announce(format_sse(json.dumps({"status": "downloading", "progress": 100, "message": "Download complete!"}), event="progress"))
                time.sleep(0.5)
                
                safe_filename = urllib.parse.quote(os.path.basename(downloaded_file_path))
                
                announcer.announce(format_sse(json.dumps({
                    "status": "download_complete", 
                    "file_path": safe_filename,
                    "message": "Download complete. Ready for streaming."
                }), event="progress"))
            else:
                error_msg = f"Downloaded file not found. Expected path: {downloaded_file_path or 'unknown'}"
                print(error_msg)
                announcer.announce(format_sse(json.dumps({"status": "error", "message": error_msg}), event="progress"))
        else:
            error_msg = f"Download failed (exit code {process.returncode})"
            if stderr.strip():
                if "403" in stderr or "Forbidden" in stderr:
                    error_msg = "Download failed: YouTube access forbidden (rate limited). Please try again later."
                else:
                    error_msg += f": {stderr.strip()}"
            
            print(f"Download failed: {error_msg}")
            announcer.announce(format_sse(json.dumps({"status": "error", "message": error_msg}), event="progress"))

    except Exception as e:
        if 'progress_stop_event' in locals():
            progress_stop_event.set()
        error_msg = f"Server error during download: {str(e)}"
        print(error_msg)
        announcer.announce(format_sse(json.dumps({"status": "error", "message": error_msg}), event="progress"))

def update_fake_progress(stop_event):
    progress = 0
    while progress < 95 and not stop_event.is_set():
        time.sleep(1.5)
        if stop_event.is_set():
            break
        progress += 1
        announcer.announce(format_sse(json.dumps({"status": "downloading", "progress": progress, "message": f"Downloading: {progress}%"}), event="progress"))

# --- Endpoint to serve the downloaded file ---
@app.route('/serve_video/<path:filename>')
def serve_video(filename):
    decoded_filename = urllib.parse.unquote(filename)
    
    # Determine search directory based on file extension
    if decoded_filename.endswith('.mp4'):
        search_dir = "/tmp/Videos"
    elif decoded_filename.endswith('.mp3'):
        search_dir = "/tmp/Audios"
    else:
        return jsonify({"error": "Unsupported file type"}), 400

    full_path = os.path.join(search_dir, decoded_filename)
    
    # Security check: ensure the path is within the expected directories
    real_path = os.path.realpath(full_path)
    if not real_path.startswith(search_dir):
        return jsonify({"error": "Unauthorized access"}), 403

    if not os.path.exists(full_path):
        print(f"File not found: {full_path}")
        return jsonify({"error": "File not found"}), 404

    try:
        with open(full_path, 'rb') as f:
            file_data = f.read()
        
        os.unlink(full_path)
        print(f"Deleted temporary file: {full_path}")
        
        mimetype = 'video/mp4' if decoded_filename.endswith('.mp4') else 'audio/mpeg'
        
        return Response(
            file_data,
            mimetype=mimetype,
            headers={
                'Content-Disposition': f'attachment; filename*=UTF-8\'\'{urllib.parse.quote(decoded_filename)}',
                'Content-Length': str(len(file_data))
            }
        )
        
    except Exception as e:
        print(f"Error serving file {full_path}: {e}")
        return jsonify({"error": "Error reading file"}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)