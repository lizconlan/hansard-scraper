require 'mongo_mapper'

class Section
  include MongoMapper::Document
  
  belongs_to :hansard
  many :fragments, :in => :fragment_ids, :order => :sequence
  
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
  
  key :fragment_ids, Array
  key :name, String
  key :sequence, Integer
end