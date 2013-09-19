#encoding: utf-8

require 'mongo_mapper'
require 'htmlentities'

class Fragment
  include MongoMapper::Document
  
  belongs_to :section
  many :paragraphs, :in => :paragraph_ids, :order => :sequence
  
  key :_type, String
  key :section_id, BSON::ObjectId
  key :title, String
  key :url, String
  key :paragraph_ids, Array
  key :columns, Array
  key :sequence, Integer
  key :k_html, String
    
  def contributions_by_member(member_name)
    contribs = []
    contrib = []
    last_id = ""
    paras = Paragraph.by_member_and_fragment_id(member_name, id).all
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

class Debate < Fragment
  key :members, Array
  key :chair, String
end

class Statement < Fragment
  key :department, String
  key :members, Array
end

class Question < Fragment
  key :department, String
  key :subject, String
  key :members, Array
  key :number, String
  key :type, String
end

class Intro < Fragment
end