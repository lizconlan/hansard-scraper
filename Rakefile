require 'rake'

require 'rubygems'
require 'bundler'
Bundler.setup

require 'mongo_mapper'

#parser libraries
require 'lib/parsers/commons/wh_debates_parser'
#require 'lib/parsers/commons/debates_parser'
#require 'lib/parsers/commons/wms_parser'
#require 'lib/parsers/commons/written_answers_parser'

#persisted models
require 'models/hansard'
require 'models/section'
require 'models/fragment'
require 'models/paragraph'

#non-persisted models
require 'models/hansard_member'
require 'models/hansard_page'

MONGO_URL = ENV['MONGOHQ_URL'] || YAML::load(File.read("config/mongo.yml"))[:mongohq_url]

env = {}
MongoMapper.config = { env => {'uri' => MONGO_URL} }
MongoMapper.connect(env)

desc "scrape a day's worth of hansard"
task :scrape_hansard do
  date = ENV['date']

  #make sure date has been supplied and is valid
  unless date
    raise 'need to specify date in yyyy-mm-dd format'
  else
    unless date =~ /^\d{4}-\d{2}-\d{2}$/
      raise 'need to specify date in yyyy-mm-dd format'
    end
  end
  Date.parse(date)

  #great, go
  parser = WHDebatesParser.new(date)
  parser.parse_pages
end