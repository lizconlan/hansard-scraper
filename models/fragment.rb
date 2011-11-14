require 'mongo_mapper'

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
  key :volume, String
  key :house, String
  key :part, String
  key :section_name, String
  key :date, String
  key :search_text, String
    
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
    prev_element = ""
    paragraphs.each do |para|
      case para._type
        when "Timestamp"
          html << "<div>#{para.text}</div>"
          prev_element = "timestamp"
        else
          if (para.text.strip[0..5] == "<table")
            if prev_element == "table"
              prev = html.pop
              
              old_table = prev.strip[0..prev.strip.rindex("</table")-1]
              new_table = para.html.strip[para.html.strip.index(">")+1..para.html.length]
              
              if old_table.strip[-8..old_table.length] == "</tbody>" and new_table.strip[0..6] == "<tbody>"
                old_table = old_table.strip[0..old_table.strip.rindex("</tbody")-1]
                new_table = new_table.strip[7..new_table.length]
              end
              
              html << "#{old_table}#{new_table}"
            else
              html << para.html
            end
            prev_element = "table"
          elsif (para.text.strip[0..0].to_i.to_s != para.text.strip[0..0]) and 
             (para.text.strip[0..0].downcase == para.text.strip[0..0]) and
             (para.text.strip[0..0] != '"')
            prev = html.pop
            prev.gsub!("</p>","")
            prev = "#{prev} #{para.text}</p>".squeeze(" ")
            html << prev
            prev_element = "para"
          else
            if para._type == "ContributionPara" and para.speaker_printed_name and para.text.strip =~ /^#{para.speaker_printed_name.gsub('(','\(').gsub(')','\)')}/
              html << "<p><b>#{para.speaker_printed_name}</b>#{para.text[para.speaker_printed_name.length..para.text.length]}"
            else
              html << "<p>#{para.text}</p>"
            end
            prev_element = "para"
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

class Statement < Fragment
  key :department, String
  key :members, Array
end

class Intro < Fragment
end