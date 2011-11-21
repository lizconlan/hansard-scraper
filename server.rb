require 'sinatra'
require 'mongo_mapper'
require 'cgi'
require 'sunspot'
require 'haml'

require 'models/hansard'
require 'models/section'
require 'models/fragment'
require 'models/paragraph'
require 'models/snippet'

before do
  Sunspot.config.solr.url = ENV['WEBSOLR_URL'] || YAML::load(File.read("config/websolr.yml"))[:websolr_url]
  
  MONGO_URL = ENV['MONGOHQ_URL'] || YAML::load(File.read("config/mongo.yml"))[:mongohq_url]
  env = {}
  MongoMapper.config = { env => {'uri' => MONGO_URL} }
  MongoMapper.connect(env)
end

helpers do
  include Rack::Utils
  alias_method :h, :escape_html
  
  def url_segments_line(house, section, date, url, separator=' &rsaquo; ')
    parse_date = date
    url_parts = url.split("/")
    house_text = "#{house} Hansard"
    house_link = "http://www.parliament.uk/business/publications/hansard/#{house.downcase}/"
    date_text = parse_date.strftime("%d %b %Y")
    
    date_link = "http://www.parliament.uk/business/publications/hansard/#{house.downcase()}/by-date/?d=#{parse_date.day}&m=#{parse_date.month}&y=#{parse_date.year}"
    section_end = ""
    if url_parts.last =~ /(\d*\.htm)/
      page = $1
      section_end = url_parts.last.split("#").first.gsub(page, "0001.htm")
    end
    section_link = "#{url_parts[0..url_parts.length-2].join("/")}/#{section_end}"

    [	"<a href='#{house_link}' title='#{house_text}: home page'>#{house_text}</a>", 
    	"<a href='#{date_link}' title='#{house_text}: #{date_text}'>#{date_text}</a>",
    	"<a href='#{section_link}' title='#{section}: #{date_text}'>#{section}</a>"
    	].join(separator)
  end
  
  def page_info
    prev_page = @page.to_i-1
    prev_page_long_range = prev_page*10+10
    
    info = [prev_page*10+1, 'to']
    
    if prev_page_long_range < @found
      info << prev_page_long_range
    else
      info << @found
    end
    
    info.join(' ')
  end
  
  def highlight(text, word)
  	text.gsub(/#{word}.?\b/i, '<strong>\0</strong>')
  end
end

get '/' do
  @q = params[:q]
	@section_filter = params[:section]
	@page = params[:p]
	if @page.to_i < 1
	  @page = 1 
	else
	  @page = @page.to_i
	end
	
	if @q	  
	  search_results = Sunspot.search(HansardFragment) do |query|
	    query.keywords @q do
	      highlight :text, {:fragment_size => 150}
	    end
	    query.facet :section, :volume, :house
    end
	  
    # if @section_filter
    #   url = "#{url}&fq=section_ss:%22#{CGI::escape(@section_filter)}%22"
    # end
    # 
    # if @page > 1
    #   url = "#{url}&start=#{(@page.to_i-1)*10}"
    # end
	  
	  @found = search_results.hits.count
	  @results = search_results
	  
    # unless CGI::escape(query).empty?
    #   buffer = open(url).read
    #         result = JSON.parse(buffer)
    #         @found = result['response']['numFound']
    #         @results = result['response']['docs']
    #         @highlights = result['highlighting']
    #         @section_facets = facets_to_hash_array(result['facet_counts']['facet_fields']['section_ss'])
    #       else
    #         redirect to('/')
    #       end
    #     end
  end
  
	haml :index
end

get '/:date/:house/:section/:fragment.:format' do
  key = params[:date] + "_hansard_" + params[:house].downcase()[0..0] + "_" + params[:section] + "_" + params[:fragment]
  frag = Fragment.find(key)
  frag.to_simple_html
end