from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/')
def home():
    return jsonify({
        "service": "Order Service",
        "message": "Order Service is running successfully!",
        "orders": [
            {"order_id": 101, "user_id": 1, "item": "Laptop"},
            {"order_id": 102, "user_id": 2, "item": "Headphones"},
            {"order_id": 103, "user_id": 3, "item": "Smartwatch"}
        ]
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
