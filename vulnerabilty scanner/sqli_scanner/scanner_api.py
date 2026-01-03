from flask import Flask, request, jsonify, Response
from bs4 import BeautifulSoup
from urllib.parse import urljoin
from flask_cors import CORS
import google.generativeai as genai
import re
import json
import concurrent.futures
import datetime
import sys
import time
import requests

app = Flask(__name__)
CORS(app)

GEMINI_API_KEY = "AIzaSyBb_UHJJZw5PQ5_KCxwE5FamZTT_PBC8IM"

def setup_gemini():
    """Configure Gemini AI with latest free models"""
    try:
        genai.configure(api_key=GEMINI_API_KEY)
        
        # List available models to see what's working
        print("🔍 Discovering available models...")
        available_models = genai.list_models()
        model_names = [model.name for model in available_models]
        print("📋 Available models:")
        for model_name in model_names:
            print(f"   - {model_name}")
        
        # Try to find a working free model - these are the current free models
        working_model = None
        free_models = [
            'gemini-2.0-flash',  # Current free fast model
            
        ]
        
        for model_name in free_models:
            if any(model_name in name for name in model_names):
                working_model = model_name
                print(f"✅ Selected working model: {working_model}")
                break
        
        if working_model:
            return working_model
        else:
            print("❌ No free models found in available models")
            # Try to use the first available model that supports generateContent
            for model in available_models:
                if 'generateContent' in model.supported_generation_methods:
                    working_model = model.name
                    print(f"🔄 Using available model: {working_model}")
                    return working_model
            
            return None
            
    except Exception as e:
        print(f"❌ Error configuring Gemini API: {e}")
        return None

# Configure Gemini on startup
WORKING_MODEL = setup_gemini()

def log_step(message, level="info"):
    """Print timestamped live log messages with different levels"""
    now = datetime.datetime.now().strftime("[%I:%M:%S %p]")
    level_colors = {
        "info": "\033[94m",      # Blue
        "success": "\033[92m",   # Green
        "warning": "\033[93m",   # Yellow
        "error": "\033[91m",     # Red
        "critical": "\033[95m",  # Purple
    }
    color = level_colors.get(level, "\033[0m")
    reset = "\033[0m"
    print(f"{color}{now} {message}{reset}")
    sys.stdout.flush()

SQLI_PAYLOADS = ["' OR '1'='1", "' OR 'a'='a", "';--", "' UNION SELECT NULL,NULL--"]
XSS_PAYLOADS = ["<script>alert(1)</script>", "\" onmouseover=alert(1) \"", "'><img src=x onerror=alert(1)>"]
CMDI_PAYLOADS = ["; ls", "&& whoami", "| cat /etc/passwd"]
LFI_PAYLOADS = ["../../../../etc/passwd", "../etc/passwd", "../../../../windows/win.ini"]

def get_forms(url):
    try:
        headers = {'User-Agent': 'Mozilla/5.0'}
        response = requests.get(url, timeout=10, headers=headers)
        soup = BeautifulSoup(response.text, "html.parser")
        return soup.find_all("form")
    except Exception as e:
        log_step(f"Error getting forms: {e}", "error")
        return []

