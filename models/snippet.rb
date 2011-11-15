require 'mongo_mapper'
require 'sunspot'

class Snippet
  attr_reader :id, :subject, :volume, :part, :columns, :members, :text, :chair, :url, :house, :section, :published_at, :department, :question
  
  def initialize(doc)
    @id = doc[:id]
    @published_at = doc[:published_at]
    @text = doc[:search_text]
    @subject = doc[:subject]
    @volume = doc[:volume]
    @part = doc[:part]
    @columns = doc[:columns]
    @members = doc[:members]
    @chair = doc[:chair]
    @url = doc[:url]
    @house = doc[:house]
    @section = doc[:section]
    @department = doc[:department]
    @question = doc[:question]
  end
    
  Sunspot.setup(Snippet) do
    string :subject, :stored => true
    string :volume, :stored => true
    string :part, :stored => true
    string :columns, :stored => true
    text :members, :stored => true
    text :text, :stored => true
    string :chair, :stored => true
    string :url, :stored => true
    string :house, :stored => true
    string :section, :stored => true
    string :question, :stored => true
    string :department, :stored => true
    time :published_at, :stored => true
  end
end

class InstanceAdapter < Sunspot::Adapters::InstanceAdapter
   def id
     @instance.id
   end
 end

 class DataAccessor < Sunspot::Adapters::DataAccessor
   def load(id)
     ""
   end
   
   def load_all(ids)
     []
   end
 end
 
Sunspot::Adapters::DataAccessor.register(DataAccessor, Snippet)
Sunspot::Adapters::InstanceAdapter.register(InstanceAdapter, Snippet)