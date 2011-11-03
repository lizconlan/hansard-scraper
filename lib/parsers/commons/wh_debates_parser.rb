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
    @count = 0
    @contribution_count = 0
    @sequence = 0

    @members = {}
    @section_members = {}
    @member = nil
    @contribution = nil
    
    @last_link = ""
    @snippet = []
    @intro = {:snippets => []}
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
          @snippet << snippet
          @subject = sanitize_text(text)
          @segment_link = "#{page.url}\##{@last_link}"
        when "h4"
          text = node.text.gsub("\n", "").squeeze(" ").strip
          if text[text.length-13..text.length-2] == "in the Chair"
            @chair = text[1..text.length-15]
          end
          @intro[:snippets] << text if @intro[:title]
        when "h5"
          #do timestamp stuff
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
                @contribution.segments << sanitize_text(text.gsub($1, "")).strip
              when /^(([^\(]*) \(([^\(]*)\):)/
                #we has a minister
                post = $2
                name = $3
                member = HansardMember.new(name, "", "", "", post)
                handle_contribution(@member, member, page)
                @contribution.segments << sanitize_text(text.gsub($1, "")).strip
              when /^(([^\(]*) \(([^\(]*)\) \(([^\(]*)\):)/
                #an MP speaking for the first time in the debate
                name = $2
                constituency = $3
                party = $4
                member = HansardMember.new(name, "", constituency, party)
                handle_contribution(@member, member, page)
                @contribution.segments << sanitize_text(text.gsub($1, "")).strip
              when /^(([^\(]*):)/
                #an MP who's spoken before
                name = $2
                member = HansardMember.new(name, name)
                handle_contribution(@member, member, page)
                @contribution.segments << sanitize_text(text.gsub($1, "")).strip
              else
                if @member
                  unless text =~ /^Sitting suspended|^Sitting adjourned|^On resuming|^Question put/ or
                      text == "#{@member.search_name} rose\342\200\224"
                    @contribution.segments << sanitize_text(text)
                  end
                end
            end
            snippet = Snippet.new
            snippet.text = sanitize_text(text)
            snippet.speaker = @member.index_name if @member
            @snippet << snippet
          end
      end
    end
    
    def store_debate(page)
      if @intro[:title]
        @sequence += 1
        intro_id = "#{@hansard_section.id}_s#{@sequence}" 
        intro = Intro.find_or_create_by_id(intro_id)
        intro.title = @intro[:title]
        intro.section = @hansard_section
        intro.sequence = @sequence
        
        @intro[:snippets].each do |snippet|
          @sequence += 1
          element_id = "#{intro.id}_e#{@sequence}"
          
          element = NonContributionText.find_or_create_by_id(element_id)
          element.fragment = intro
          element.text = snippet
          element.sequence = @sequence
          
          element.save
          intro.elements << element
        end
        intro.save
        @hansard_section.fragments << intro
        @hansard_section.save
        
        @intro = {:snippets => []}
      else
        handle_contribution(@member, @member, page)
      
        if @segment_link #no point storing pointers that don't link back to the source
          segment_id = "#{doc_id}_wh_#{@count}"
                  
          @count += 1
          names = []
          @members.each { |x, y| names << y.index_name unless names.include?(y.index_name) }
      
          column_text = ""
          if @start_column == @end_column or @end_column == ""
            column_text = @start_column
          else
            column_text = "#{@start_column} to #{@end_column}"
          end
        
          @debate = Debate.find_or_create_by_id(segment_id)
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
          
          @sequence += 1
          @debate.sequence = @sequence
          
          @snippet.each do |snippet|
            @sequence += 1
            element_id = "#{@debate.id}_e#{@sequence}"
            element = Contribution.find_or_create_by_id(element_id)
            element.text = snippet.text
            element.fragment = @debate
            element.member = snippet.speaker
            element.sequence = @sequence
            element.save
            @debate.elements << element
          end
        
          @debate.save

          @start_column = @end_column if @end_column != ""
      
          p @subject
          p segment_id
          p @segment_link
          p ""
      
          store_member_contributions
        end
      end
    end

end