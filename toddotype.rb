require 'sinatra'
require 'json'
require 'data_mapper'

@@the_key = '9wk3u5d'
@@device_mapping = [
	:cdplayer1,
	:cdplayer2,
	:turntable1,
	:turntable2,
	:tapedeck,
	:computer
]

if ENV['HEROKU_POSTGRESQL_GOLD_URL']
  require 'dm-postgres-adapter'
else
  require 'dm-sqlite-adapter'
  require 'pry'
end

configure do 
	DataMapper.setup(:default, ENV['HEROKU_POSTGRESQL_GOLD_URL'] || "sqlite3:///#{Dir.pwd}/db/test.db")
	class Track
		include DataMapper::Resource
		property :id, Serial

		property :artist, String
		property :song,   String
		property :album,  String
		property :label,  String
		property :format, String	
		property :device, Integer

		property :played, Boolean, :default => false
		property :played_at, DateTime
		property :created_at, DateTime
	end
	DataMapper.auto_upgrade!
end

get '/' do
	erb :home, :locals => {:tracks => Track.all(:played => true), :device_mapping => @@device_mapping, :waiting_tracks => Track.all(:played => false) }
end

get '/playlist' do
	erb :playlist, :locals => {:tracks => Track.all(:played => true, :order => [:played_at.asc]) }
end

get '/queued' do
	erb :queued, :locals => {:waiting_tracks => Track.all(:played => false), :device_mapping => @@device_mapping }
end

post '/q' do
	if Track.first(:played=>false, :device=>params['device'].to_i).nil?
		Track.new(:artist => params['artist'], :song => params['song'], :album => params['album'],
						  :label => params['label'], :device => params['device'].to_i, :created_at => DateTime.now).save
	else
		"A track is already cued on #{@@device_mapping[params['device'].to_i].upcase}."
	end
end

post '/unq' do
	Track.first(:played=>false, :device => params['device']).destroy
end

post '/stations/:station' do |station|
	if params[:key] == @@the_key
		t = Track.first(:played => false, :device => params[:device])	
		if not t.nil?
			t.played = true
			t.played_at = DateTime.now
			d = @@device_mapping[params[:device].to_i].to_s.upcase
			if d.include? "CD"
				t.format = "CD"
			elsif d.include? "TAPE"
				t.format = "Tape cassette"
			elsif d.include? "TURN"
				t.format = "Vinyl"
			elsif d.include? "COMPUTER"
				t.format = "Computer"
			end
			t.save
			{:error => 0, :msg => 'Success.' }.to_json
		else
			{:error => 2, :msg => 'Bad post data.'}.to_json
		end
	else
		{:error => 1, :msg => 'Bad key.'}.to_json
	end
end

post '/manage_devices' do 
	(0..@@device_mapping.size-1).each do |i|
		if not params[i.to_s].nil?
			@@device_mapping[i] = params[i.to_s].to_sym
		end
	end
end
