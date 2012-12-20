# dev hint: shotgun login.rb

require "bcrypt"
require "rack-flash"
require "rubygems"
require "sinatra"
require "yaml"

use Rack::Flash, :sweep => true

configure do
  set :public_folder, Proc.new { File.join(root, "static") }
  enable :sessions
end

Team = Struct.new :name, :salt, :encrypted_password, :robot_name, :scores

FileUtils.mkdir_p File.join(settings.root, "teams")

helpers do
  def team_name
    session[:team_name] || "Guest"
  end

  def logged_in?
    session.has_key? :team_name
  end
end

get "/" do
  @teams = read_teams
  erb :leader_board
end

get "/new" do
  require_login
  erb :upload
end

post "/new" do
  require_login
  FileUtils.mv params[:data][:tempfile].path, filename_for_team(session[:team_name], "jar")
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
  flash[:notice] = "Logged in"
  redirect to session[:previous_url] || "/"
end

get "/logout" do
  session.delete(:team_name)
  flash[:notice] = "Logged out"
  redirect to "/"
end

def require_login
  if !session[:team_name] then
    session[:previous_url] = request["REQUEST_PATH"]
    flash.now[:error] = "Please log in"
    halt erb(:login_form)
  end
end

def team_exists? name
  File.exists? filename_for_team(name)
end

def create_team name, password
  salt = BCrypt::Engine.generate_salt
  encrypted_password = BCrypt::Engine.hash_secret(password, salt)
  write_team_data name, Team.new(name, salt, encrypted_password)
end

def log_in_as name, password
  salt, encrypted_password = File.read(filename_for_team(name)).lines.map &:chomp
  unless encrypted_password == BCrypt::Engine.hash_secret(password, salt)
    flash.now[:error] = "Incorrect password, or you're trying to create a team with a name that already exists."
    halt erb(:login_form)
  end
end

def read_teams
  Dir[File.join settings.root, "teams", "*.yml"].map {|f| YAML.load File.read(f) }
end

def filename_for_team name, extension = "yml"
  "#{File.join(settings.root, "teams", name.gsub(/[^\w]+/, "-"))}.#{extension}"
end

def write_team_data name, data
  File.open filename_for_team(name), "w" do |f|
    f.write data.to_yaml
  end
end

def read_team_data name
  YAML.load File.read(filename_for_team name)
end
