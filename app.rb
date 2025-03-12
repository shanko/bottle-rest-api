require 'sinatra/base'
require 'sinatra/json'
require 'jwt'
require 'json'
require 'fileutils'
require 'sequel'
require 'pg'

class App < Sinatra::Base
  # Database configuration
  configure do
    # Initialize database connection
    DB = Sequel.connect(
      adapter: 'postgres',
      host: ENV['DB_HOST'] || raise('DB_HOST environment variable is not set'),
      database: ENV['DB_NAME'] || raise('DB_NAME environment variable is not set'),
      user: ENV['DB_USER'] || raise('DB_USER environment variable is not set'),
      password: ENV['DB_PASSWORD'] || raise('DB_PASSWORD environment variable is not set')
    )

    # Create users table if it doesn't exist
    DB.create_table? :users do
      primary_key :id
      String :data, text: true
      DateTime :created_at
      DateTime :updated_at
    end
  end

  # Load secret key from environment variable
  SECRET_KEY = ENV['DEMO_SECRET_KEY']
  raise 'DEMO_SECRET_KEY environment variable is not set' unless SECRET_KEY

  TOKEN_FILE = '.token'

  # Load credentials from auth.json
  begin
    credentials = JSON.parse(File.read('auth.json'))
    VALID_USERNAME = credentials['username']
    VALID_PASSWORD = credentials['password']
  rescue StandardError => e
    raise "Error loading credentials from auth.json: #{e.message}"
  end

  # Create data directory if it doesn't exist
  DATA_DIR = 'data_files'
  FileUtils.mkdir_p(DATA_DIR)

  # Configure Sinatra
  configure do
    enable :logging
  end

  # Helper method to check if token is valid
  def valid_token?(token)
    begin
      decoded = JWT.decode(token, SECRET_KEY, true, algorithm: 'HS256')
      exp = decoded[0]['exp']
      # Return true if token hasn't expired
      return Time.now.to_i < exp
    rescue JWT::DecodeError
      false
    end
  end

  # Helper method to generate new token
  def generate_token(username)
    JWT.encode(
      {
        username: username,
        exp: Time.now.to_i + (24 * 3600)  # Token expires in 24 hours
      },
      SECRET_KEY,
      'HS256'
    )
  end

  # Helper method to read cached token
  def read_cached_token
    return nil unless File.exist?(TOKEN_FILE)
    begin
      data = JSON.parse(File.read(TOKEN_FILE))
      token = data['token']
      return token if valid_token?(token)
      nil
    rescue StandardError
      nil
    end
  end

  # Helper method to save token to cache
  def save_token_to_cache(token)
    begin
      puts "Attempting to save token to #{TOKEN_FILE}..."
      # Ensure we have write permissions by using File.open with write mode
      File.open(TOKEN_FILE, 'w', 0600) do |file|
        data = JSON.generate({ token: token })
        puts "Writing data: #{data}"
        file.write(data)
      end
      puts "Token successfully saved to cache"
      true  # Return true on success
    rescue StandardError => e
      puts "Error saving token to cache: #{e.message}"
      puts "Error backtrace: #{e.backtrace.join("\n")}"
      false  # Return false on failure
    end
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
      # First, check for cached valid token
      if cached_token = read_cached_token
        return json(
          message: 'Login successful (cached)',
          token: cached_token
        )
      end

      # If no valid cached token, proceed with authentication
      data = JSON.parse(request.body.read)
      username = data['username']
      password = data['password']

      unless username && password
        halt 400, json(error: 'Username and password are required')
      end

      if username == VALID_USERNAME && password == VALID_PASSWORD
        # Generate new token
        token = generate_token(username)

        # Save token to cache file
        save_token_to_cache(token)

        json(
          message: 'Login successful',
          token: token
        )
      else
        halt 401, json(error: 'Invalid credentials')
      end
    rescue JSON::ParserError
      halt 400, json(error: 'Invalid JSON data')
    rescue StandardError => e
      halt 500, json(error: "Login failed: #{e.message}")
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

      timestamp = Time.now
      data['current_time'] = timestamp.strftime('%Y-%m-%d %H:%M:%S')

      # Save to database
      user = DB[:users].insert(
        data: JSON.generate(data),
        created_at: timestamp,
        updated_at: timestamp
      )

      # Also save to file for backup
      filename = File.join(DATA_DIR, "data_#{timestamp.strftime('%Y%m%d_%H%M%S')}.txt")
      File.write(filename, JSON.pretty_generate(data))

      # Return response with database ID
      data['id'] = user
      json(data)
    rescue Sequel::Error => e
      halt 500, json(error: "Database error: #{e.message}")
    rescue JSON::ParserError
      halt 400, json(error: 'Invalid request data')
    rescue StandardError => e
      halt 500, json(error: "Failed to save data: #{e.message}")
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