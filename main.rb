require 'sinatra'
require 'haml'
require 'stylus'
require 'stylus/tilt'
require 'net/http'
require 'pg'
require 'date'

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
    username: String.new(params['username']),
    password: String.new(params['password']),
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
      pg = PG.connect ENV['DATABASE_URL']

      is_exists = pg.exec_params("SELECT COUNT(participant_username) FROM participant WHERE participant_username = $1", [post[:username]]).values == 1

      if is_exists
        @msg = 'registered'
      else
        seats = @@max_participants - pg.exec_params("SELECT COUNT(participant_username) FROM participant").values

        if seats > 0
          query = pg.exec_params("INSERT INTO participant VALUES(, $1, $2, , , $3)", [post[:username], json[0][:email], DateTime.now])

          if query.result_status == PGRES_COMMAND_OK
            @msg = 'ok'
          end
        else
          query = pg.exec_params("INSERT INTO waiting_list VALUES(, $1, $2, $3)", [post[:username], json[0][:email], DateTime.now])

          if query.result_status == PGRES_COMMAND_OK
            @msg = 'awaiting'
          end
        end
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

