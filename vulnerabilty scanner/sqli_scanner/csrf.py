from bs4 import BeautifulSoup
import requests
def check_csrf(url):
    session = requests.Session()
    resp = session.get(url)
    soup = BeautifulSoup(resp.text, 'lxml')
    for form in soup.find_all("form"):
        method = form.get("method", "get").lower()
        if method == "post":  
            hidden_inputs = form.find_all("input", {"type": "hidden"})
            tokens = [inp.get("name") for inp in hidden_inputs if "token" in inp.get("name", "").lower()]
            if not tokens:
                print(f"[!] Potential CSRF risk at {url} -> Form action={form.get('action')}")
            else:
                print(f"[+] CSRF protection token found: {tokens}")
if __name__ == "__main__":
    url = input("Enter the URL to check for CSRF: ")
    check_csrf(url)