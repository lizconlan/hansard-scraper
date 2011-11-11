require 'lib/parser'

class WHDebatesParser < Parser
  attr_reader :section, :section_prefix
  
  def initialize(date, house="Commons", section="Westminster Hall")
    super(date, house)
    @section = section
    @section_prefix = "wh"
  end
  
  def get_section_index
    super(section)
  end
  
  def init_vars
    @page = 0
    @section_seq = 0
    @fragment_seq = 0
    @para_seq = 0
    @contribution_seq = 0

    @members = {}
    @section_members = {}
    @member = nil
    @contribution = nil
    
    @last_link = ""
    @snippet = []
    @intro = {:snippets => [], :columns => []}
    @subject = ""
    @start_column = ""
    @end_column = ""
    
    @chair = ""
  end
  
  def reset_vars
    @snippet = []
  end
  
  
  private
    def parse_node(node, page)
      case node.name
        when "h2"
          @intro[:title] = node.content
        when "a"
          process_links_and_columns(node)
        when "h3"
          unless @snippet.empty?
            store_debate(page)
            @snippet = []
            @segment_link = ""
          end
          text = node.text.gsub("\n", "").squeeze(" ").strip
          snippet = Snippet.new
          snippet.text = sanitize_text(text)
          snippet.column = @end_column
          @snippet << snippet
          @subject = sanitize_text(text)
          @segment_link = "#{page.url}\##{@last_link}"
        when "h4"
          text = node.text.gsub("\n", "").squeeze(" ").strip
          if text[text.length-13..text.length-2] == "in the Chair"
            @chair = text[1..text.length-15]
          end
          if @intro[:title]
            @intro[:snippets] << text
            @intro[:columns] << @end_column
          end
        when "h5"
          snippet = Snippet.new
          snippet.text = node.text
          snippet.desc = "timestamp"
          snippet.column = @end_column
          @snippet << snippet
        when "p" 
          column_desc = ""
          member_name = ""
          if node.xpath("a") and node.xpath("a").length > 0
            @last_link = node.xpath("a").last.attr("name")
          end
          unless node.xpath("b").empty?
            node.xpath("b").each do |bold|
              if bold.text =~ /^\d+ [A-Z][a-z]+ \d{4} : Column (\d+(?:WH)?(?:WS)?(?:P)?(?:W)?)(?:-continued)?$/  #older page format
                if @start_column == ""
                  @start_column = $1
                else
                  @end_column = $1
                end
                column_desc = bold.text
              else 
                member_name = bold.text.strip
              end
            end
          else
            member_name = ""
          end
          
          text = node.content.gsub("\n", "").gsub(column_desc, "").squeeze(" ").strip
          if node.xpath("i").first
            italic_text = node.xpath("i").first.content
          else
            italic_text = ""
          end
          
          if text[text.length-13..text.length-2] == "in the Chair"
            @chair = text[1..text.length-15]
          end
          
          #ignore column heading text
          unless text =~ /^\d+ [A-Z][a-z]+ \d{4} : Column (\d+(?:WH)?(?:WS)?(?:P)?(?:W)?)(?:-continued)?$/
            #check if this is a new contrib
            case member_name
              when /^(([^\(]*) \(in the Chair\):)/
                #the Chair
                name = $2
                post = "Debate Chair"
                member = HansardMember.new(name, name, "", "", post)
                handle_contribution(@member, member, page)
                @contribution_seq += 1
              when /^(([^\(]*) \(([^\(]*)\):)/
                #we has a minister
                post = $2
                name = $3
                member = HansardMember.new(name, "", "", "", post)
                handle_contribution(@member, member, page)
                @contribution_seq += 1                
              when /^(([^\(]*) \(([^\(]*)\) \(([^\(]*)\):)/
                #an MP speaking for the first time in the debate
                name = $2
                constituency = $3
                party = $4
                member = HansardMember.new(name, "", constituency, party)
                handle_contribution(@member, member, page)
                @contribution_seq += 1
              when /^(([^\(]*):)/
                #an MP who's spoken before
                name = $2
                member = HansardMember.new(name, name)
                handle_contribution(@member, member, page)                
                @contribution_seq += 1
              else
                if text == "#{member_name} #{italic_text}".squeeze(" ")
                  member = HansardMember.new(member_name, member_name)
                  handle_contribution(@member, member, page)
                  @contribution_seq += 1
                end
            end              
              
            snippet = Snippet.new
            snippet.text = sanitize_text(text)       
            if @member
              if snippet.text =~ /^#{@member.post} \(#{@member.name}\)/
                snippet.printed_name = "#{@member.post} (#{@member.name})"
              elsif snippet.text =~ /^#{@member.search_name}/
                snippet.printed_name = @member.search_name
              else
                snippet.printed_name = @member.printed_name
              end
              snippet.speaker = @member.index_name
            end
            snippet.column = @end_column
            snippet.contribution_seq = @contribution_seq
            @snippet << snippet
          end
      end
    end
    
    def store_debate(page)
      if @intro[:title]
        @fragment_seq += 1
        intro_id = "#{@hansard_section.id}_#{@fragment_seq.to_s.rjust(6, "0")}"
        intro = Intro.find_or_create_by_id(intro_id)
        @para_seq += 1
        intro.title = @intro[:title]
        intro.section = @hansard_section
        intro.sequence = @fragment_seq
        
        @intro[:snippets].each_with_index do |snippet, i|
          @para_seq += 1
          para_id = "#{intro.id}_e#{@para_seq.to_s.rjust(6, "0")}"
          
          para = NonContributionPara.find_or_create_by_id(para_id)
          para.fragment = intro
          para.text = snippet
          para.sequence = @para_seq
          para.column = @intro[:columns][i]
          
          para.save
          intro.paragraphs << para
        end
        
        intro.save
        @hansard_section.fragments << intro
        @hansard_section.save

        @intro = {:snippets => []}
      else
        handle_contribution(@member, @member, page)
      
        if @segment_link #no point storing pointers that don't link back to the source
          @fragment_seq += 1
          segment_id = "#{@hansard_section.id}_#{@fragment_seq.to_s.rjust(6, "0")}"
                  
          names = []
          @members.each { |x, y| names << y.index_name unless names.include?(y.index_name) }
      
          column_text = ""
          if @start_column == @end_column or @end_column == ""
            column_text = @start_column
          else
            column_text = "#{@start_column} to #{@end_column}"
          end
        
          @debate = Debate.find_or_create_by_id(segment_id)
          @para_seq = 0
          @hansard_section.fragments << @debate
          @hansard_section.save
        
          @hansard.volume = page.volume
          @hansard.part = sanitize_text(page.part.to_s)
          @hansard.save
        
          @debate.section = @hansard_section
          @debate.members = names

          @debate.title = @subject
          @debate.chair = @chair
          @debate.url = @segment_link
          
          @fragment_seq += 1
          @debate.sequence = @fragment_seq
          @debate.volume = page.volume
          @debate.house = @hansard.house
          @debate.section_name = @hansard_section.name
          @debate.part = @hansard.part
          @debate.date = @hansard.date
          
          search_text = []
          
          @snippet.each do |snippet|
            unless snippet.text == @debate.title or snippet.text == ""
              @para_seq += 1
              para_id = "#{@debate.id}_p#{@para_seq.to_s.rjust(6, "0")}"
              
              case snippet.desc
                when "timestamp"
                  para = Timestamp.find_or_create_by_id(para_id)
                else
                  if snippet.speaker.nil?
                    para = NonContributionPara.find_or_create_by_id(para_id)
                  else
                    para = ContributionPara.find_or_create_by_id(para_id)
                    para.member = snippet.speaker
                    para.contribution_id = "#{@debate.id}__#{snippet.contribution_seq.to_s.rjust(6, "0")}"
                    if snippet.text.strip =~ /^#{snippet.printed_name.gsub('(','\(').gsub(')','\)')}/
                      para.speaker_printed_name = snippet.printed_name
                    end
                  end
              end
              
              para.text = snippet.text
              search_text << snippet.text
              para.column = snippet.column
              para.sequence = @para_seq
              para.fragment = @debate
              para.save
              
              @debate.search_text = search_text.join(" ")
              
              @debate.paragraphs << para
            end
          end
          
          @debate.columns = @debate.paragraphs.collect{|x| x.column}.uniq
          @debate.save
          @start_column = @end_column if @end_column != ""
      
          p @subject
          p segment_id
          p @segment_link
          p ""
        end
      end
    end

end