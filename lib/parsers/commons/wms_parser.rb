require './lib/parser'

class WMSParser < Parser
  attr_reader :section, :section_prefix
  
  def initialize(date, house="Commons", section="Written Ministerial Statements")
    super(date, house)
    @section = section
    @section_prefix = "wms"
  end
  
  def get_section_index
    super("Written Statements")
  end
  
  def reset_vars
    @snippet = []
    @members = {}
    @section_members = {}
  end
  
  
  private
    def parse_node(node, page)
      case node.name
        when "h2"
          @intro[:title] = node.content
          @intro[:link] = "#{page.url}\##{@last_link}"
          @k_html << "<h1>#{node.content.strip}</h1>"
        when "a"
          process_links_and_columns(node)   
        when "h3"
          unless @snippet.empty? or @snippet.join("").length == 0
            store_debate(page)
            @snippet = []
            @segment_link = ""
          end
          
          text = node.text.gsub("\n", "").squeeze(" ").strip
          @department = sanitize_text(text)          
          @segment_link = "#{page.url}\##{@last_link}"
          @k_html << "<h3>#{@department}</h3>"
        when "h4"
          text = node.content.gsub("\n", "").squeeze(" ").strip
          
          if @intro[:title]
            @intro[:snippets] << text
            @intro[:columns] << @end_column
            @intro[:links] << "#{page.url}\##{@last_link}"
            @k_html << "<h2>#{text}</h2>"
          else
            unless @snippet.empty? or @snippet.join("").length == 0
              store_debate(page)
              @snippet = []
              @segment_link = ""
            end
            
            @subject = sanitize_text(text)
            @segment_link = "#{page.url}\##{@last_link}"
            @k_html << "<h4>#{@subject}</h4>"
          end
        when "table"
          if node.xpath("a") and node.xpath("a").length > 0
            @last_link = node.xpath("a").last.attr("name")
          end
          
          snippet = HansardSnippet.new
          snippet.text = node.to_html.gsub(/<a class="[^"]*" name="[^"]*">\s?<\/a>/, "")
          snippet.link = "#{page.url}\##{@last_link}"
          
          if @member
            snippet.speaker = @member.index_name
          end
          snippet.column = @end_column
          snippet.contribution_seq = @contribution_seq
          @snippet << snippet
          @k_html << html_fix(@coder.encode(snippet.text.strip, :named))
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
          
          text = node.text.gsub("\n", "").gsub(column_desc, "").squeeze(" ").strip
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
            
            snippet = HansardSnippet.new
            snippet.text = sanitize_text(text)
            snippet.link = "#{page.url}\##{@last_link}"
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
          
          unless snippet.text == ""
            if snippet.printed_name and snippet.text.strip =~ /^#{snippet.printed_name.gsub('(','\(').gsub(')','\)')}/
              k_html = "<p><b>#{@coder.encode(snippet.printed_name, :named)}</b>#{@coder.encode(snippet.text.strip[snippet.printed_name.length..snippet.text.strip.length], :named)}</p>"
              @k_html << html_fix(k_html.gsub("\t"," ").squeeze(" "))
            else
              @k_html << "<p>#{html_fix(@coder.encode(snippet.text.strip, :named))}</p>"
            end
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
        intro.url = @intro[:link]
        intro.sequence = @fragment_seq
        
        @intro[:snippets].each_with_index do |snippet, i|
          @para_seq += 1
          para_id = "#{intro.id}_p#{@para_seq.to_s.rjust(6, "0")}"
          
          para = NonContributionPara.find_or_create_by_id(para_id)
          para.fragment = intro
          para.text = snippet
          para.sequence = @para_seq
          para.url = @intro[:links][i]
          para.column = @intro[:columns][i]
          
          para.save
          intro.paragraphs << para
        end
        intro.columns = intro.paragraphs.collect{ |x| x.column }.uniq
        intro.k_html = @k_html.join("<p>&nbsp;</p>")
        
        intro.save
        @hansard_section.fragments << intro
        @hansard_section.save

        @intro = {:snippets => [], :columns => [], :links => []}
      else
        handle_contribution(@member, @member, page)
      
        if @segment_link #no point storing pointers that don't link back to the source
          @fragment_seq += 1
          segment_id = "#{@hansard_section.id}_#{@fragment_seq.to_s.rjust(6, "0")}"
                        
          column_text = ""
          if @start_column == @end_column or @end_column == ""
            column_text = @start_column
          else
            column_text = "#{@start_column} to #{@end_column}"
          end
        
          @statement = Statement.find_or_create_by_id(segment_id)
          @statement.k_html = @k_html.join("<p>&nbsp;</p>")
          @para_seq = 0
          @hansard_section.fragments << @statement
          @hansard_section.save
        
          @daily_part.volume = page.volume
          @daily_part.part = sanitize_text(page.part.to_s)
          @daily_part.save
        
          @statement.section = @hansard_section

          @statement.title = @subject
          @statement.department = @department
          @statement.url = @segment_link
          
          @statement.sequence = @fragment_seq
          
          @snippet.each do |snippet|
            unless snippet.text == @statement.title or snippet.text == ""
              @para_seq += 1
              para_id = "#{@statement.id}_p#{@para_seq.to_s.rjust(6, "0")}"
              
              case snippet.desc
                when "timestamp"
                  para = Timestamp.find_or_create_by_id(para_id)
                  para.text = snippet.text
                else
                  if snippet.speaker.nil?
                    para = NonContributionPara.find_or_create_by_id(para_id)
                    para.text = snippet.text
                  elsif snippet.text.strip[0..5] == "<table"
                    para = ContributionTable.find_or_create_by_id(para_id)
                    para.member = snippet.speaker
                    para.contribution_id = "#{@statement.id}__#{snippet.contribution_seq.to_s.rjust(6, "0")}"
                    para.html = snippet.text.strip
                    
                    table = Nokogiri::HTML(snippet.text)
                    para.text = table.content
                  else
                    para = ContributionPara.find_or_create_by_id(para_id)
                    para.member = snippet.speaker
                    para.contribution_id = "#{@statement.id}__#{snippet.contribution_seq.to_s.rjust(6, "0")}"
                    if snippet.text.strip =~ /^#{snippet.printed_name.gsub('(','\(').gsub(')','\)')}/
                      para.speaker_printed_name = snippet.printed_name
                    end
                    para.text = snippet.text
                  end
              end
              
              para.url = snippet.link
              para.column = snippet.column
              para.sequence = @para_seq
              para.fragment = @statement
              para.save
              
              @statement.paragraphs << para
            end
          end
          
          @statement.columns = @statement.paragraphs.collect{|x| x.column}.uniq
          @statement.members = @statement.paragraphs.collect{|x| x.member}.uniq
          @statement.save
          @start_column = @end_column if @end_column != ""
          
          unless ENV["RACK_ENV"] == "test"
            p @subject
            p segment_id
            p @segment_link
            p ""
          end
        end
      end
      reset_vars()
      @k_html = []
    end
    
end