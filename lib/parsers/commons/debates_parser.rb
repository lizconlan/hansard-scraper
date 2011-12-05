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
    @div_snippet = nil
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
            @k_html << "<h1>#{text}</h1>"
          end
          
          if text == "Oral Answers to Questions"
            @subsection = "Oral Answer"
            @intro[:title] = node.content
            @intro[:link] = "#{page.url}\##{@last_link}"
            @k_html << "<h3>#{text}</h3>"
          end
        when "h3"
          text = node.text.gsub("\n", "").squeeze(" ").strip
          if (@snippet_type == "department heading" and @subsection == "Oral Answer")
            @department = sanitize_text(text)
            if text.downcase != "prayers" and ((@snippet.empty? == false and @snippet.collect{|x| x.text}.join("").length > 0) or @intro[:title])
              store_debate(page)
              @snippet = []
              @segment_link = ""
              @questions = []
              @petitions = []
              @section_members = {}
              
              @k_html << "<h3>#{text}</h3>"
            else
              @subject = sanitize_text(text)
              if @intro[:title]
                @intro[:snippets] << text
                @intro[:columns] << @end_column
                @intro[:links] << "#{page.url}\##{@last_link}"
              else
                snippet = HansardSnippet.new
                snippet.text = sanitize_text(text)
                snippet.column = @end_column
                @snippet << snippet
                @segment_link = "#{page.url}\##{@last_link}"
              end
            end
          elsif @snippet_type == "subject heading" and @subsection == "Oral Answer"
            if ((@snippet.empty? == false and @snippet.collect{|x| x.text}.join("").length > 0) and @subject != "") or @intro[:title]
              store_debate(page)
              @snippet = []
              @segment_link = ""
              @questions = []
              @petitions = []
              @section_members = {}
            end
            
            @subject = text
            @k_html << "<h4>#{text}</h4>"
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
                     "point of order",
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
                @subject = sanitize_text(text)
                @segment_link = "#{page.url}\##{@last_link}"
              end
            end
            @k_html << "<h3>#{text}</h3>"
          end
        when "h4"
          text = sanitize_text(node.text.gsub("\n", "").squeeze(" ").strip)
          if @intro[:title]
            @intro[:snippets] << text
            @intro[:columns] << @end_column
            @intro[:links] << "#{page.url}\##{@last_link}"
            if text =~ /^[A-Z][a-z]*day \d{1,2} [A-Z][a-z]* \d{4}$/
              @k_html << "<h2>#{text}</h2>"
            else
              @k_html << "<p>#{text}</p>"
            end
          else
            if text.downcase =~ /^back\s?bench business$/
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
              if text =~ /^[A-Z][a-z]*day \d{1,2} [A-Z][a-z]* \d{4}$/
                @k_html << "<h2>#{text}</h2>"
              else
                @k_html << "<h3>#{text}</h3>"
              end
            else              
              snippet = HansardSnippet.new
              snippet.text = sanitize_text(text)
              snippet.column = @end_column
              @snippet << snippet
              unless @subsection == "Oral Answer"
                @subject = sanitize_text(text)
              end
              @segment_link = "#{page.url}\##{@last_link}"
              if text =~ /^[A-Z][a-z]*day \d{1,2} [A-Z][a-z]* \d{4}$/
                @k_html << "<h2>#{text}</h2>"
              elsif @subsection == "Oral Answer" and !(text =~ / was asked /)
                @k_html << "<h4>#{text}</h4>"
              else
                @k_html << "<p>#{text}</p>"
              end
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
          @k_html << "<div>#{text}</div>"
        when "p", "center"
          column_desc = ""
          member_name = ""
          
          if @subsection == "Debate"
            if node.xpath("i") and node.xpath("i").length > 0
              case node.xpath("i").first.text.strip
                when /^Motion/
                  unless (node.xpath("i").collect { |x| x.text }).join(" ") =~ /and Question p/
                    @subsection = "Motion"
                    @member = nil
                  end
                when /^Debate resumed/
                  @subject = "#{@subject} (resumed)"
                  @member = nil
                when /^Ordered/, /^Question put/
                  @subsection = ""
                  @member = nil
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
                    if @snippet_type == "division" and @div_snippet
                      @snippet << @div_snippet
                      @k_html << "<p>#{@div_snippet.overview}</p><p>&nbsp;</p><div>Division No. #{@div_snippet.number} - #{@div_snippet.timestamp}</div><p>&nbsp;</p><div><b>AYES</b><div>#{@div_snippet.ayes.join("</div><div>")}</div><div>Tellers for the Ayes: #{@div_snippet.tellers_ayes}</div><p>&nbsp;</p><div><b>NOES</b><div>#{@div_snippet.noes.join("</div><div>")}</div><div>Tellers for the Noes: #{@div_snippet.tellers_noes}</div><p>#{@div_snippet.summary}</p>"
                      @div_snippet = nil
                    end
                    @snippet_type = "contribution"
                    @link = node.attr("name")
                  when /^stpa_/
                    if @snippet_type == "division" and @div_snippet
                      @snippet << @div_snippet
                      @k_html << "<p>#{@div_snippet.overview}</p><p>&nbsp;</p><div>Division No. #{@div_snippet.number} - #{@div_snippet.timestamp}</div><p>&nbsp;</p><div><b>AYES</b><div>#{@div_snippet.ayes.join("</div><div>")}</div><div>Tellers for the Ayes: #{@div_snippet.tellers_ayes}</div><p>&nbsp;</p><div><b>NOES</b><div>#{@div_snippet.noes.join("</div><div>")}</div><div>Tellers for the Noes: #{@div_snippet.tellers_noes}</div><p>#{@div_snippet.summary}</p>"
                      @div_snippet = nil
                    end
                    @snippet_type = "contribution"
                    @link = node.attr("name")
                  when /^divlst_/
                    @snippet_type = "division"
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
          
          text = node.content.gsub("\n", " ").gsub("\r", "").gsub(column_desc, "").squeeze(" ").strip
          
          if @snippet_type == "question"
            if text =~ /^((?:T|Q)\d+)\.\s\[([^\]]*)\] /
              qno = $1
              question = $2
              if @questions.empty?
                if @subject =~ /\- (?:T|Q)\d+/
                  @subject = "#{@subject.gsub(/\- (?:T|Q)\d+/, "- #{qno}")}"
                else
                  @subject = "#{@subject} - #{qno}"
                end
              else
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
          elsif @snippet_type == "division"
            case text.strip
              when /^(Question|Motion)/
                @div_snippet.summary = text
                if @div_snippet
                  @snippet << @div_snippet
                  @k_html << "<p>#{@div_snippet.overview}</p><p>&nbsp;</p><div>Division No. #{@div_snippet.number} - #{@div_snippet.timestamp}</div><p>&nbsp;</p><div><b>AYES</b></div><div>#{@div_snippet.ayes.join("</div><div>")}</div><div>Tellers for the Ayes: #{@div_snippet.tellers_ayes}</div><p>&nbsp;</p><div><b>NOES</b></div><div>#{@div_snippet.noes.join("</div><div>")}</div><div>Tellers for the Noes: #{@div_snippet.tellers_noes}</div><p>&nbsp;</p><p>#{@div_snippet.summary}</p>"
                  @div_snippet = nil
                end
              when /^The House divided/
                @div_snippet = HansardSnippet.new
                @div_snippet.desc = "division"
                @div_snippet.text = "division"
                @div_snippet.overview = text
                @div_snippet.ayes = []
                @div_snippet.noes = []
                @div_snippet.tellers_ayes = ""
                @div_snippet.tellers_noes = ""
              when /^Ayes \d+, Noes \d+./
                @div_snippet.overview = "#{@div_snippet.overview} #{text}".strip
              when /^Division No\. ([^\]]*)\]/
                @div_snippet.number = $1
              when /\[(\d+\.\d+ (a|p)m)/
                @div_snippet.timestamp = $1
              when "AYES"
                @current_list = "ayes"
                @tellers = false
              when "NOES"
                @current_list = "noes"
                @tellers = false
              when ""  
                #ignore
              when /^Tellers for the (Ayes|Noes):/
                @tellers = true
              when /^[A-Z][a-z]*, (rh)?\s?(Mr|Ms|Mrs|Sir)?\s?[A-Z][a-z]*/
                if @current_list == "ayes"
                  @div_snippet.ayes << text.strip
                else
                  @div_snippet.noes << text.strip
                end
              else
                if @tellers
                  if @current_list == "ayes"
                    @div_snippet.tellers_ayes = "#{@div_snippet.tellers_ayes} #{text.strip}".strip
                  else
                    @div_snippet.tellers_noes = "#{@div_snippet.tellers_noes} #{text.strip}".strip
                  end
                else
                  if @current_list == "ayes"
                    aye = @div_snippet.ayes.pop
                    aye = "#{aye} #{text.strip}"
                    @div_snippet.ayes << aye
                  else
                    noe = @div_snippet.noes.pop
                    noe = "#{noe} #{text.strip}"
                    @div_snippet.noes << noe
                  end
                end
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
              
              @k_html << "<p>#{text}</p>"
            elsif @snippet_type != "division"
              snippet = HansardSnippet.new
              if @member
                snippet.speaker = @member.index_name                  
              end
              snippet.text = sanitize_text(text)
              snippet.column = @end_column
              
              if @member
                if snippet.text =~ /^((T|Q)?\d+\.\s+(\[\d+\]\s+)?)?#{@member.post} \(#{@member.name}\)/
                  snippet.printed_name = "#{@member.post} (#{@member.name})"
                  snippet.text = sanitize_text(text)
                elsif snippet.text =~ /^((T|Q)?\d+\.\s+(\[\d+\]\s+)?)?#{@member.search_name}/
                  snippet.printed_name = @member.search_name
                  snippet.text = sanitize_text(text)
                else
                  snippet.printed_name = @member.printed_name
                  snippet.text = sanitize_text(text)
                end
              end
              
              @snippet << snippet
              @segment_link = "#{page.url}\##{@last_link}"
              
              unless snippet.text == ""
                if snippet.printed_name and snippet.text.strip =~ /^((T|Q)?\d+\.\s+(\[\d+\]\s+)?)?#{snippet.printed_name.gsub('(','\(').gsub(')','\)')}/
                  prefix = $1
                  if prefix
                    pref_length = prefix.length
                  else
                    pref_length = 0
                  end
                  k_html = "<p>#{prefix}<b>#{@coder.encode(snippet.printed_name, :named)}</b>#{@coder.encode(snippet.text.strip[snippet.printed_name.length+pref_length..snippet.text.strip.length], :named)}</p>"
                  @k_html << html_fix(k_html.gsub("\t"," ").squeeze(" "))
                else
                  @k_html << "<p>#{html_fix(@coder.encode(snippet.text.strip, :named))}</p>"
                end
              end
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
        @para_seq = 0
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
              @debate.department = @department
            else
              @debate = Debate.find_or_create_by_id(segment_id)
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

            @snippet.each do |snippet|
              unless snippet.text == @debate.title or snippet.text == ""
                @para_seq += 1
                para_id = "#{@debate.id}_p#{@para_seq.to_s.rjust(6, "0")}"

                case snippet.desc
                  when "timestamp"
                    para = Timestamp.find_or_create_by_id(para_id)
                  when "division"
                    para = Division.find_or_create_by_id(para_id)
                    para.number = snippet.number
                    para.ayes = snippet.ayes
                    para.noes = snippet.noes
                    para.tellers_ayes = snippet.tellers_ayes
                    para.tellers_noes = snippet.tellers_noes
                    para.timestamp = snippet.timestamp
                    
                    para.text = "#{snippet.overview} \n #{snippet.timestamp} - Division No. #{snippet.number} \n Ayes: #{snippet.ayes.join("; ")}, Tellers for the Ayes: #{snippet.tellers_ayes}, Noes: #{snippet.noes.join("; ")}, Tellers for the Noes: #{snippet.tellers_noes} \n #{snippet.summary}"
                  else
                    if snippet.speaker.nil?
                      para = NonContributionPara.find_or_create_by_id(para_id)
                    else
                      para = ContributionPara.find_or_create_by_id(para_id)
                      para.member = snippet.speaker
                      para.contribution_id = "#{@debate.id}__#{snippet.contribution_seq.to_s.rjust(6, "0")}"
                      if snippet.text.strip =~ /^(T?\d+\.\s+(\[\d+\]\s+)?)?#{snippet.printed_name.gsub('(','\(').gsub(')','\)')}/
                        para.speaker_printed_name = snippet.printed_name
                      end
                    end
                end

                col_paras = @debate.paragraphs.dup
                col_paras.delete_if{|x| x.respond_to?("member") == false }
                @debate.members = col_paras.collect{|x| x.member}.uniq

                para.text = snippet.text
                para.url = snippet.link
                para.column = snippet.column
                para.sequence = @para_seq
                para.fragment = @debate
                para.save

                @debate.paragraphs << para
              end
            end
          end

          @debate.columns = @debate.paragraphs.collect{|x| x.column}.uniq
          @debate.k_html = @k_html.join("<p>&nbsp;</p>")
          @debate.save
          @start_column = @end_column if @end_column != ""

          p @subject
          p segment_id
          p @segment_link
          p ""
        end
      end
      @k_html = []
    end

end
