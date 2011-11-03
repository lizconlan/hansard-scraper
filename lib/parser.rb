require 'rubygems'
require 'nokogiri'
require 'rest-client'
require 'date'
require 'time'

require 'lib/indexer'

require 'models/hansard_page'
require 'models/hansard_member'

require 'models/hansard_fragment'

require 'models/hansard/hansard'
require 'models/hansard/section'
require 'models/hansard/fragment'
require 'models/hansard/element'

class Parser
  attr_reader :date, :doc_id, :house
  
  COLUMN_HEADER = /^\d+ [A-Z][a-z]+ \d{4} : Column (\d+(?:WH)?(?:WS)?(?:P)?(?:W)?)(?:-continued)?$/
  
  def initialize(date, house="Commons")
    @date = date
    @house = house
    @doc_id = "#{date}_hansard_#{house[0..0].downcase()}"
    
    @hansard = Hansard.find_or_create_by_id(@doc_id)
    @hansard.house = house
    @hansard.date = date
    @hansard_section = nil
    @stored_contribution = nil
  end
  
  def get_section_index(section)
    url = get_section_links[section]
    if url
      response = RestClient.get(url)
      return response.body
    end
  end
  
  def get_section_links
    parse_date = Date.parse(date)
    index_page = "http://www.parliament.uk/business/publications/hansard/#{house.downcase()}/by-date/?d=#{parse_date.day}&m=#{parse_date.month}&y=#{parse_date.year}"
    begin
      result = RestClient.get(index_page)
    rescue
      return nil
    end
  
    doc = Nokogiri::HTML(result.body)
    urls = Hash.new
  
    doc.xpath("//ul[@id='publication-items']/li/a").each do |link|
      urls["#{link.text.strip}"] = link.attribute("href").value.to_s
    end
  
    urls
  end
  
  def link_to_first_page
    html = get_section_index
    return nil unless html
    doc = Nokogiri::HTML(html)
    
    content_section = doc.xpath("//div[@id='content-small']/p[3]/a")
    if content_section.empty?
      content_section = doc.xpath("//div[@id='content-small']/table/tr/td[1]/p[3]/a[1]")
    end
    if content_section.empty?
      content_section = doc.xpath("//div[@id='maincontent1']/div/a[1]")
    end
    relative_path = content_section.attr("href").value.to_s
    "http://www.publications.parliament.uk#{relative_path[0..relative_path.rindex("#")-1]}"
  end
  
  def parse_page(page)    
    @page += 1
    content = page.doc.xpath("//div[@id='content-small']")
    if content.empty?
      content = page.doc.xpath("//div[@id='maincontent1']")
    elsif content.children.size < 10
      content = page.doc.xpath("//div[@id='content-small']/table/tr/td[1]")
    end
    content.children.each do |child|
      if child.class == Nokogiri::XML::Element
        parse_node(child, page)
      end
    end
  end
  
  def parse_pages
    init_vars()
    
    @indexer = Indexer.new()
    
    unless link_to_first_page
      warn "No #{section} data available for this date"
    else
      if @section_prefix == ""
        section_id = @doc_id
      else
        section_id = "#{@doc_id}_#{section_prefix}"
      end
      
      @hansard_section = Section.find_or_create_by_id(section_id)
      @hansard_section.hansard = @hansard
      @hansard.save
      
      @hansard.sections << @hansard_section
      @hansard_section.name = @section
      @hansard_section.save
      
      page = HansardPage.new(link_to_first_page)
      parse_page(page)
      while page.next_url
        page = HansardPage.new(page.next_url)
        parse_page(page)
      end
    
      #flush the buffer
      unless @snippet.empty? or @snippet.join("").length == 0
        store_debate(page)
        reset_vars()
      end
    end
  end
  
  private
    def process_links_and_columns(node)
      @last_link = node.attr("name") if node.attr("class") == "anchor"
      if node.attr("class") == "anchor-column"
        if @start_column == ""
          @start_column = node.attr("name").gsub("column_", "")
        else
          @end_column = node.attr("name").gsub("column_", "")
        end
      elsif node.attr("name") =~ /column_(.*)/  #older page format
        if @start_column == ""
          @start_column = node.attr("name").gsub("column_", "")
        else
          @end_column = node.attr("name").gsub("column_", "")
        end
      elsif node.attr("name") =~ /^\d*$/ #older page format
        @last_link = node.attr("name")
      end
    end
    
    def determine_snippet_type(node)
      case node.attr("name")
        when /^hd_/
          #heading e.g. the date, The House met at..., The Deputy PM was asked
          @snippet_type = "heading"
          @link = node.attr("name")
        when /^place_/
          @snippet_type = "location heading"
          @link = node.attr("name")
        when /^dpthd_/
          @snippet_type = "department heading"
          @link = node.attr("name")
        when /^subhd_/
          @snippet_type = "subject heading"
          @link = node.attr("name")
        when /^qn_/
          @snippet_type = "question"
          @link = node.attr("name")
        when /^st_/
          @snippet_type = "contribution"
          @link = node.attr("name")
      end 
    end
    
    def handle_contribution(member, new_member, page)
      if @contribution and member
        unless @members.keys.include?(member.search_name)
          if @section_members.keys.include?(member.search_name)
            @members[member.search_name] = @section_members[member.search_name]
          else
            @members[member.search_name] = member
            @section_members[member.search_name] = member
          end
        end
        @contribution.end_column = @end_column
        @members[member.search_name].contributions << @contribution
      end
      if @end_column == ""
        @contribution = HansardContribution.new("#{page.url}\##{@last_link}", @start_column)
      else
        @contribution = HansardContribution.new("#{page.url}\##{@last_link}", @end_column)
      end
      
      if new_member
        if @members.keys.include?(new_member.search_name)
          new_member = @members[new_member.search_name]
        elsif @section_members.keys.include?(new_member.search_name)
          new_member = @section_members[new_member.search_name]
        else
          @members[new_member.search_name] = new_member
          @section_members[new_member.search_name] = new_member
        end
        @member = new_member
      end
    end
    
    def store_member_contributions
    end
    
    def sanitize_text(text)
      text = text.gsub("\342\200\230", "'")
      text = text.gsub("\342\200\231", "'")
      text = text.gsub("\342\200\234", '"')
      text = text.gsub("\342\200\235", '"')
      text = text.gsub("\342\200\224", " - ")
      text = text.gsub("\302\243", "£")
      text
    end
end
