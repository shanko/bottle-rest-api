from bottle import Bottle, response, request
import json
from datetime import datetime, timedelta
import jwt
import os

app = Bottle()

# Load secret key from environment variable
SECRET_KEY = os.environ.get('DEMO_SECRET_KEY')
if not SECRET_KEY:
    raise ValueError("DEMO_SECRET_KEY environment variable is not set")

# Load credentials from auth.json
try:
    with open('auth.json', 'r') as f:
        credentials = json.load(f)
        VALID_USERNAME = credentials['username']
        VALID_PASSWORD = credentials['password']
except (FileNotFoundError, KeyError, json.JSONDecodeError) as e:
    raise ValueError(f"Error loading credentials from auth.json: {str(e)}")

def verify_token():
    """Verify the Bearer token from Authorization header"""
    auth_header = request.headers.get('Authorization')
    if not auth_header or not auth_header.startswith('Bearer '):
        response.status = 401
        return {'error': 'No valid authorization header found'}

    token = auth_header.split(' ')[1]
    try:
        jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
        return None
    except jwt.InvalidTokenError:
        response.status = 401
        return {'error': 'Invalid token'}

def require_auth(func):
    """Decorator to protect routes with JWT authentication"""
    def wrapper(*args, **kwargs):
        error = verify_token()
        if error:
            return error
        return func(*args, **kwargs)
    return wrapper

# Enable CORS
@app.hook('after_request')
def enable_cors():
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = 'Origin, Accept, Content-Type, X-Requested-With, X-CSRF-Token, Authorization'

# Login endpoint
@app.route('/login', method='POST')
def login():
    try:
        data = request.json
        if not data:
            response.status = 400
            return {'error': 'Missing request body'}

        username = data.get('username')
        password = data.get('password')

        if not username or not password:
            response.status = 400
            return {'error': 'Username and password are required'}

        if username == VALID_USERNAME and password == VALID_PASSWORD:
            # Generate JWT token
            token = jwt.encode({
                'username': username,
                'exp': datetime.utcnow() + timedelta(hours=24)  # Token expires in 24 hours
            }, SECRET_KEY, algorithm="HS256")

            return {
                'message': 'Login successful',
                'token': token
            }
        else:
            response.status = 401
            return {'error': 'Invalid credentials'}

    except Exception as e:
        response.status = 400
        return {'error': str(e)}

# Basic route (protected)
@app.route('/', method='GET')
@require_auth
def index():
    return {'message': 'Welcome to the Bottle REST API'}

# Health check endpoint (unprotected)
@app.route('/health', method='GET')
def health_check():
    return {'status': 'healthy'}

# Echo endpoint (protected)
@app.route('/echo', method='GET')
@require_auth
def echo():
    return dict(request.query)

# Data endpoint with current time (protected)
@app.route('/data', method='POST')
@require_auth
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