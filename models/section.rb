#encoding: utf-8

require 'mongo_mapper'

class Section
  include MongoMapper::Document
  
  belongs_to :daily_part
  many :fragments, :in => :fragment_ids, :order => :sequence
  
  def date
    daily_part.date
  end
  
  def volume
    daily_part.volume
  end
  
  def part
    daily_part.part
  end
  
  def house
    daily_part.house
  end
  
  key :fragment_ids, Array
  key :name, String
  key :sequence, Integer
  key :url, String
  
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
  
  def k_html_fragments
    k_fragments = []
    intro = ""
    dept = ""
    question_html = ""
    question_title = ""
    sequence = 0
    count = 0
    fragments.each do |fragment|
      count += 1
      case fragment._type
        when "Intro"
          if intro == "" 
            intro = fragment.k_html
          else
            intro = "#{intro}<p>&nbsp;#{fragment.k_html}"
          end
        else
          if name == "Written Answers" or name == "Written Ministerial Statements"
            if fragment.department != dept and dept != ""
              sequence += 1
              k_fragments << {:title => dept, :sequence => sequence, :html => question_html}
              dept = fragment.department
              question_html = fragment.k_html
            else
              unless intro == ""
                question_html = "#{intro}<p>&nbsp;</p>#{fragment.k_html}"
                intro = ""
              else
                question_html = "#{question_html}<p>&nbsp;</p>#{fragment.k_html}"
              end
              dept = fragment.department
            end
            if count == fragments.count
              sequence += 1
              k_fragments << {:title => fragment.department, :sequence => sequence, :html => "#{question_html}<p>&nbsp;</p>#{fragment.k_html}"}
            end
          elsif name == "Debates and Oral Answers"
            if fragment.title =~ /Topical Questions/
              question_title = "Topical Questions"
              if question_html == ""
                question_html = fragment.k_html
              else
                question_html = "#{question_html}<p>&nbsp;</p>#{fragment.k_html}"
              end
            else
              sequence += 1
              unless question_html == ""
                k_fragments << {:title => question_title, :sequence => sequence, :html => question_html}
                question_html = ""
                sequence += 1
              end
              if intro == ""
                k_fragments << {:title => fragment.title, :sequence => sequence, :html => fragment.k_html}
              else
                k_fragments << {:title => fragment.title, :sequence => sequence, :html => intro + "<p>&nbsp;</p>" + fragment.k_html}
                intro = ""
              end
            end
          else
            sequence += 1
            if intro == ""
              k_fragments << {:title => fragment.title, :sequence => sequence, :html => fragment.k_html}
            else
              k_fragments << {:title => fragment.title, :sequence => sequence, :html => intro + "<p>&nbsp;</p>" + fragment.k_html}
              intro = ""
            end
          end
      end
    end
    k_fragments.sort_by { |x| x[:sequence] }
  end
end