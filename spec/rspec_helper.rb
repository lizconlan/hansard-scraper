if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start do
    add_filter 'spec'
  end
end

RSpec.configure do |config|
  config.mock_framework = :mocha
end

ENV["RACK_ENV"] = "test" unless ENV["RACK_ENV"]

require 'rspec/autorun'
require "mocha/api"