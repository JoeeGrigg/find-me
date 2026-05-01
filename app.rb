require 'sinatra'

get '/' do
  @latitude = rand(-85.0..85.0).round(6)
  @longitude = rand(-180.0..180.0).round(6)

  map_delta = 0.05
  @map_bbox = [
    @longitude - map_delta,
    @latitude - map_delta,
    @longitude + map_delta,
    @latitude + map_delta
  ].map { |coordinate| coordinate.round(6) }.join(',')

  erb :index
end
