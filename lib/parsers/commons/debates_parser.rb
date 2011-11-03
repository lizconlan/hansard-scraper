require 'lib/parser'

class DebatesParser < Parser
  attr_reader :section
  
  def initialize(date, house="Commons", section="Debates and Oral Answers")
    super(date, house)
    @section = section
    @section_prefix = ""
  end
  
  def get_section_index
    super(section)
  end
  
  def init_vars
    @column = ""
    @page = 0
    @count = 0
    @contribution_count = 0
    
    @members = {}
    @member = nil
    @section_members = {}
    @contribution = nil
    
    @last_link = ""
    @snippet = []
    @subject = ""
    @department = ""
    @start_column = ""
    @end_column = ""
    @questions = []
    @question_no = ""
    @petitions = []
    
    @subsection = ""
  end
  
  def reset_vars
    @snippet = []
    @questions = []
    @petitions = []
  end
  
  
  private
    def parse_node(node, page)
      case node.name
        when "a"
          process_links_and_columns(node)
          determine_snippet_type(node)
        when "h2"
          text = node.text.gsub("\n", "").squeeze(" ").strip
          @snippet << sanitize_text(text)
          if text == "Oral Answers to Questions"
            @subsection = "Oral Answer"
          end
        when "h3"
          text = node.text.gsub("\n", "").squeeze(" ").strip
          if @snippet_type == "department heading" and @subsection == "Oral Answer"
            @department = sanitize_text(text)
          else
            if text.downcase == "prayers"
              @subject = text
              @subsection = ""
            else
              unless @snippet.empty? or @snippet.join("").length == 0
                store_debate(page)
                @snippet = []
                @segment_link = ""
                @questions = []
                @petitions = []
                @section_members = {}
              end
              case text.downcase
                when "business without debate"
                  @subsection = ""
                when /^business/,
                     "european union documents",
                     "points of order",
                     "royal assent",
                     "bill presented"
                  @subject = text
                  @subsection = ""
                when "petition"
                  @subsection = "Petition"
                when /adjournment/
                  @subsection = "Adjournment Debate"
                else
                  if @subsection == ""
                    @subsection = "Debate"
                  end
              end
              unless text.downcase == "petition"
                @snippet << sanitize_text(text)
                @subject = sanitize_text(text)
                @segment_link = "#{page.url}\##{@last_link}"
              end
            end
          end
        when "h4"
          text = node.text.gsub("\n", "").squeeze(" ").strip
          if @subject.downcase == "prayers"
            #ignore
          elsif text.downcase == "backbench business"
            #treat as honourary h3
            unless @snippet.empty? or @snippet.join("").length == 0
              store_debate(page)
              @snippet = []
              @segment_link = ""
              @questions = []
              @petitions = []
              @section_members = {}
            end
            @subsection = "Debate"
          else
            @snippet << sanitize_text(text)
          end
        when "h5"
          text = node.text.gsub("\n", "").squeeze(" ").strip
          @snippet << sanitize_text(text)
        when "p"
          column_desc = ""
          member_name = ""
          
          if @subsection == "Debate"
            if node.xpath("i") and node.xpath("i").length > 0
              case node.xpath("i").first.text.strip
                when /^Motion/
                  unless (node.xpath("i").collect { |x| x.text }).join(" ") =~ /and Question p/
                    @subsection = "Motion"
                  end
                when /^Debate resumed/
                  @subject = "#{@subject} (resumed)"
                when /^Ordered/
                  @subsection = ""
              end
            end
          end
          
          if @snippet.empty? and node.xpath("center") and node.xpath("center").text == node.text
            #skip it for now
          else
            if node.xpath("a") and node.xpath("a").length > 0
              @last_link = node.xpath("a").last.attr("name")
              node.xpath("a").each do |anchor|
                case anchor.attr("name")
                  when /^qn_/
                    @snippet_type = "question"
                    @link = node.attr("name")
                  when /^st_/
                    @snippet_type = "contribution"
                    @link = node.attr("name")
                end
              end
            end
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
          if @snippet_type == "question"
            if text =~ /^((?:T|Q)\d+)\.\s\[([^\]]*)\] /
              qno = $1
              question = $2
              unless @questions.empty?
                if @subject =~ /\- (?:T|Q)\d+/
                  @subject = "#{@subject.gsub(/\- (?:T|Q)\d+/, "- #{@question_no}")}"
                else
                  @subject = "#{@subject} - #{@question_no}"
                end
                store_debate(page)
                @snippet = []
                @questions = []
                @petitions = []
              end
              @question_no = qno
              @questions << question
              @segment_link = "#{page.url}\##{@last_link}"
              @subject = "#{@subject.gsub(/\- (?:T|Q)\d+/, "- #{@question_no}")}"
            elsif text[text.length-1..text.length] == "]" and text.length > 3
              question = text[text.rindex("[")+1..text.length-2]
              @questions << sanitize_text(question)
            end
          end
          if @subsection == "Petition"
            if text =~ /\[(P[^\]]*)\]/
              @petitions << $1
            end
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
              when /^(([^\(]*) \(([^\(]*)\) \(([^\(]*)\))/
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
            @snippet << sanitize_text(text)
          end
        when "div"
         #if node.attr("class").value.to_s == "navLinks"
         #ignore
        when "hr"
          #ignore
      end
    end
    
    def store_debate(page)
      handle_contribution(@member, @member, page)
      
      unless @questions.empty?
        @subsection = "Oral Answer"
      end
      
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
      
        if @questions == [] and @subsection == "Oral Answer"
          @subsection = "Debate"
          @department = ""
        end
        
        if @petitions == [] and @subsection == "Petition"
          @subsection = "Debate"
        end
      
        subject = ""
        if @subsection == ""
          subject = @subject
        else
          subject = "#{@subsection}: #{@subject}"
        end
      
        doc = {:title => sanitize_text(subject),
         :volume => page.volume,
         :columns => column_text,
         :part => sanitize_text(page.part.to_s),
         :members => names,
         :subject => subject,
         :url => @segment_link,
         :house => house,
         :section => section,
         :date => Time.parse("#{@date}T00:00:01Z")
        }
        
        if @department != ""
          doc[:department] = @department
        end
        
        unless @questions.empty?
          doc[:questions] = "| " + @questions.join(" | ") + " |"
        end
        
        unless @petitions.empty?
          doc[:petitions] = "| " + @petitions.join(" | ") + " |"
        end
         
        categories = {"house" => house, "section" => section}
      
        @indexer.add_document(segment_id, doc, @snippet.join(" "))

        @start_column = @end_column if @end_column != ""
        
        p subject
        p segment_id
        p @segment_link
        # p "Dept: " + @department
        # p "Questions: " + @questions.join(", ")
        # p "Petitions: " + @petitions.join(", ")
        p ""
      
        store_member_contributions
        
        if @subsection == "Motion"
          @subsection = ""
        end
      end
    end

end
