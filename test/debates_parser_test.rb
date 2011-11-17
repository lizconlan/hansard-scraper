
require 'test/unit'
require 'mocha'
require 'shoulda'

require 'lib/parsers/commons/debates_parser'

class DebatesParserTest < Test::Unit::TestCase
  def stub_saves
    Intro.any_instance.stubs(:save)
    NonContributionPara.any_instance.stubs(:save)
    ContributionPara.any_instance.stubs(:save)
    Timestamp.any_instance.stubs(:save)
    Section.any_instance.stubs(:save)
    Hansard.any_instance.stubs(:save)
    # Debate.any_instance.stubs(:save)
    # Question.any_instance.stubs(:save)
  end
  
  def stub_hansard
    @hansard = Hansard.new()
    Hansard.expects(:find_or_create_by_id).with("2099-01-01_hansard_c").returns(@hansard)
  end
  
  def stub_page
    html = File.read("test/data/backbench_business_excerpt.html")
    @page = mock()
    @page.expects(:next_url).returns(nil)
    @page.expects(:doc).returns(Nokogiri::HTML(html))
    @page.expects(:url).at_least_once.returns(@url)
  end
    
  context "when handling Backbench Business section" do
    setup do
      @url = "http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110719/debtext/110719-0001.htm"
      stub_saves
      stub_hansard
      stub_page
      
      @parser = DebatesParser.new("2099-01-01")
      @parser.expects(:section_prefix).returns("d")
      @parser.expects(:link_to_first_page).returns(@url)
    end

    should "correctly recognise the Backbench Business section" do
      HansardPage.expects(:new).returns(@page)
      
      section = Section.new
      Section.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d').returns(section)
      
      intro = Intro.new
      Intro.expects(:find_or_create_by_id).returns(intro)
      intro.expects(:title=).with("Backbench Business")
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by_id).returns(ncpara)
      ncpara.expects(:fragment=).with(intro)
      ncpara.expects(:text=).with("[30th Allotted Day]")
      ncpara.expects(:sequence=).with(1)
      ncpara.expects(:url=).with("#{@url}\#11071988000020")
      ncpara.expects(:column=).with("831")
      
      intro.expects(:paragraphs).at_least_once.returns([ncpara])
      
      @parser.parse_pages
    end
  end
end
