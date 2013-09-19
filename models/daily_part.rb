#encoding: utf-8

require 'mongo_mapper'

class DailyPart
  include MongoMapper::Document
  
  many :sections, :in => :section_ids, :order => :sequence
  
  key :date, String
  key :volume, String
  key :part, String
  key :house, String
  key :section_ids, Array
  
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