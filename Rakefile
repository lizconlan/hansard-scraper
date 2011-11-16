require 'rake'

require 'rubygems'
require 'bundler'
Bundler.setup

require 'mongo_mapper'
require 'time'

#parser libraries
require 'lib/parsers/commons/debates_parser'
require 'lib/parsers/commons/wh_debates_parser'
require 'lib/parsers/commons/wms_parser'
require 'lib/parsers/commons/written_answers_parser'


#indexer
require 'lib/indexer'

#persisted models
require 'models/hansard'
require 'models/section'
require 'models/fragment'
require 'models/paragraph'

#non-persisted models
require 'models/hansard_member'
require 'models/hansard_page'
require 'models/snippet'

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
  parser = DebatesParser.new(date)
  parser.parse_pages
  
  # parser = WHDebatesParser.new(date)
  # parser.parse_pages
  # 
  # parser = WMSParser.new(date)
  # parser.parse_pages
  # 
  # # TODO: Petitions
  # 
  # parser = WrittenAnswersParser.new(date)
  # parser.parse_pages
  # 
  # # TODO: Ministerial Corrections
end

desc "index a day's worth of hansard"
task :index_hansard do
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
  indexer = Indexer.new
  
  hansard = Hansard.find_by_date(date)
  hansard.sections.each do |section|
    section.fragments.each do |fragment|
      if fragment.columns.size > 1
        columns = "#{fragment.columns.first} to #{fragment.columns.last}"
      else
        columns = fragment.columns.first
      end
      snippet_hash = {
        :id => fragment.id,
        :published_at => Time.parse("#{fragment.date}T00:00:01Z"),
        :search_text => fragment.search_text,
        :subject => fragment.title,
        :volume => fragment.volume,
        :part => fragment.part,
        :columns => columns,
        :url => fragment.url,
        :house => fragment.house,
        :section => fragment.section_name
      }
      if fragment.respond_to?("members")
        snippet_hash[:members] = fragment.members
      end
      if fragment.respond_to?("chair")
        snippet_hash[:chair] = fragment.chair
      end
      if fragment.respond_to?("number")
        snippet_hash[:question] = fragment.number
      end
      if fragment.respond_to?("department")
        snippet_hash[:department] = fragment.department
      end
      snippet = Snippet.new(snippet_hash)
      indexer.add_document(snippet)
    end
  end
end