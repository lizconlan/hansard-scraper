require 'mongo_mapper'

class Section
  include MongoMapper::Document
  
  belongs_to :hansard
  many :debates, :in => :debate_ids
  
  def date
    hansard.date
  end
  
  def volume
    hansard.volume
  end
  
  def part
    hansard.part
  end
  
  def house
    hansard.house
  end
  
  key :debate_ids, Array
  key :name, String
  key :sequence, Integer
end