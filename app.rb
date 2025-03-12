require 'sinatra/base'
require 'sinatra/json'
require 'jwt'
require 'json'

class App < Sinatra::Base
  # Load secret key from environment variable
  SECRET_KEY = ENV['DEMO_SECRET_KEY']
  raise 'DEMO_SECRET_KEY environment variable is not set' unless SECRET_KEY

  # Load credentials from auth.json
  begin
    credentials = JSON.parse(File.read('auth.json'))
    VALID_USERNAME = credentials['username']
    VALID_PASSWORD = credentials['password']
  rescue StandardError => e
    raise "Error loading credentials from auth.json: #{e.message}"
  end

  # Configure Sinatra
  configure do
    enable :logging
  end

  # Enable CORS
  before do
    headers['Access-Control-Allow-Origin'] = '*'
    headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS'
    headers['Access-Control-Allow-Headers'] = 'Origin, Accept, Content-Type, X-Requested-With, X-CSRF-Token, Authorization'

    # Handle preflight OPTIONS requests
    halt 200 if request.request_method == 'OPTIONS'
  end

  # Helper method to verify JWT token
  def verify_token
    auth_header = request.env['HTTP_AUTHORIZATION']
    unless auth_header&.start_with?('Bearer ')
      halt 401, json(error: 'No valid authorization header found')
    end

    token = auth_header.split(' ')[1]
    begin
      JWT.decode(token, SECRET_KEY, true, algorithm: 'HS256')
    rescue JWT::DecodeError
      halt 401, json(error: 'Invalid token')
    end
  end

  # Login endpoint
  post '/login' do
    begin
      data = JSON.parse(request.body.read)
      username = data['username']
      password = data['password']

      unless username && password
        halt 400, json(error: 'Username and password are required')
      end

      if username == VALID_USERNAME && password == VALID_PASSWORD
        # Generate JWT token
        token = JWT.encode(
          {
            username: username,
            exp: Time.now.to_i + (24 * 3600)  # Token expires in 24 hours
          },
          SECRET_KEY,
          'HS256'
        )

        json(
          message: 'Login successful',
          token: token
        )
      else
        halt 401, json(error: 'Invalid credentials')
      end
    rescue JSON::ParserError
      halt 400, json(error: 'Invalid JSON data')
    end
  end

  # Basic route (protected)
  get '/' do
    verify_token
    json(message: 'Welcome to the Sinatra REST API')
  end

  # Health check endpoint (unprotected)
  get '/health' do
    json(status: 'healthy')
  end

  # Echo endpoint (protected)
  get '/echo' do
    verify_token
    json(params)
  end

  # Data endpoint with current time (protected)
  post '/data' do
    verify_token
    begin
      data = JSON.parse(request.body.read)
      halt 400, json(error: 'Invalid JSON data') unless data.is_a?(Hash)

      data['current_time'] = Time.now.strftime('%Y-%m-%d %H:%M:%S')
      json(data)
    rescue JSON::ParserError
      halt 400, json(error: 'Invalid request data')
    end
  end

  # Error handling for 404
  not_found do
    content_type :json
    json(error: 'Not found')
  end

  # Start the server if ruby file executed directly
  run! if app_file == $0
end