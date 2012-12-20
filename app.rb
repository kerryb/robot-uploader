# dev hint: shotgun login.rb

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

def require_login
  if !session[:robot_name] then
    session[:previous_url] = request["REQUEST_PATH"]
    @error = "Sorry, you need to be logged in to do that"
    halt erb(:login_form)
  end
end

get "/" do
  erb :leader_board
end

get "/new" do
  require_login
  erb :upload
end

get "/login/form" do 
  erb :login_form
end

post "/login/attempt" do
  session[:robot_name] = params["robot_name"]
  where_user_came_from = session[:previous_url] || "/"
  redirect to where_user_came_from 
end

get "/logout" do
  session.delete(:robot_name)
  erb %{<div class="alert alert-message">Logged out</div>}
end
