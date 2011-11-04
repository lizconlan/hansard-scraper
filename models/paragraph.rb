require 'mongo_mapper'

class Paragraph
  include MongoMapper::Document
  belongs_to :fragment
    
  key :_type, String
  key :debate_id, BSON::ObjectId
  key :url, String
  key :columns, Array
  key :text, String
  key :sequence, Integer
end

class Timestamp < Paragraph
end

class ContributionPara < Paragraph
  key :member, String
  key :prefix_html, String
end

class NonContributionPara < Paragraph
  key :description, String
end