def test_payloads(url, payloads, vuln_type, severity, indicators=None, stop_on_first=True):
    vulns = []
    forms = get_forms(url)
    log_step(f"🔍 Testing for {vuln_type} vulnerabilities", "info")
    for form in forms:
        action = form.get("action")
        method = form.get("method", "get").lower()
        inputs = form.find_all("input")

        for payload in payloads:
            data = {}
            for inp in inputs:
                name = inp.get("name")
                if name:
                    data[name] = payload
            target_url = urljoin(url, action)
            try:
                if method == "post":
                    res = requests.post(target_url, data=data, timeout=5)
                else:
                    res = requests.get(target_url, params=data, timeout=5)
                body = res.text.lower()
                match = False

                if vuln_type == "SQL Injection":
                    if any(ind in body for ind in indicators):
                        match = True
                elif vuln_type == "XSS":
                    if payload in res.text:
                        match = True
                elif vuln_type == "Command Injection":
                    if "root" in body or "uid=" in body:
                        match = True
                elif vuln_type == "Local File Inclusion":
                    if "root:" in body or "[extensions]" in body:
                        match = True
                if match:
                    vuln_data = {
                        "form_action": target_url,
                        "payload": payload,
                        "type": vuln_type,
                        "severity": severity,
                        "description": f"{vuln_type} vulnerability detected in {target_url}"
                    }
                    vulns.append(vuln_data)
                    log_step(f"⚠ {vuln_type} detected at {target_url} using payload {payload}", "warning")
                    if stop_on_first:
                        return vulns
            except Exception as e:
                log_step(f"{vuln_type} test error: {e}", "error")
    
    if not vulns:
        log_step(f"✅ No {vuln_type} vulnerabilities found", "success")
    
    return vulns

def analyze_with_gemini_simple(url):
    if not GEMINI_API_KEY:
        return [{"vulnerability_type": "AI Analysis Unavailable", "severity": "Info", "description": "No API key", "recommendation": "Review traditional results"}]

    if not WORKING_MODEL:
        return [{"vulnerability_type": "Model Configuration Error", "severity": "High", "description": "No working Gemini model found. Please check your API key and available models.", "recommendation": "Check Gemini API configuration and quota"}]

    try:
        # Use the simplest configuration for free models
        model = genai.GenerativeModel(WORKING_MODEL)

        prompt = f"""
        Analyze the website {url} for security vulnerabilities.
        
        Provide a JSON array with security findings in this exact format:
        [
            {{
                "vulnerability_type": "Vulnerability Name",
                "severity": "High/Medium/Low/Info", 
                "description": "Brief description",
                "recommendation": "How to fix it"
            }}
        ]
        
        Focus on common web vulnerabilities and security best practices.
        """

        log_step(f"🧠 Generating AI security assessment using {WORKING_MODEL}...", "info")

        with concurrent.futures.ThreadPoolExecutor() as executor:
            future = executor.submit(model.generate_content, prompt)
            try:
                response = future.result(timeout=25)
                response_text = response.text.strip()

                log_step(f"📝 Raw AI Response received ({len(response_text)} chars)", "info")

                # Try to extract JSON from the response
                json_match = re.search(r'\[.*\]', response_text, re.DOTALL)
                if json_match:
                    try:
                        ai_results = json.loads(json_match.group())
                        log_step(f"✅ AI analysis completed - Found {len(ai_results)} security issues", "success")
                        return ai_results
                    except json.JSONDecodeError as e:
                        log_step(f"⚠ JSON parsing failed, using text analysis", "warning")
                        # If JSON fails, return the text as analysis
                        return [{"vulnerability_type": "Security Analysis", "severity": "Info", "description": response_text[:250], "recommendation": "Review website security manually"}]
                else:
                    # If no JSON found but we have content
                    if response_text and len(response_text) > 10:
                        return [{"vulnerability_type": "Security Assessment", "severity": "Info", "description": response_text[:250], "recommendation": "Review traditional scan results"}]
                    else:
                        return [{"vulnerability_type": "No Specific Findings", "severity": "Info", "description": "AI analysis completed but no specific vulnerabilities identified", "recommendation": "Review traditional scan results for detailed findings"}]

            except concurrent.futures.TimeoutError:
                log_step("⏰ AI analysis timed out", "error")
                return [{"vulnerability_type": "Analysis Timeout", "severity": "Info", "description": "AI analysis took too long to complete", "recommendation": "Check traditional results"}]

    except Exception as e:
        error_msg = str(e)
        log_step(f"❌ AI Analysis Error: {error_msg}", "error")
        
        # Specific error handling
        if "API_KEY_INVALID" in error_msg:
            return [{"vulnerability_type": "Invalid API Key", "severity": "High", "description": "The provided Gemini API key is invalid", "recommendation": "Check your API key configuration"}]
        elif "quota" in error_msg.lower():
            return [{"vulnerability_type": "Quota Exceeded", "severity": "Medium", "description": "Gemini API quota has been exceeded", "recommendation": "Check your API usage limits or wait for quota reset"}]
        elif "429" in error_msg:
            return [{"vulnerability_type": "Rate Limited", "severity": "Medium", "description": "Too many requests to Gemini API", "recommendation": "Wait and try again later"}]
        elif "404" in error_msg:
            return [{"vulnerability_type": "Model Not Found", "severity": "High", "description": f"Model {WORKING_MODEL} not available. Available models printed above.", "recommendation": "Check the console output for available models and update configuration"}]
        else:
            return [{"vulnerability_type": "Analysis Failed", "severity": "Info", "description": f"Error: {error_msg}", "recommendation": "Check API configuration and try again"}]

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        "status": "healthy", 
        "message": "Scanner API is running",
        "ai_model": WORKING_MODEL or "Not configured",
        "api_key": "Configured" if GEMINI_API_KEY else "Missing"
    })

