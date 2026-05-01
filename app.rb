require 'digest'
require 'dotenv'

Dotenv.load(File.join(__dir__, '.env')) if File.file?(File.join(__dir__, '.env'))

require 'http'
require 'json'
require 'securerandom'
require 'sinatra'

OWNTRACKS_TIMEOUT_SECONDS = 5

use Rack::Auth::Basic, 'Restricted Area' do |username, password|
  expected_username = ENV.fetch('BASIC_AUTH_USERNAME', '')
  expected_password = ENV.fetch('BASIC_AUTH_PASSWORD', '')

  next false if expected_username.empty? || expected_password.empty?

  Rack::Utils.secure_compare(Digest::SHA256.hexdigest(username.to_s), Digest::SHA256.hexdigest(expected_username)) &
    Rack::Utils.secure_compare(Digest::SHA256.hexdigest(password.to_s), Digest::SHA256.hexdigest(expected_password))
end

helpers do
  def owntracks_url
    host = ENV.fetch('OWNTRACKS_HOST', '').strip
    return nil if host.empty?

    base_url = host.match?(%r{\Ahttps?://}) ? host : "https://#{host}"
    "#{base_url.chomp('/')}/api/0/last"
  end

  def request_owntracks
    url = owntracks_url
    return [nil, 'OWNTRACKS_HOST is not set'] unless url

    username = ENV.fetch('OWNTRACKS_USERNAME', '').strip
    password = ENV.fetch('OWNTRACKS_PASSWORD', '')
    return [nil, 'OWNTRACKS_USERNAME is not set'] if username.empty?
    return [nil, 'OWNTRACKS_PASSWORD is not set'] if password.empty?

    response = HTTP
      .timeout(connect: OWNTRACKS_TIMEOUT_SECONDS, read: OWNTRACKS_TIMEOUT_SECONDS)
      .basic_auth(user: username, pass: password)
      .get(url)

    [response, nil]
  rescue StandardError => e
    [nil, "OwnTracks request failed: #{e.class}: #{e.message}"]
  end
end

get '/' do
  response, error = request_owntracks

  unless response
    status 503
    content_type :json
    return JSON.generate(error: error)
  end

  json_body = JSON.parse(response.body)
  device = ENV.fetch('OWNTRACKS_DEVICE', '').strip
  device_data = json_body.find { |x| x["device"] == device }

  unless device_data
    status 502
    content_type :json
    return JSON.generate(error: "OwnTracks device not found: #{device.empty? ? 'OWNTRACKS_DEVICE is not set' : device}")
  end

  @latitude = device_data["lat"]
  @longitude = device_data["lon"]
  battery_value = device_data["batt"] || device_data["battery"] || device_data["B"]
  @battery_percentage = case battery_value
                        when Numeric
                          battery_value.round
                        when String
                          battery_value.strip.match?(/\A\d+(?:\.\d+)?\z/) ? battery_value.to_f.round : nil
                        end

  unless @latitude && @longitude
    status 502
    content_type :json
    return JSON.generate(error: "OwnTracks location is missing lat/lon for device: #{device}")
  end

  map_delta = 0.05
  @map_bbox = [
    @longitude - map_delta,
    @latitude - map_delta,
    @longitude + map_delta,
    @latitude + map_delta
  ].map { |coordinate| coordinate.round(6) }.join(',')

  erb :index
end
