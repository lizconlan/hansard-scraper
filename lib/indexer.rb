require 'yaml'
require 'time'

require 'sunspot'

class Indexer
  def initialize
    Sunspot.config.solr.url = ENV['WEBSOLR_URL'] || YAML::load(File.read("config/websolr.yml"))[:websolr_url]
  end
  
  def add_document(fragment)  
    Sunspot.index(fragment)
    Sunspot.commit
  end
end