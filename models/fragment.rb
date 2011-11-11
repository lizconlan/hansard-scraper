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
  
  def to_simple_html
    html = []
    paragraphs.each do |para|
      case para._type
        when "Timestamp"
          html << "<div>#{para.text}</div>"
        else
          if (para.text.strip[0..0].to_i.to_s != para.text.strip[0..0]) and 
             (para.text.strip[0..0].downcase == para.text.strip[0..0]) and
             (para.text.strip[0..0] != '"')
            prev = html.pop
            prev.gsub!("</p>","")
            prev = "#{prev} #{para.text}</p>".squeeze(" ")
            html << prev
          else
            if para._type == "ContributionPara" and para.speaker_printed_name and para.text.strip =~ /^#{para.speaker_printed_name.gsub('(','\(').gsub(')','\)')}/
              html << "<p><b>#{para.speaker_printed_name}</b>#{para.text[para.speaker_printed_name.length..para.text.length]}"
            else
              html << "<p>#{para.text}</p>"
            end
          end
      end
    end
    html = html.join("<p>&nbsp;</p>")
    "#{url}<h1>#{title}</h1> #{html}"
  end
end

class Debate < Fragment
  key :members, Array
  key :chair, String
end

class Intro < Fragment
end