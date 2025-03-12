from bottle import Bottle, response, request
import json
from datetime import datetime

app = Bottle()

# Enable CORS
@app.hook('after_request')
def enable_cors():
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = 'Origin, Accept, Content-Type, X-Requested-With, X-CSRF-Token'

# Basic route
@app.route('/', method='GET')
def index():
    return {'message': 'Welcome to the Bottle REST API'}

# Health check endpoint
@app.route('/health', method='GET')
def health_check():
    return {'status': 'healthy'}

# Echo endpoint
@app.route('/echo', method='GET')
def echo():
    return dict(request.query)

# Data endpoint with current time
@app.route('/data', method='POST')
def add_timestamp():
    try:
        data = request.json
        if not data or not isinstance(data, dict):
            response.status = 400
            return {'error': 'Invalid JSON data'}

        data['current_time'] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        return data
    except Exception as e:
        response.status = 400
        return {'error': 'Invalid request data'}

# Error handling
@app.error(404)
def error404(error):
    response.content_type = 'application/json'
    return json.dumps({'error': 'Not found'})

if __name__ == '__main__':
    app.run(host='localhost', port=8080, debug=True, reloader=True)