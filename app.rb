# dev hint: shotgun login.rb

require "bcrypt"
require "csv"
require "rack-flash"
require "rubygems"
require "sinatra"
require "yaml"
require "zippy"

use Rack::Flash, :sweep => true

configure do
  enable :sessions
end

Team = Struct.new :name, :salt, :encrypted_password, :robot_name, :scores do
  def total_score
    scores.inject 0, &:+
  end
end

FileUtils.mkdir_p %w{teams robots scores}.map {|dir| File.join(settings.root, dir) }

helpers do
  def team_name
    session[:team_name]
  end

  def logged_in?
    session.has_key? :team_name
  end
end

get "/" do
  @scores = read_scores
  @teams = read_teams(@scores).sort_by(&:total_score).reverse
  erb :leader_board
end

get "/new" do
  require_login
  erb :upload
end

post "/new" do
  require_login
  require "pp"
  pp params
  unless params[:data] && !params[:data].empty?
    flash[:error] = "Please select a file"
    halt erb :upload
  end
  upload_robot params[:data][:tempfile]
  flash[:notice] = "Robot uploaded"
  redirect to "/"
end

get "/login" do 
  erb :login_form
end

post "/login" do
  team_name, password = params.values_at("team_name", "password")
  if team_exists? team_name
    log_in_as team_name, password
  else
    create_team team_name, password
  end
  session[:team_name] = team_name
  redirect to "/"
end

get "/logout" do
  session.delete(:team_name)
  flash[:notice] = "Logged out"
  redirect to "/"
end

get "/robots/:name" do
  send_file File.join(settings.root, "robots", params[:name])
end

def require_login
  if !session[:team_name] then
    flash.now[:error] = "Please log in"
    halt erb(:login_form)
  end
end

def team_exists? name
  File.exists? filename_for_team(name)
end

def create_team name, password
  if name.empty? || password.empty?
    flash[:error] = "Please supply a team name and password"
    halt erb :login_form
  end
  salt = BCrypt::Engine.generate_salt
  encrypted_password = BCrypt::Engine.hash_secret(password, salt)
  write_team name, Team.new(name, salt, encrypted_password)
  flash[:notice] = "Team created"
end

def log_in_as name, password
  team = read_team name
  if team.encrypted_password == BCrypt::Engine.hash_secret(password, team.salt)
    flash[:notice] = "Logged in"
  else
    flash.now[:error] = "Incorrect password, or you're trying to create a team with a name that already exists."
    halt erb(:login_form)
  end
end

def upload_robot data_path
  team_name = session[:team_name]
  jar_file = filename_for_team(team_name, "jar", "robots")
  FileUtils.mv data_path, jar_file
  Zippy.open(jar_file) do |zip|
    properties = zip[zip.grep(/properties$/).first]
    team = read_team team_name
    team.robot_name = properties.lines.grep(/^robot.classname=/).first.split("=").last.chomp
    write_team team_name, team
  end
end

def read_scores
  Dir[File.join settings.root, "scores", "*.csv"].sort.map {|f|
    Hash.new { 0 }.tap do |scores|
      CSV.read(f).drop(3).reverse.drop(1).each_with_index.map {|row, points|
        scores[row[1].split.first] = points + 1
      }
    end
  }
end

def read_teams scores
  Dir[File.join settings.root, "teams", "*.yml"].map {|f|
    YAML.load(File.read(f)).tap do |team|
      team.scores = scores.map {|round| round[team.robot_name] }
    end
  }
end

def filename_for_team name, extension = "yml", dir = "teams"
  "#{File.join(settings.root, dir, name.gsub(/[^\w]+/, "-"))}.#{extension}"
end

def write_team name, team
  File.open filename_for_team(name), "w" do |f|
    f.write team.to_yaml
  end
end

def read_team name
  YAML.load File.read(filename_for_team name)
end
