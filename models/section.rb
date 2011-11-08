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
  
  def contributions_by_member(member_name)
    contribs = []
    contrib = []
    last_id = ""
    paras = Paragraph.by_member_and_fragment_id_start(member_name, id).all
    paras.each do |para|
      unless para.contribution_id == last_id
        unless contribs.empty? and contrib.empty?
          contribs << contrib
          contrib = []
        end
      end
      contrib << para
      last_id = para.contribution_id
    end
    contribs << contrib unless contrib.empty?
    contribs
  end
end