@app.route('/models', methods=['GET'])
def list_models():
    """Endpoint to list available models"""
    try:
        available_models = genai.list_models()
        model_list = [{
            "name": model.name,
            "display_name": model.display_name,
            "description": model.description,
            "supported_methods": model.supported_generation_methods
        } for model in available_models]
        
        return jsonify({
            "available_models": model_list,
            "current_model": WORKING_MODEL
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/scan', methods=['POST'])
def scan_website():
    try:
        data = request.get_json()
        url = data.get('url')
        
        if not url:
            return jsonify({"error": "No URL provided"}), 400

        log_step(f"🎯 Starting scan for: {url}", "info")
        
        if not url.startswith(('http://', 'https://')):
            url = 'https://' + url

        log_step("🚀 Starting security scan...", "info")
        time.sleep(1)
        
        # Run vulnerability tests
        sqli_vulns = test_payloads(url, SQLI_PAYLOADS, "SQL Injection", "High", ["error", "syntax", "mysql", "sql", "exception", "warning"])
        xss_vulns = test_payloads(url, XSS_PAYLOADS, "XSS", "Medium")
        cmdi_vulns = test_payloads(url, CMDI_PAYLOADS, "Command Injection", "High")
        lfi_vulns = test_payloads(url, LFI_PAYLOADS, "Local File Inclusion", "High")
        
        # AI Analysis
        ai_analysis = []
        if WORKING_MODEL:
            log_step("🤖 Starting AI security analysis...", "info")
            ai_analysis = analyze_with_gemini_simple(url)
        else:
            log_step("⚠ AI analysis skipped - no working model", "warning")
            ai_analysis = [{"vulnerability_type": "AI Analysis Disabled", "severity": "Info", "description": "AI analysis is not available due to model configuration issues", "recommendation": "Check backend logs for model configuration details"}]
        
        log_step("🎉 Security scan completed successfully", "success")
        
        result = {
            "url": url,
            "sqli_vulnerabilities": sqli_vulns,
            "xss_vulnerabilities": xss_vulns,
            "command_injection_vulnerabilities": cmdi_vulns,
            "lfi_vulnerabilities": lfi_vulns,
            "ai_analysis": ai_analysis,
            "scan_status": "completed",
            "ai_model": WORKING_MODEL or "Not available"
        }
        
        return jsonify(result)
        
    except Exception as e:
        log_step(f"💥 Critical error during scan: {str(e)}", "critical")
        return jsonify({"error": f"Scan failed: {str(e)}"}), 500

if __name__ == "__main__":
    print("🚀 Starting VulScanner Backend...")
    print(f"🔑 API Key: {'Configured' if GEMINI_API_KEY else 'Missing'}")
    print(f"🤖 Selected Model: {WORKING_MODEL or 'None - check configuration'}")
    
    if not WORKING_MODEL:
        print("❌ WARNING: No working Gemini model found!")
        print("💡 Check your API key and ensure you have access to Gemini models")
    
    app.run(debug=True, host='0.0.0.0', port=5000)