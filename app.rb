# dev hint: shotgun login.rb

require "bcrypt"
require "rubygems"
require "sinatra"

configure do
  set :public_folder, Proc.new { File.join(root, "static") }
  enable :sessions
end

helpers do
  def robot_name
    session[:robot_name] || "Guest"
  end

  def logged_in?
    session.has_key? :robot_name
  end
end

get "/" do
  erb :leader_board
end

get "/new" do
  require_login
  erb :upload
end

post "/new" do
  FileUtils.mkdir_p File.join(settings.root, "robots")
  FileUtils.mv params[:data][:tempfile].path, File.join(settings.root, "robots", "#{session[:robot_name]}.jar")
  erb 'Upload Complete'
end

get "/login/form" do 
  erb :login_form
end

post "/login/attempt" do
  robot_name, password = params.values_at("robot_name", "password")
  if robot_exists? robot_name
    log_in_as robot_name, password
  else
    create_robot robot_name, password
  end
  session[:robot_name] = robot_name
  where_user_came_from = session[:previous_url] || "/"
  redirect to where_user_came_from 
end

get "/logout" do
  session.delete(:robot_name)
  erb %{<div class="alert alert-message">Logged out</div>}
end

def require_login
  if !session[:robot_name] then
    session[:previous_url] = request["REQUEST_PATH"]
    @error = "Sorry, you need to be logged in to do that"
    halt erb(:login_form)
  end
end

def robot_exists? name
  File.exists? File.join(settings.root, "auth", filename_for_robot(name))
end

def create_robot name, password
  FileUtils.mkdir_p File.join(settings.root, "auth")
  salt = BCrypt::Engine.generate_salt
  encrypted_password = BCrypt::Engine.hash_secret(password, salt)
  File.open File.join(settings.root, "auth", filename_for_robot(name)), "w" do |f|
    f.puts salt
    f.puts encrypted_password
  end
end

def log_in_as name, password
  salt, encrypted_password = File.read(File.join(settings.root, "auth", filename_for_robot(name))).lines.map &:chomp
  unless encrypted_password == BCrypt::Engine.hash_secret(password, salt)
    @error = "Incorrect password, or you're trying to create a robot with a name that already exists."
    halt erb(:login_form)
  end
end

def filename_for_robot name
  name.gsub /[^\w]+/, "-"
end
