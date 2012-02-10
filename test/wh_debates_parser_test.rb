require 'test/unit'
require 'mocha'
require 'shoulda'

require 'lib/parsers/commons/wh_debates_parser'

class WHDebatesParserTest < Test::Unit::TestCase
  def stub_saves
    Intro.any_instance.stubs(:save)
    NonContributionPara.any_instance.stubs(:save)
    ContributionPara.any_instance.stubs(:save)
    Timestamp.any_instance.stubs(:save)
    Section.any_instance.stubs(:save)
    DailyPart.any_instance.stubs(:save)
    Debate.any_instance.stubs(:save)
  end
  
  def stub_daily_part
    @daily_part = DailyPart.new()
    DailyPart.expects(:find_or_create_by_id).with("2099-01-01_hansard_c").returns(@daily_part)
  end
  
  def stub_page(file)
    html = File.read(file)
    @page = mock()
    @page.expects(:next_url).returns(nil)
    @page.expects(:doc).returns(Nokogiri::HTML(html))
    @page.expects(:url).at_least_once.returns(@url)
    @page.expects(:volume).at_least_once.returns("531")
    @page.expects(:part).at_least_once.returns("190")
  end
  
  context "in general" do
    setup do
      @url = "http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110719/halltext/110719h0001.htm"
      stub_saves
      stub_daily_part
      
      @parser = WHDebatesParser.new("2099-01-01")
      @parser.expects(:section_prefix).returns("wh")
      @parser.expects(:link_to_first_page).returns(@url)
    end

    should "create the Intro section, including the k_html field" do
      stub_page("test/data/wh_debates.html")
      HansardPage.expects(:new).returns(@page)
      
      section = Section.new
      Section.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_wh').returns(section)
      section.expects(:id).at_least_once.returns('2099-01-01_hansard_c_wh')
      
      intro = Intro.new
      Intro.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_wh_000001").returns(intro)
      intro.expects(:title=).with("Westminster Hall")
      intro.expects(:id).at_least_once.returns("2099-01-01_hansard_c_wh_000001")
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_wh_000001_p000001").returns(ncpara)
      ncpara.expects(:fragment=).with(intro)
      ncpara.expects(:text=).with("Tuesday 19 July 2011")
      ncpara.expects(:sequence=).with(1)
      ncpara.expects(:url=).with("#{@url}\#11071984000004")
      ncpara.expects(:column=).with("183WH")
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_wh_000001_p000002").returns(ncpara)
      ncpara.expects(:fragment=).with(intro)
      ncpara.expects(:text=).with("[Jim Dobbin in the Chair]")
      ncpara.expects(:sequence=).with(2)
      ncpara.expects(:url=).with("#{@url}\#11071984000005")
      ncpara.expects(:column=).with("183WH")
      
      intro.expects(:paragraphs).at_least_once.returns([ncpara])
      intro.expects(:k_html=).with("<h1>Westminster Hall</h1><p>&nbsp;</p><h2>Tuesday 19 July 2011</h2><p>&nbsp;</p><p>[Jim Dobbin in the Chair]</p>")
      
      #ignore the rest of the file, not relevant
      timestamp = Timestamp.new
      contribution = ContributionPara.new
      debate = Debate.new
      debate.expects(:id).at_least_once.returns("debate")
      
      Timestamp.expects(:find_or_create_by_id).at_least_once.returns(timestamp)
      timestamp.expects(:text=).at_least_once
      
      NonContributionPara.expects(:find_or_create_by_id).with("debate_p000001").at_least_once.returns(contribution)
      ContributionPara.expects(:find_or_create_by_id).at_least_once.returns(contribution)
      contribution.expects(:fragment=).at_least_once
      contribution.expects(:text=).at_least_once
      contribution.expects(:url=).at_least_once
      contribution.expects(:sequence=).at_least_once
      contribution.expects(:column=).at_least_once
      contribution.expects(:member=).at_least_once
      contribution.expects(:speaker_printed_name=).at_least_once
      
      Debate.expects(:find_or_create_by_id).at_least_once.returns(debate)
      debate.expects(:k_html=).at_least_once
      debate.expects(:paragraphs).at_least_once.returns([])
      
      @parser.parse_pages
    end
    
    should "create the Debate section, including the k_html field" do
      stub_page("test/data/wh_debates.html")
      HansardPage.expects(:new).returns(@page)
      
      section = Section.new
      Section.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_wh').returns(section)
      section.expects(:id).at_least_once.returns('2099-01-01_hansard_c_wh')
      
      intro = Intro.new
      Intro.any_instance.stubs(:paragraphs).returns([])
      Intro.any_instance.stubs(:title=)
      Intro.any_instance.stubs(:id).returns("intro")
      Intro.expects(:find_or_create_by_id).returns(intro)
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by_id).with('intro_p000001').returns(ncpara)
      NonContributionPara.expects(:find_or_create_by_id).with('intro_p000002').returns(ncpara)
      ncpara.stubs(:fragment=)
      ncpara.stubs(:text=)
      ncpara.stubs(:url=)
      ncpara.stubs(:sequence=)
      ncpara.stubs(:column=)
      
      debate = Debate.new
      Debate.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_wh_000002").returns(debate)
      debate.expects(:id).at_least_once.returns("2099-01-01_hansard_c_wh_000002")
      debate.expects(:paragraphs).at_least_once.returns([])

      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_wh_000002_p000001').returns(ncpara)
      ncpara.expects(:fragment=).with(debate)
      ncpara.expects(:text=).with("Motion made, and Question proposed, That the sitting be now adjourned. - (Miss Chloe Smith.)")
      ncpara.expects(:url=).with("#{@url}\#11071984000006")
      ncpara.expects(:sequence=).with(1)
      ncpara.expects(:column=).with("183WH")
      
      timestamp = Timestamp.new
      
      Timestamp.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_wh_000002_p000002").returns(timestamp)
      timestamp.expects(:text=).with("9.30 am")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_wh_000002_p000003").returns(contribution)
      contribution.expects(:fragment=).with(debate)
      contribution.expects(:text=).with('Andrew Gwynne (Denton and Reddish) (Lab): Start of speech')
      contribution.expects(:url=)
      contribution.expects(:sequence=).with(3)
      contribution.expects(:column=)
      contribution.expects(:member=).with("Andrew Gwynne")
      contribution.expects(:speaker_printed_name=).with("Andrew Gwynne")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_wh_000002_p000004").returns(contribution)
      contribution.expects(:fragment=).with(debate)
      contribution.expects(:text=).with("Continuation of speech")
      contribution.expects(:url=)
      contribution.expects(:sequence=).with(4)
      contribution.expects(:member=).with("Andrew Gwynne")
      contribution.expects(:column=).with("184WH")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_wh_000002_p000005").returns(contribution)
      contribution.expects(:fragment=).with(debate)
      contribution.expects(:text=).with("Sarah Teather: I shall complete this point first. I have only four minutes left and I have barely answered any of the points raised in the debate.")
      contribution.expects(:url=)
      contribution.expects(:sequence=).with(5)
      contribution.expects(:member=).with("Sarah Teather")
      contribution.expects(:speaker_printed_name=).with("Sarah Teather")
      contribution.expects(:column=).with("184WH")
      
      debate.expects(:k_html=).with("<h3>School Food</h3><p>&nbsp;</p><p>Motion made, and Question proposed, That the sitting be now adjourned. - (Miss Chloe Smith.)</p><p>&nbsp;</p><div>9.30 am</div><p>&nbsp;</p><p><b>Andrew Gwynne</b> (Denton and Reddish) (Lab): Start of speech</p><p>&nbsp;</p><p>Continuation of speech</p><p>&nbsp;</p><p><b>Sarah Teather</b>: I shall complete this point first. I have only four minutes left and I have barely answered any of the points raised in the debate.</p>")
          
      @parser.parse_pages
    end
  end

end
