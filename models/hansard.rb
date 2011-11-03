require 'mongo_mapper'

class Hansard
  include MongoMapper::Document
  
  many :sections, :in => :section_ids, :order => :sequence
  
  key :date, String
  key :volume, String
  key :part, String
  key :house, String
  key :section_ids, Array
end