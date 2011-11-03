require 'mongo_mapper'

class Element
  include MongoMapper::Document
  belongs_to :fragment
    
  key :_type, String
  key :debate_id, BSON::ObjectId
  key :url, String
  key :columns, Array
  key :text, String
  key :sequence, Integer
end

class Timestamp < Element
end

class Contribution < Element
  key :member, String
  key :prefix_html, String
end

class NonContributionText < Element
  key :description, String
end