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

3. Run the application:
```bash
python app.py
```

The server will start on `http://localhost:8080`

## API Endpoints

- `GET /`: Hello World endpoint
- `GET /health`: Health check endpoint
- `GET /echo`: Returns all query parameters as JSON (e.g., `/echo?name=John&age=30`)
- `POST /data`: Accepts JSON data and adds current timestamp to it
  - Request body: Any valid JSON object
  - Response: Same JSON object with added `current_time` field
- More endpoints to be added...