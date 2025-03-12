# Bottle REST API

This is a REST API built using the Bottle Python framework.

## Setup

1. Create a virtual environment (recommended):
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Set up authentication:
   - Create an `auth.json` file with your credentials:
     ```json
     {
         "username": "your_username",
         "password": "your_password"
     }
     ```
   - Set the `DEMO_SECRET_KEY` environment variable:
     ```bash
     # On Unix/macOS:
     export DEMO_SECRET_KEY="your-secure-secret-key"

     # On Windows:
     set DEMO_SECRET_KEY=your-secure-secret-key
     ```

4. Run the application:
```bash
python app.py
```

The server will start on `http://localhost:8080`

## Authentication

Most endpoints are protected and require authentication. To access protected endpoints:

1. First, obtain a JWT token by calling the login endpoint with valid credentials (matching auth.json):
```bash
curl -X POST http://localhost:8080/login \
  -H "Content-Type: application/json" \
  -d '{"username": "your_username", "password": "your_password"}'
```

2. Use the returned token in subsequent requests as a Bearer token:
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:8080/protected_endpoint
```

## API Endpoints

### Public Endpoints
- `GET /health`: Health check endpoint

### Protected Endpoints (require authentication)
- `GET /`: Hello World endpoint
- `GET /echo`: Returns all query parameters as JSON (e.g., `/echo?name=John&age=30`)
- `POST /data`: Accepts JSON data and adds current timestamp to it

### Authentication Endpoints
- `POST /login`: Login endpoint
  - Request body: JSON with username and password matching auth.json
  - Response: `{"message": "Login successful", "token": "JWT_TOKEN"}`

## Security Notes

1. Keep your `DEMO_SECRET_KEY` secure and never commit it to version control
2. The `auth.json` file is git-ignored to prevent accidental commits
3. In production, consider using a secure credential storage system instead of a local JSON file