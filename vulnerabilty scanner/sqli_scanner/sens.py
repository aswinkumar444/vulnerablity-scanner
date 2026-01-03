from flask import Flask, request, jsonify
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# Hardcoded dataset with text and labels - converted to dictionary for exact matching
sensitive_keywords = {
    "credit card": 1,
    "password": 1,
    "ssn": 1,
    "social security": 1,
    "bank account": 1,
    "secret": 1,
    "confidential": 1
}

normal_keywords = {
    "normal": 0,
    "regular": 0,
    "hello": 0,
    "world": 0
}
dataset = [
    ("normal", 0),
    ("This contains credit card: 1234-5678-9012-3456", 1),
    ("Just a regular message", 0),
    ("password", 1),
    ("Hello world", 0),
    ("credit card", 1),
    ("ssn", 1),
    ("social security", 1),
    ("bank account", 1),
    ("secret", 1),
    ("confidential", 1),
    ("apple", 0),
    ("banana", 0),
    ("computer", 0),
    ("phone", 0)
]
def load_data():
    texts = [item[0] for item in dataset]
    labels = [item[1] for item in dataset]
    return texts, labels

def train_model(texts, labels):
    pipeline = Pipeline([
        ('tfidf', TfidfVectorizer(stop_words='english', max_features=50000)),
        ('clf', LogisticRegression(max_iter=1000))
    ])
    pipeline.fit(texts, labels)
    return pipeline
texts, labels = load_data()
model = train_model(texts, labels)
def check_exact_match(text):
    """Check if text exactly matches any keyword"""
    text_lower = text.lower()
    for keyword, label in sensitive_keywords.items():
        if keyword.lower() in text_lower:
            return label, 1.0
    for keyword, label in normal_keywords.items():
        if keyword.lower() in text_lower:
            return label, 1.0
    
    return None, None
@app.route('/detect', methods=['POST', 'OPTIONS'])
def detect_sensitive():
    if request.method == 'OPTIONS':
        response = jsonify()
        response.headers.add('Access-Control-Allow-Origin', '*')
        response.headers.add('Access-Control-Allow-Headers', 'Content-Type')
        response.headers.add('Access-Control-Allow-Methods', 'POST')
        return response
    
    payload = request.get_json(silent=True) or {}
    text = str(payload.get('text', '')).strip()
    if not text:
        return jsonify({'error': 'Text is required'}), 400
    
    try:
        exact_match, exact_confidence = check_exact_match(text)
        
        if exact_match is not None:
            return jsonify({
                'sensitive': exact_match, 
                'probability': exact_confidence,
                'method': 'exact_match'
            })
        pred = int(model.predict([text])[0])
        proba = float(model.predict_proba([text])[0][1])
        
        return jsonify({
            'sensitive': pred, 
            'probability': proba,
            'method': 'ml_model'
        })
        
    except Exception as e:
        return jsonify({'error': f'Prediction error: {str(e)}'}), 500

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({'status': 'ok'})

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5004)