require 'mongo_mapper'

class Paragraph
  include MongoMapper::Document
  belongs_to :fragment
    
  key :_type, String
  key :debate_id, BSON::ObjectId
  key :url, String
  key :column, String
  key :text, String
  key :sequence, Integer
  
  def self.by_member(member_name)
    where(:_type => "ContributionPara", :member => member_name)
  end
  
  def self.by_member_and_fragment_id(member_name, fragment_id)
    where(:_type => "ContributionPara", :member => member_name, :fragment_id => fragment_id).sort(:sequence)
  end
  
  def self.by_member_and_hansard_id(member_name, hansard_id)
    where(:_type => "ContributionPara", :member => member_name, :fragment_id => /^#{hansard_id}/).sort(:fragment_id, :sequence)
  end
end

class Timestamp < Paragraph
end

class ContributionPara < Paragraph
  key :member, String
  key :prefix_html, String
  key :contribution_id, String
end

class NonContributionPara < Paragraph
  key :description, String
end