require 'sinatra'
require 'haml'
require 'stylus'
require 'stylus/tilt'
require 'net/http'
require 'pg'

set :haml, format: :html5
set :public_folder, File.dirname(__FILE__) + '/static'
set :static_cache_control, [:public, max_age: 300]

@@max_participants = 60
@@api_url = ENV['SSO_API_URL'] || nil

if @@api_url.nil?
  raise 'Setup your SSO_API_URL first!'
end

get '/' do
  registered_participants = 0
  awaiting_participants = 0

  haml :index, layout: :default, locals: {
    title: 'Open Mind Proclub 2018',
    seats: @@max_participants - registered_participants,
    waiting_number: awaiting_participants,
  }
end

get '/stylesheet' do
  stylus :default
end

post '/register' do
  post = {
    username: params['username'],
    password: params['password'],
  }

  api = @@api_url % post
  uri = URI.parse api
  res = Net::HTTP.get uri || nil

  @msg = ''
  if res.nil?
    @msg = 'conerr'
  else
    json = JSON.parse res

    if json[0].kind_of?(NilClass)
      @msg = 'invalid'
    else
      pg_host = ENV['DATABASE_HOST']
      pg_port = ENV['DATABASE_PORT']
      pg_username = ENV['DATABASE_USERNAME']
      pg_password = ENV['DATABASE_PASSWORD']
      pg_database = ENV['DATABASE_NAME']

      pg = PG.connect(
        host: pg_host,
        port: pg_port,
        dbname: pg_database,
        user: pg_username,
        password: pg_password,
      )

      is_exists = pg.exec("SELECT COUNT(participant_username) FROM participant WHERE participant_username = '$1'", [post.username]) == 1

      if is_exists
        @msg = 'registered'
      else
        @msg = 'hehe'
      end
    end
  end

  JSON.generate({ response: @msg, raw: res })
end

get '/about' do
  haml :about, layout: :single, locals: {
    title: 'About This Application',
  }
end

not_found do
  haml :error404, layout: :single, locals: {
    title: 'Oopsie! 404 Not Found!',
  }
end

