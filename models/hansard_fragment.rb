require 'mongo_mapper'
require 'sunspot'
require 'time'
require 'models/fragment'

class HansardFragment
  attr_reader :id, :subject, :volume, :part, :columns, :members, :text, :chair, :url, :house, :section, :published_at
  
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
  end
  
  def self.find(doc_id)
    frag = Fragment.find(doc_id)
    
    if frag.respond_to?("members")
      members = frag.members
    else
      members = []
    end
    
    if frag.respond_to?("chair")
      chair = frag.chair
    else
      chair = ""
    end
    
    if frag.columns.size > 1
      cols = frag.columns.first + " to " + frag.columns.last
    else
      cols = frag.columns.first
    end
    
    self.new({
      :id => frag.id,
      :published_at => Time.parse("#{frag.date}T00:00:01Z"),
      :text => frag.search_text,
      :subject => frag.title,
      :volume => frag.volume,
      :part => frag.part,
      :columns => cols,
      :members => members,
      :chair => chair,
      :url => frag.url,
      :house => frag.house,
      :section_name => frag.section_name
    })
  end
  
  Sunspot.setup(HansardFragment) do
    string :subject
    string :volume
    string :part
    string :columns
    text :members
    text :text, :stored => true
    string :chair
    string :url
    string :house
    string :section
    time :published_at
  end
end

class InstanceAdapter < Sunspot::Adapters::InstanceAdapter
   def id
     @instance.id
   end
 end

 class DataAccessor < Sunspot::Adapters::DataAccessor
   def load(id)
     HansardFragment.find(id)
   end
   
   def load_all(ids)
     ids.map { |id| HansardFragment.find(id) }
   end
 end
 
Sunspot::Adapters::DataAccessor.register(DataAccessor, HansardFragment)
Sunspot::Adapters::InstanceAdapter.register(InstanceAdapter, HansardFragment)