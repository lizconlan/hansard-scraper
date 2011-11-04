require 'mongo_mapper'

class Fragment
  include MongoMapper::Document
  
  belongs_to :section
  many :paragraphs, :in => :paragraph_ids, :order => :sequence
  
  key :_type, String
  key :hansard_id, BSON::ObjectId
  key :title, String
  key :url, String
  key :paragraph_ids, Array
  key :columns, Array
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

class Debate < Fragment
  key :members, Array
  key :chair, String
end

class Intro < Fragment
end