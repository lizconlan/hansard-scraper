require 'mongo_mapper'

class Debate
  include MongoMapper::Document
  
  belongs_to :section
  many :debate_elements, :in => :element_ids
  
  key :hansard_id, BSON::ObjectId
  key :url, String
  key :element_ids, Array
  key :columns, Array
  key :members, Array
  key :chair, String
  key :subject, String
  key :sequence, Integer
  
  def date
    section.date
  end
  
  def volume
    section.volume
  end
  
  def part
    section.part
  end
  
  def house
    section.house
  end
  
  def section
    section.name
  end
end