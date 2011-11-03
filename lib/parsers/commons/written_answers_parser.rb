require 'lib/parser'

class WrittenAnswersParser < Parser
  attr_reader :section
  
  def initialize(date, house="Commons", section="Written Answers")
    super(date, house)
    @section = section
    @section_prefix = "w"
  end
  
  def get_section_index
    super(section)
  end
  
  def init_vars
    @page = 0
    @count = 0
    @contribution_count = 0

    @members = {}
    @questions = []
    @section_members = {}
    @member = nil
    @contribution = nil
    
    @last_link = ""
    @snippet = []
    @subject = ""
    @department = ""
    @start_column = ""
    @end_column = ""
    
    @chair = ""
  end
  
  def reset_vars
    @snippet = []
    @questions = []
    @members = {}
  end
  
  
  private
    def parse_node(node, page)
      case node.name
        when "a"
          process_links_and_columns(node)
          determine_snippet_type(node)
        when "h3"
          unless @snippet.empty? or @snippet.join("").length == 0
            store_debate(page)
            @snippet = []
            @segment_link = ""
            @questions = []
            @members = {}
          end
          text = node.text.gsub("\n", "").squeeze(" ").strip
          if @snippet_type == "department heading"
            @department = sanitize_text(text)
          else
            @subject = sanitize_text(text)
          end
          @segment_link = "#{page.url}\##{@last_link}"
        when "h4"
          unless @snippet.empty? or @snippet.join("").length == 0
            store_debate(page)
            @snippet = []
            @questions = []
            @segment_link = ""
            @members = {}
          end
          text = node.text.gsub("\n", "").squeeze(" ").strip
          @subject = sanitize_text(text)
          @segment_link = "#{page.url}\##{@last_link}"
        when "p", "table"
          column_desc = ""
          if node.xpath("a") and node.xpath("a").length > 0
            @last_link = node.xpath("a").last.attr("name")
          end
          
          text = node.text.gsub("\n", "").gsub(column_desc, "").squeeze(" ").strip
          
          if text[text.length-1..text.length] == "]" and text.length > 3
            question = text[text.rindex("[")+1..text.length-2]
            @questions << sanitize_text(question)
          end
          
          #ignore column heading text
          unless text =~ /^\d+ [A-Z][a-z]+ \d{4} : Column (\d+(?:WH)?(?:WS)?(?:P)?(?:W)?)(?:-continued)?$/
            @snippet << sanitize_text(text)
          end
      end
    end
    
    def store_debate(page)
      handle_contribution(@member, @member, page)
      
      if @segment_link #no point storing empty pointers
        segment_id = "#{doc_id}_w_#{@count}"
        @count += 1

        column_text = ""
        if @start_column == @end_column or @end_column == ""
          column_text = @start_column
        else
          column_text = "#{@start_column} to #{@end_column}"
        end
      
        doc = {:title => "Written Answer: " + sanitize_text("#{@subject}"),
         :volume => page.volume,
         :columns => column_text,
         :part => sanitize_text(page.part.to_s),
         :department => @department,
         :subject => @subject,
         :url => @segment_link,
         :house => house,
         :section => section,
         :date => Time.parse("#{@date}T00:00:01Z")
        }
        
        unless @questions.empty?
          doc[:questions] = "| " + @questions.join(" | ") + " |"
        end
        
        categories = {"house" => house, "section" => section}
      
        @indexer.add_document(segment_id, doc, @snippet.join(" "))

        @start_column = @end_column if @end_column != ""
      
        p @subject
        p segment_id
        p @segment_link
        p ""
      end
    end
    
end