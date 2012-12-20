# dev hint: shotgun login.rb

require "bcrypt"
require "rack-flash"
require "rubygems"
require "sinatra"

use Rack::Flash, :sweep => true

configure do
  set :public_folder, Proc.new { File.join(root, "static") }
  enable :sessions
end

helpers do
  def team_name
    session[:team_name] || "Guest"
  end

  def logged_in?
    session.has_key? :team_name
  end
end

get "/" do
  @teams = []
  erb :leader_board
end

get "/new" do
  require_login
  erb :upload
end

post "/new" do
  require_login
  FileUtils.mkdir_p File.join(settings.root, "teams")
  FileUtils.mv params[:data][:tempfile].path, File.join(settings.root, "teams", "#{session[:team_name]}.jar")
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
  File.exists? File.join(settings.root, "auth", filename_for_team(name))
end

def create_team name, password
  FileUtils.mkdir_p File.join(settings.root, "auth")
  salt = BCrypt::Engine.generate_salt
  encrypted_password = BCrypt::Engine.hash_secret(password, salt)
  File.open File.join(settings.root, "auth", filename_for_team(name)), "w" do |f|
    f.puts salt
    f.puts encrypted_password
  end
end

def log_in_as name, password
  salt, encrypted_password = File.read(File.join(settings.root, "auth", filename_for_team(name))).lines.map &:chomp
  unless encrypted_password == BCrypt::Engine.hash_secret(password, salt)
    flash.now[:error] = "Incorrect password, or you're trying to create a team with a name that already exists."
    halt erb(:login_form)
  end
end

def filename_for_team name
  name.gsub /[^\w]+/, "-"
end
