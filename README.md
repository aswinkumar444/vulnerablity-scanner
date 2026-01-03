WEBSCANNER
A Flutter-based application designed to perform vulnerability scanning on a specified URL. This tool provides a user-friendly interface to input a target URL, initiate a scan, and visualize the results through charts and statistics.
Features

URL Input: Enter a target URL to scan for All vulnerabilities.
Scan Initiation: Trigger scans with a clean, modern button design.
Status Feedback: Displays scan status with clear success or error messages.
Statistics Visualization:
1.SQLI INJECTION
2.XSS
3.CSRF
4.COMMAND INJECTION

AI INTEGERATION:
LLM Model for automation process for finding the Vulnerabilities
Bar chart for total requests vs. failures.
Bar chart for average response time.
Pie chart for success rate.


Responsive UI: Dark-themed interface with rounded corners and a professional look, inspired by modern web design.

Prerequisites

Flutter SDK: Ensure Flutter is installed (version 3.0.0 or higher recommended).
Dart: Comes with Flutter installation.
Backend Server: A backend server running at http://localhost:5002/check_dos to handle scan requests.
Dependencies:
http package for making HTTP requests.
fl_chart package for rendering charts.



Installation
Git Clone:
```bash
git clone https://github.com/CHRIS-7777/Android-debug.git
```


Install Dependencies:
   ```bash
   flutter pub get
   ```


Set Up Backend:Ensure a backend server is running at http://localhost:5002/check_dos to process scan requests. Update the URL in dos_scanner.dart if your backend is hosted elsewhere.

Run the Application:
   ```bash
   flutter run
   ```



Usage

Launch the app.
Enter a target URL in the provided text field (e.g., http://localhost:8000 or https://example.com).
Click the Start Scan button to initiate the DoS scan.
View the scan results, including:
Total requests and failures in stat cards.
Visual charts for requests vs. failures, average response time, and success rate.



File Structure

lib/dos_scanner.dart: Main Dart file containing the DoS scanner UI and logic.
pubspec.yaml: Contains project dependencies, including http and fl_chart.

Dependencies
Add the following to your pubspec.yaml:
dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.2
  fl_chart: ^0.68.0

Screenshots
Coming soon
Contributing
Contributions are welcome! Please follow these steps:

Fork the repository.
Create a new branch (git checkout -b feature/your-feature).
Make your changes and commit (git commit -m 'Add your feature').
Push to the branch (git push origin feature/your-feature).
Open a pull request.

License
This project is licensed under the MIT License - see the LICENSE file for details.
Disclaimer
This tool is for educational and ethical testing purposes only. Do not use it to perform unauthorized scans or attacks on systems you do not own or have explicit permission to test.
