require 'rubygems'

#setup gem environment
require 'bundler'
Bundler.setup

require File.dirname(__FILE__) + "/server"
# set :app_file, File.expand_path(File.dirname(__FILE__) + '/server.rb')

set :logging, false
disable :run, :reload

run Sinatra::Application