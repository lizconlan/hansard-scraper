require 'mongo_mapper'

class DebateElement
  include MongoMapper::Document
  belongs_to :debate
    
  before_create { |d| d[:_type] = d.class.name }
  
  key :debate_id, BSON::ObjectId
  key :url, String
  key :columns, Array
  key :text, String
  key :sequence, Integer
end

class DebateTimestamp < DebateElement
end

class Contribution < DebateElement
  key :member
  key :prefix_html
end

class NonContributionText < DebateElement
end