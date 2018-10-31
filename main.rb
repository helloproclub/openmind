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
  pg = PG.connect ENV['DATABASE_URL']

  registered_participants = pg.exec(
    "SELECT COUNT(participant_username) FROM participant;"
  ).values[0][0].to_i

  awaiting_participants = pg.exec(
    "SELECT COUNT(waiting_list_username) FROM waiting_list;"
  ).values[0][0].to_i

  pg.close

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
    if Net::HTTP.get_response(uri).code.to_i != 200
      @msg = 'mt'
    else
      json = JSON.parse res

      if json[0].kind_of?(NilClass)
        @msg = 'invalid'
      else
        pg = PG.connect ENV['DATABASE_URL']

        is_exists = pg.exec_params(
          "SELECT COUNT(participant_username) FROM participant " +
          "WHERE participant_username = $1;",
          [post[:username]]
        ).values[0][0].to_i == 1

        if is_exists
          @msg = 'registered'
        else
          seats = @@max_participants - pg.exec(
            "SELECT COUNT(participant_username) FROM participant;"
          ).values[0][0].to_i

          if seats > 0
            query = pg.exec_params(
              "INSERT INTO participant (" +
              "participant_username, participant_email, created_at" +
              ") " +
              "VALUES ($1, $2, $3);",
              [post[:username], json[0]['email'], DateTime.now],
            )

            if query.result_status == PG::Result::PGRES_COMMAND_OK
              @msg = 'ok'
            end
          else
            is_exists = pg.exec_params(
              "SELECT COUNT(waiting_list_username) FROM waiting_list " +
              "WHERE waiting_list_username = $1;",
              [post[:username]],
            ).values[0][0].to_i == 1

            if is_exists
              @msg = 'aregistered'
            else
              query = pg.exec_params(
                "INSERT INTO waiting_list (" +
                "waiting_list_username, waiting_list_email, created_at" +
                ") " +
                "VALUES ($1, $2, $3);",
                [post[:username], json[0]['email'], DateTime.now],
              )

              if query.result_status == PG::Result::PGRES_COMMAND_OK
                @msg = 'awaiting'
              end
            end
          end
        end

        pg.close
      end
    end
  end

  JSON.generate({ response: @msg })
end

get '/success' do
  haml :success, layout: :single, locals: {
    title: 'Yass! Success!',
  }
end

get '/cancel' do
  haml :cancel, layout: :single, locals: {
    title: 'Aww, why?!'
  }
end

post '/cancel' do
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
    if Net::HTTP.get_response(uri).code.to_i != 200
      @msg = 'mt'
    else
      json = JSON.parse res

      if json[0].kind_of?(NilClass)
        @msg = 'invalid'
      else
        pg = PG.connect ENV['DATABASE_URL']

        is_exists = pg.exec_params(
          "SELECT COUNT(participant_username) FROM participant " +
          "WHERE participant_username = $1;",
          [post[:username]]
        ).values[0][0].to_i == 1

        if is_exists
          delete = pg.exec_params(
            "DELETE FROM participant WHERE participant_username = $1;",
            [post[:username]],
          )

          if delete.result_status == PG::Result::PGRES_COMMAND_OK
            awaiting = pg.exec(
              "SELECT waiting_list_username, waiting_list_email " +
              "FROM waiting_list LIMIT 1;",
            ).values[0]

            awaiting_username = awaiting[0]
            awaiting_email = awaiting[1]

            query = pg.exec_params(
              "INSERT INTO participant (" +
              "participant_username, participant_email, created_at" +
              ") " +
              "VALUES ($1, $2, $3);",
              [awaiting_username, awaiting_email, DateTime.now],
            )

            if query.result_status == PG::Result::PGRES_COMMAND_OK
              pg.exec_params(
                "DELETE FROM waiting_list WHERE waiting_list_username = $1;",
                awaiting_username,
              )

              @msg = 'ok'
            end
          end
        else
          @msg = 'nexists'
        end

        pg.close
      end
    end
  end

  JSON.generate({ response: @msg })
end

get '/cancelled' do
  haml :cancelled, layout: :single, locals: {
    title: 'Aww :(',
  }
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

