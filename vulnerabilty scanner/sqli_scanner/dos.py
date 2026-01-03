from flask import Flask, request, jsonify
from flask_cors import CORS
import subprocess
import tempfile
import os
import csv
import uuid

app = Flask(__name__)
CORS(app)

@app.route("/check_dos", methods=["POST"])
def check_dos():
    data = request.json
    url = data.get("url")
    
    if not url:
        return jsonify({"error": "URL required"}), 400
    
    locustfile_content = f"""
from locust import HttpUser, task, between

class DoSTestUser(HttpUser):
    wait_time = between(0.1, 0.5)
    host = "{url}"
    
    @task
    def test_endpoint(self):
        self.client.get("/")
"""
    tmpfile = tempfile.NamedTemporaryFile(delete=False, suffix=".py")
    tmpfile.write(locustfile_content.encode())
    tmpfile.close()
    csv_prefix = f"report_{uuid.uuid4().hex}"
    result = subprocess.run(
        [
            "python", "-m", "locust",
            "-f", tmpfile.name, "--headless",
            "-u", "50",
            "-r", "10",
            "-t", "30s",
            f"--csv={csv_prefix}"
        ],
        capture_output=True, text=True
    )
    
    os.unlink(tmpfile.name)
    
    stats = {
        "total_requests": 0,
        "failures": 0,
        "avg_response_time": 0.0
    }
    csv_files_found = []
    for suffix in ["_stats.csv", "_failures.csv", "_exceptions.csv"]:
        filepath = f"{csv_prefix}{suffix}"
        if os.path.exists(filepath):
            csv_files_found.append(suffix)
    stats_file = f"{csv_prefix}_stats.csv"
    try:
        if os.path.exists(stats_file):
            with open(stats_file, "r") as f:
                pass
            with open(stats_file, "r") as f:
                reader = csv.DictReader(f)
                for row in reader:
                    name = row.get("Name", "").lower()
                    if name in ["/", "aggregated", "total"] or "aggregated" in name:
                        request_columns = ["# requests", "Request Count", "Requests", "requests"]
                        failure_columns = ["# failures", "Failure Count", "Failures", "failures"]
                        avg_time_columns = ["Average Response Time", "Avg Response Time", "average_response_time", "avg_response_time"]
                        
                        total_requests = 0
                        for col in request_columns:
                            if col in row and row[col]:
                                try:
                                    total_requests = int(float(row[col]))
                                    break
                                except:
                                    continue
                        
                        failures = 0
                        for col in failure_columns:
                            if col in row and row[col]:
                                try:
                                    failures = int(float(row[col]))
                                    break
                                except:
                                    continue
                        avg_response_time = 0.0
                        for col in avg_time_columns:
                            if col in row and row[col]:
                                try:
                                    avg_response_time = float(row[col])
                                    break
                                except:
                                    continue
                        
                        stats = {
                            "total_requests": total_requests,
                            "failures": failures,
                            "avg_response_time": round(avg_response_time, 2)
                        }
                        break
        else:
            stats["error"] = "Stats CSV file not found"
    except Exception as e:
        stats["error"] = f"CSV parse failed: {e}"
    
    failures_file = f"{csv_prefix}_failures.csv"
    failure_details = []
    try:
        if os.path.exists(failures_file):
            with open(failures_file, "r") as f:
                reader = csv.DictReader(f)
                for row in reader:
                    failure_details.append({
                        "method": row.get("Method", ""),
                        "name": row.get("Name", ""),
                        "error": row.get("Error", ""),
                        "occurrences": row.get("Occurrences", "")
                    })
    except Exception as e:
        pass
    
    for suffix in ["_stats.csv", "_failures.csv", "_exceptions.csv"]:
        try:
            os.remove(f"{csv_prefix}{suffix}")
        except:
            pass
    
    status = "Site seems stable under test"
    if stats.get("failures", 0) > 0:
        status = f"Possible DoS vulnerability detected - {stats['failures']} failures out of {stats['total_requests']} requests"
    elif stats.get("avg_response_time", 0) > 5000:
        status = "Site responding slowly under load - potential DoS vulnerability"
    
    response = {
        "url": url,
        "status": status,
        "raw_output": result.stdout,
        "stderr": result.stderr,
        "stats": stats,
        "csv_files_found": csv_files_found,
        "failure_details": failure_details
    }
    
    return jsonify(response)

if __name__ == "__main__":
    app.run(port=5002, debug=True)