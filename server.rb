require 'dotenv/load'
require 'sinatra'
require 'sinatra/reloader' if development?
require 'httparty'

set host: ENV.fetch('HOST').freeze
set consumer_key: ENV.fetch('POCKET_CONSUMER_KEY').freeze
set session_secret: ENV.fetch('SECRET').freeze
set alert_timeout: ENV.fetch('ALERT_TIMEOUT', 5).to_i
enable :sessions

get '/' do
  redirect to '/login' unless session[:pocket_access_token]

  if params[:url]
    response = HTTParty.post('https://getpocket.com/v3/add',
      headers: { 'Content-Type': 'application/json', 'X-Accept': 'application/json' },
      body: { url: params[:url], consumer_key: settings.consumer_key, access_token: session[:pocket_access_token] }.to_json,
    )

    if response.code.to_s.start_with?('2')
      @message = "Added '#{JSON.parse(response.body).fetch('title', params[:url])}'"
    else
      @error = 'something went wrong'
    end
  end

  erb :index
end

get '/login' do
  session[:pocket_auth_state] = SecureRandom.urlsafe_base64
  redirect_uri = "#{settings.development? ? 'http' : 'https'}://#{settings.host}/login/callback"
  response = HTTParty.post('https://getpocket.com/v3/oauth/request',
    headers: { 'Content-Type': 'application/json', 'X-Accept': 'application/json' },
    body: { redirect_uri:, consumer_key: settings.consumer_key, state: session[:pocket_auth_state] }.to_json,
  )

  halt 500, 'something went wrong' unless response.code.to_s.start_with?('2')

  session[:pocket_auth_code] = JSON.parse(response.body).fetch('code')
  redirect "https://getpocket.com/auth/authorize?request_token=#{session[:pocket_auth_code]}&redirect_uri=#{redirect_uri}"
end

get '/login/callback' do
  response = HTTParty.post('https://getpocket.com/v3/oauth/authorize',
    headers: { 'Content-Type': 'application/json', 'X-Accept': 'application/json' },
    body: { consumer_key: settings.consumer_key, code: session[:pocket_auth_code] }.to_json,
  )

  halt 500, 'something went wrong' unless response.code.to_s.start_with?('2')

  session[:pocket_access_token], session[:username] = JSON.parse(response.body).values_at('access_token', 'username')

  redirect to '/'
end
