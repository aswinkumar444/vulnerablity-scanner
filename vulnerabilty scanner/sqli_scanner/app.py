import os
import hashlib
from flask import Blueprint, Flask, request, jsonify
from flask_cors import CORS
app = Flask(__name__)
CORS(app)
file_scan_bp = Blueprint("file_scan", __name__)
UPLOAD_FOLDER = "uploads"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
ALLOWED_EXTENSIONS = {".txt", ".pdf", ".doc", ".docx"}
MAX_FILE_SIZE = 10 * 1024 * 1024
scan_results = []
MALICIOUS_HASHES = {
    "098f6bcd4621d373cade4e832627b4f6",
    "8b1a9953c4611296a827abf8c47804d7",
    "9e107d9d372bb6826bd81d3542a419d6",
    "e99a18c428cb38d5f260853678922e03",
    "253a48892a8c3e9bfce6c074568df0c5",
    "9edba03409429f42d7e75f2eafb6d4fg",
    "253a48892a8c3e9bfce6c074568df0c5",
    "9edba03409429f42d7e75f2eafb6d4af",
}
def allowed_file(filename):
    """Check if the file extension is allowed"""
    return os.path.splitext(filename)[1].lower() in ALLOWED_EXTENSIONS

def get_md5_from_file(filepath, filename):
    """Generate MD5 hash based on file content"""
    if os.path.splitext(filename)[1].lower() in {".txt", ".doc", ".docx"}:
        with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read().strip().replace("\r", "").replace("\n", "")
        return hashlib.md5(content.encode("utf-8")).hexdigest().lower()
    else:
        md5_hash = hashlib.md5()
        with open(filepath, "rb") as f:
            for chunk in iter(lambda: f.read(4096), b""):
                md5_hash.update(chunk)
        return md5_hash.hexdigest().lower()
@file_scan_bp.route("/scan_file", methods=["POST"])
def scan_file():
    if "file" not in request.files:
        return jsonify({"error": "No file part"}), 400
    file = request.files["file"]
    if file.filename == "":
        return jsonify({"error": "No selected file"}), 400
    if not allowed_file(file.filename):
        return jsonify({"error": "File type not allowed"}), 400
    file.seek(0, os.SEEK_END)
    file_size = file.tell()
    if file_size > MAX_FILE_SIZE:
        return jsonify({"error": "File too large (max 10MB)"}), 400
    file.seek(0)
    filepath = os.path.join(UPLOAD_FOLDER, file.filename)
    file.save(filepath)
    try:
        file_hash = get_md5_from_file(filepath, file.filename)
        print(f"Computed MD5 hash for {file.filename}: {file_hash}")
        if file_hash in MALICIOUS_HASHES:
            status = "RISK"
            severity = "HIGH"
        else:
            status = "SAFE"
            severity = "LOW"
        try:
            os.remove(filepath)
        except OSError:
            pass

        result = {
            "type": "file",
            "name": file.filename,
            "status": status,
            "severity": severity,
            "hash": file_hash,
        }
        scan_results.append(result)
        return jsonify(result), 200
    except Exception as e:
        print("Error:", e)
        return jsonify({"error": "Failed to process file"}), 500
app.register_blueprint(file_scan_bp)
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001, debug=True)
