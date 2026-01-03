import requests
from bs4 import BeautifulSoup
SQL_ERRORS = [
    "you have an error in your sql syntax",
    "warning: mysql",
    "unclosed quotation mark",
    "quoted string not properly terminated",
    "error in your sql"
]
def scan_sqli(url, param):
    test_url = f"{url}?{param}='"
    try:
        response = requests.get(test_url, timeout=5)
        soup = BeautifulSoup(response.text, "html.parser")
        for error in SQL_ERRORS:
            if error.lower() in response.text.lower():
                page_title = soup.title.string if soup.title else "No Title"
                print("\n[+] SQL Injection Vulnerability Detected!")
                print(f"    → URL: {test_url}")
                print(f"    → Parameter: {param}")
                print(f"    → Page Title: {page_title}")
                print(f"    → Error Evidence: {error}")
                return
        print("\n[-] No SQL Injection vulnerability detected.")
    except requests.exceptions.RequestException as e:
        print(f"[!] Request Failed: {e}")
if __name__ == "__main__":
    url = input("Enter the base URL (e.g., http://testphp.vulnweb.com/artists.php): ").strip()
    param = input("Enter the parameter to test (e.g., artist): ").strip()
    scan_sqli(url, param)
