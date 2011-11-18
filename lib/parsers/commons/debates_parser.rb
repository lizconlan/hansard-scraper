require 'lib/parser'

class DebatesParser < Parser
  attr_reader :section, :section_prefix
  
  def initialize(date, house="Commons", section="Debates and Oral Answers")
    super(date, house)
    @section = section
    @section_prefix = "d"
  end
  
  def get_section_index
    super(section)
  end
  
  def init_vars
    super()
    
    @questions = []
    @question_no = ""
    @petitions = []
    
    @column = ""
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
          
          if (@snippet.empty? == false and @snippet.collect{|x| x.text}.join("").length > 0) or @intro[:title]
            store_debate(page)
            @snippet = []
            @segment_link = ""
            @questions = []
            @petitions = []
            @section_members = {}
          end
          
          if text == "House of Commons"
            @intro[:title] = node.content
            @intro[:link] = "#{page.url}\##{@last_link}"
          end
          
          if text == "Oral Answers to Questions"
            @subsection = "Oral Answer"
            @intro[:title] = node.content
            @intro[:link] = "#{page.url}\##{@last_link}"
          end
        when "h3"
          text = node.text.gsub("\n", "").squeeze(" ").strip
          if (@snippet_type == "department heading" and @subsection == "Oral Answer") or  
            if (@snippet.empty? == false and @snippet.collect{|x| x.text}.join("").length > 0) or @intro[:title]
              store_debate(page)
              @snippet = []
              @segment_link = ""
              @questions = []
              @petitions = []
              @section_members = {}
            end
            @department = sanitize_text(text)
            if @intro[:title]
              @intro[:snippets] << text
              @intro[:columns] << @end_column
              @intro[:links] << "#{page.url}\##{@last_link}"
            else
              snippet = HansardSnippet.new
              snippet.text = sanitize_text(text)
              snippet.column = @end_column
              @snippet << snippet
              @subject = sanitize_text(text)
              @segment_link = "#{page.url}\##{@last_link}"
            end
          elsif @snippet_type == "subject heading" and @subsection == "Oral Answer"            
            if (@snippet.empty? == false and @snippet.collect{|x| x.text}.join("").length > 0) or @intro[:title]
              store_debate(page)
              @snippet = []
              @segment_link = ""
              @questions = []
              @petitions = []
              @section_members = {}
            end
            
            @subject = text
            p "my chosen specialist subject is: #{@subject}"
          else
            @subsection = ""
            if text.downcase == "prayers"
              @intro[:snippets] << text
              @intro[:columns] << @end_column
              @intro[:links] << "#{page.url}\##{@last_link}"
            else
              if (@snippet.empty? == false) or @intro[:title]
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
                snippet = HansardSnippet.new
                snippet.text = sanitize_text(text)
                snippet.column = @end_column
                @snippet << snippet
                @subject = sanitize_text(text)
                @segment_link = "#{page.url}\##{@last_link}"
              end
            end
          end
        when "h4"
          text = node.text.gsub("\n", "").squeeze(" ").strip
          if @intro[:title]
            @intro[:snippets] << text
            @intro[:columns] << @end_column
            @intro[:links] << "#{page.url}\##{@last_link}"
          else
            if @subject.downcase == "prayers"
              @intro[:snippets] << text
              @intro[:columns] << @end_column
              @intro[:links] << "#{page.url}\##{@last_link}"
            elsif text.downcase =~ /^back\s?bench business$/
              #treat as honourary h3
              if (@snippet.empty? == false and @snippet.collect{|x| x.text}.join("").length > 0) or @intro[:title]
                store_debate(page)
                @snippet = []
                @segment_link = ""
                @questions = []
                @petitions = []
                @section_members = {}
              end
              @intro[:title] = text
              @subsection = ""
            else              
              snippet = HansardSnippet.new
              snippet.text = sanitize_text(text)
              snippet.column = @end_column
              @snippet << snippet
              @subject = sanitize_text(text)
              @segment_link = "#{page.url}\##{@last_link}"
            end
          end
        when "h5"
          text = node.text.gsub("\n", "").squeeze(" ").strip
          
          snippet = HansardSnippet.new
          snippet.text = node.text
          snippet.desc = "timestamp"
          snippet.column = @end_column
          snippet.link = "#{page.url}\##{@last_link}"
          @snippet << snippet
        when "p", "center"
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
          
          text = node.content.gsub("\n", "").gsub(column_desc, "").squeeze(" ").strip
          
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
          unless (text =~ /^\d+ [A-Z][a-z]+ \d{4} : Column (\d+(?:WH)?(?:WS)?(?:P)?(?:W)?)(?:-continued)?$/) or text == ""
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
            
            if @intro[:title]
              @intro[:snippets] << text
              @intro[:columns] << @end_column
              @intro[:links] << "#{page.url}\##{@last_link}"
            else
              snippet = HansardSnippet.new
              if @member
                snippet.speaker = @member.index_name
                snippet.printed_name = @member.printed_name
              end
              snippet.text = sanitize_text(text)
              snippet.column = @end_column
              @snippet << snippet
              @segment_link = "#{page.url}\##{@last_link}"
            end
          end
        when "div"
         #if node.attr("class").value.to_s == "navLinks"
         #ignore
        when "hr"
          #ignore
      end
    end
    
    def store_debate(page)
      unless @questions.empty?
        @subsection = "Oral Answer"
      end
      
      if @intro[:title]
        @fragment_seq += 1
        intro_id = "#{@hansard_section.id}_#{@fragment_seq.to_s.rjust(6, "0")}"
        intro = Intro.find_or_create_by_id(intro_id)
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

        intro.save
        @hansard_section.fragments << intro
        @hansard_section.save

        @intro = {:snippets => [], :columns => [], :links => []}
      else
        unless @snippet.empty?
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

            if @subsection == "Oral Answer"
              @debate = Question.find_or_create_by_id(segment_id)
              @debate.number = @questions.last
            else
              @debate = Debate.find_or_create_by_id(segment_id)
              @debate.chair = @chair
            end
          
            @para_seq = 0
            @hansard_section.fragments << @debate
            @hansard_section.save

            @hansard.volume = page.volume
            @hansard.part = sanitize_text(page.part.to_s)
            @hansard.save

            @debate.section = @hansard_section
            @debate.title = @subject
            @debate.url = @segment_link

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

                col_paras = @debate.paragraphs.dup
                col_paras.delete_if{|x| x.respond_to?("member") == false }
                @debate.members = col_paras.collect{|x| x.member}.uniq

                para.text = snippet.text
                search_text << snippet.text
                para.url = snippet.link
                para.column = snippet.column
                para.sequence = @para_seq
                para.fragment = @debate
                para.save

                @debate.search_text = search_text.join(" ")

                @debate.paragraphs << para
              end
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
      
      
      
      
      
      # unless @questions.empty?
      #         @subsection = "Oral Answer"
      #       end
      #       
      #       if @segment_link #no point storing pointers that don't link back to the source
      #         segment_id = "#{doc_id}_wh_#{@count}"
      #         @count += 1
      #         names = []
      #         @members.each { |x, y| names << y.index_name unless names.include?(y.index_name) }
      #       
      #         column_text = ""
      #         if @start_column == @end_column or @end_column == ""
      #           column_text = @start_column
      #         else
      #           column_text = "#{@start_column} to #{@end_column}"
      #         end
      #       
      #         if @questions == [] and @subsection == "Oral Answer"
      #           @subsection = "Debate"
      #           @department = ""
      #         end
      #         
      #         if @petitions == [] and @subsection == "Petition"
      #           @subsection = "Debate"
      #         end
      #       
      #         subject = ""
      #         if @subsection == ""
      #           subject = @subject
      #         else
      #           subject = "#{@subsection}: #{@subject}"
      #         end
      #       
      #         doc = {:title => sanitize_text(subject),
      #          :volume => page.volume,
      #          :columns => column_text,
      #          :part => sanitize_text(page.part.to_s),
      #          :members => names,
      #          :subject => subject,
      #          :url => @segment_link,
      #          :house => house,
      #          :section => section,
      #          :date => Time.parse("#{@date}T00:00:01Z")
      #         }
      #         
      #         if @department != ""
      #           doc[:department] = @department
      #         end
      #         
      #         unless @questions.empty?
      #           doc[:questions] = "| " + @questions.join(" | ") + " |"
      #         end
      #         
      #         unless @petitions.empty?
      #           doc[:petitions] = "| " + @petitions.join(" | ") + " |"
      #         end
      #          
      #         categories = {"house" => house, "section" => section}
      #       
      #         @indexer.add_document(segment_id, doc, @snippet.join(" "))
      # 
      #         @start_column = @end_column if @end_column != ""
      #         
      #         p subject
      #         p segment_id
      #         p @segment_link
      #         # p "Dept: " + @department
      #         # p "Questions: " + @questions.join(", ")
      #         # p "Petitions: " + @petitions.join(", ")
      #         p ""
      #       
      #         store_member_contributions
      #         
      #         if @subsection == "Motion"
      #           @subsection = ""
      #         end
      #       end
    end

end
