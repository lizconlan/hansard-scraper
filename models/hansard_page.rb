require 'nokogiri'
require 'rest-client'

class HansardPage
  attr_reader :html, :doc, :url, :next_url, :start_column, :end_column, :volume, :part, :title
  
  def initialize(url)
    @url = url
    response = RestClient.get(url)
    @html = response.body
    @doc = Nokogiri::HTML(@html)
    next_link = []
    if @doc.xpath("//div[@class='navLinks']").empty?
      next_link = @doc.xpath("//table").last.xpath("tr/td/a[text()='Next Section']")
    elsif @doc.xpath("//div[@class='navLinks'][2]").empty?
      next_link = @doc.xpath("//div[@class='navLinks'][1]/div[@class='navLeft']/a")
    else
      next_link = @doc.xpath("//div[@class='navLinks'][2]/div[@class='navLeft']/a")
    end
    unless next_link.empty?
      prefix = url[0..url.rindex("/")]
      @next_url = prefix + next_link.attr("href").value.to_s
    else
      @next_url = nil
    end
    scrape_metadata()
  end
  
  private
    def scrape_metadata
      subject = doc.xpath("//meta[@name='Subject']").attr("content").value.to_s
      column_range = doc.xpath("//meta[@name='Columns']").attr("content").value.to_s
      cols = column_range.gsub("Columns: ", "").split(" to ")

      @start_column = cols[0]
      @end_column = cols[1]
      @volume = subject[subject.index("Volume:")+8..subject.rindex(",")-1]
      @part = subject[subject.index("Part:")+5..subject.length].gsub("\302\240", "")
      @title = doc.xpath("//head/title").text.strip
    end
end