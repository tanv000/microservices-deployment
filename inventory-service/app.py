from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/')
def home():
    return jsonify({
        "service": "Inventory Service",
        "message": "Inventory Service is running successfully!",
        "inventory": [
            {"item_id": 1, "name": "Laptop", "stock": 25},
            {"item_id": 2, "name": "Headphones", "stock": 60},
            {"item_id": 3, "name": "Smartwatch", "stock": 40}
        ]
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
