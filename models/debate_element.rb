require 'mongo_mapper'

class DebateElement
  include MongoMapper::Document
  belongs_to :fragment
    
  before_create { |d| d[:_type] = d.class.name }
  
  key :fragment_id, BSON::ObjectId
  key :url, String
  key :columns, Array
  key :text, String
  key :sequence, Integer
end

class Timestamp < DebateElement
end

class Contribution < DebateElement
  key :member
end

class NonContributionText < DebateElement
end