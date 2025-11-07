from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/')
def home():
    return jsonify({
        "service": "User Service",
        "message": "User Service is running successfully!",
        "users": [
            {"id": 1, "name": "Tanvi"},
            {"id": 2, "name": "Rahul"},
            {"id": 3, "name": "Priya"}
        ]
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
