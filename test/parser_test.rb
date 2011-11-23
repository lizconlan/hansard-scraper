require 'test/unit'
require 'mocha'
require 'shoulda'

require 'lib/parsers/commons/wms_parser'

class ParserTest < Test::Unit::TestCase
  def setup
    hansard = Hansard.new
    Hansard.expects(:find_or_create_by_id).with("2099-01-01_hansard_c").returns(hansard)
    
    @parser = WMSParser.new("2099-01-01")
    @parser.init_vars()
  end
  
  context "in general" do
    setup do
      setup()      
      @section_list = {
        "Petitions"=> "http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110110/petnindx/110110-x.htm",
        "Written Answers"=> "http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110110/index/110110-x.htm",
        "Debates and Oral Answers"=> "http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110110/debindx/110110-x.htm",
        "Written Statements"=> "http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110110/wmsindx/110110-x.htm",
        "Ministerial Corrections"=> "http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110110/corrindx/110110-x.htm"
       }
    end
    
    should "retrieve an unordered Hash of section names and urls" do
      index_html = %Q|<ul id="publication-items" class="publications">
          <li><a href="http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110110/debindx/110110-x.htm">Debates and Oral Answers</a><p>Follow Commons debates on bills, oral statements made by Ministers and find out what issues were rai</p></li>
          <li><a href="http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110110/wmsindx/110110-x.htm">Written Statements</a><p>Read written statements made by Ministers on policy or government actions </p></li>
          <li><a href="http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110110/index/110110-x.htm">Written Answers</a><p>Find out Ministers' responses to written parliamentary questions asked by MPs</p></li>
          <li><a href="http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110110/petnindx/110110-x.htm">Petitions</a><p>Discover more about public petitions presented by MPs on behalf of their constituents </p></li>
          <li><a href="http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110110/corrindx/110110-x.htm">Ministerial Corrections</a><p>Ministers can publish corrections to information previously given to the House of Commons</p></li>
          <li id="ctl00_ctl00_SiteSpecificPlaceholder_PageContent_ctlCalendarListing_ctrlItemListing_rptItems_ctl01_ctl00_ulIndexLinks">
            <ul>
                <li id="ctl00_ctl00_SiteSpecificPlaceholder_PageContent_ctlCalendarListing_ctrlItemListing_rptItems_ctl01_ctl00_liContent"><a id="ctl00_ctl00_SiteSpecificPlaceholder_PageContent_ctlCalendarListing_ctrlItemListing_rptItems_ctl01_ctl00_hypContentLink" href="http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110110/indexes/cx110110.html">Contents</a></li>
                <li id="ctl00_ctl00_SiteSpecificPlaceholder_PageContent_ctlCalendarListing_ctrlItemListing_rptItems_ctl01_ctl00_liIndex" class="last"><a id="ctl00_ctl00_SiteSpecificPlaceholder_PageContent_ctlCalendarListing_ctrlItemListing_rptItems_ctl01_ctl00_hypIndex" href="http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110110/indexes/dx110110.html">Index</a></li>
            </ul>
            <ul id="ctl00_ctl00_SiteSpecificPlaceholder_PageContent_ctlCalendarListing_ctrlItemListing_rptItems_ctl01_ctl00_ulDocumentLink" class="square-bullets">
              <li><a href="http://www.publications.parliament.uk/pa/cm201011/cmhansrd/chan95.pdf" class="document">Official Report - 10.01.2011&nbsp;(<span><img src="/assets/images/pdf-icon.gif" alt="PDF" /></span> PDF)</a></li>
            </ul>    
          </li>
        </ul>|
      
      index_url = "http://www.parliament.uk/business/publications/hansard/commons/by-date/?d=1&m=1&y=2099"
      response = mock()
      response.expects(:body).returns(index_html)
      RestClient.expects(:get).with(index_url).returns(response)
            
      assert_equal(@section_list, @parser.get_section_links)
    end

    should "load a section page for a given section name" do
      response = mock()
      response.expects("body").returns("html goes here")
      @parser.expects(:get_section_links).returns(@section_list)
      RestClient.expects(:get).with("http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110110/wmsindx/110110-x.htm").returns(response)
      
      assert_equal("html goes here", @parser.get_section_index)
    end
  end
  
  context "when dealing with pages that use the maincontent1 format (up to Feb 17 2011)" do
    setup do
      setup()
      @section_html = %Q|<body><div id="maincontent1">
        <p>Clicking an entry will fetch the appropriate file and position it with the item at the top of the screen</p>
        <p>Following the Table of Contents is <a href="#speakers">a more detailed list which gives subject headings, timelines and names of speakers</a></p>
        <table width="100%"><tbody><tr><td align="left"><font size="+1"><b>Volume No. 521</b></font></td><td align="right"><font size="+1"><b>Part No. 95</b></font></td></tr></tbody></table>
        <div align="center">
          <h3 align="center">Written Ministerial Statements for 10 January 2011</h3>
          <a href="/pa/cm201011/cmhansrd/cm110110/wmstext/110110m0001.htm#1101104000009"></a><br>
          <h3 align="center"><a href="/pa/cm201011/cmhansrd/cm110110/wmstext/110110m0001.htm#1101104000002">Treasury </a></h3>
          <a href="/pa/cm201011/cmhansrd/cm110110/wmstext/110110m0001.htm#1101104000010">Financial Assistance forIreland </a><br>
        </div></div></body>|
    end
    
    should "work out the link to the first content page for a given section when the maincontent1 format is used" do
      section = "Written Statements"
      @parser.expects(:get_section_index).returns(@section_html)
      
      assert_equal("http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110110/wmstext/110110m0001.htm", @parser.link_to_first_page)
    end
    
    should "be able to find the content when asked to parse the page" do
      url = "http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110719/debtext/110719-0001.htm"
      @hansard_page = HansardPage.new(url)
      page_html = %Q|<html><head>
        <meta name="Subject" content="House of Commons Hansard, Volume: 523, Part: 121">
        <meta name="Columns" content="Columns: 91WS to 96WS"></head>
        <body><div id="maincontent1"><div>content goes here</div></div></body></html>|
      
      @hansard_page.expects(:doc).times(2).returns(Nokogiri::HTML(page_html))      
      @parser.expects(:parse_node)

      @parser.parse_page(@hansard_page)
    end
  end
  
  context "when dealing with pages that use the content-small id (Feb 28 2011 onwards)" do
    setup do
      setup()
      @section_html = %Q|<body><div id="content-small">
        <p>Clicking an entry will fetch the appropriate file and position it with the item at the top of the screen</p>
        <p>Following the Table of Contents is <a href="#speakers">a more detailed list which gives subject headings, timelines and names of speakers</a></p>
        <table width="100%"><tbody><tr><td align="left" colspan="1" rowspan="1"><font size="+1"><b>Volume No. 536</b></font></td><td align="right" colspan="1" rowspan="1"><font size="+1"><b>Part No. 226</b></font></td></tr></tbody></table>
        <h3 style="text-align:center;">House of Commons Written Ministerial Statements 21 November 2011</h3>
        <p style="text-align:center;text-transform:capitalize;margin:0 !important;padding:2px;">
          <a href="/pa/cm201011/cmhansrd/cm111121/wmstext/111121m0001.htm#1111212000001">written ministerial statements </a>
        </p>
        <h3 style="text-align:center;text-transform:capitalize;margin:0;padding:10px 0 0 0;">
          <a href="/pa/cm201011/cmhansrd/cm111121/wmstext/111121m0001.htm#1111212000002">business, innovation and skills </a>
        </h3></div></body>|
    end
    
    should "work out the link to the first content page for a given section" do
      section = "Written Statements"
      
      @parser.expects(:get_section_index).returns(@section_html)
      
      assert_equal("http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm111121/wmstext/111121m0001.htm", @parser.link_to_first_page)
    end
    
    should "be able to find the content when asked to parse the page" do
      url = "http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110719/debtext/110719-0001.htm"
      @hansard_page = HansardPage.new(url)
      page_html = %Q|<html><head>
        <meta name="Subject" content="House of Commons Hansard, Volume: 523, Part: 121">
        <meta name="Columns" content="Columns: 91WS to 96WS"></head>
        <body><div id="content-small"><table><tr><td><div>content goes here</div></td></tr></table></div></body></html>|
      
      @hansard_page.expects(:doc).times(2).returns(Nokogiri::HTML(page_html))      
      @parser.expects(:parse_node)

      @parser.parse_page(@hansard_page)
    end
  end
end