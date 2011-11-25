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
    Hansard.any_instance.stubs(:save)
    Debate.any_instance.stubs(:save)
  end
  
  def stub_hansard
    @hansard = Hansard.new()
    Hansard.expects(:find_or_create_by_id).with("2099-01-01_hansard_c").returns(@hansard)
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
      stub_hansard
      
      @parser = WHDebatesParser.new("2099-01-01")
      @parser.expects(:section_prefix).returns("wh")
      @parser.expects(:link_to_first_page).returns(@url)
    end

    should "create the Intro section and the first Debate" do
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
      
      #intro section complete, expecting a Debate entitled "School Food"
      
      debate = Debate.new
      Debate.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_wh_000002").returns(debate)
      debate.expects(:id).at_least_once.returns("2099-01-01_hansard_c_wh_000002")
      
      NonContributionPara.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_wh_000002_p000001').returns(ncpara)
      ncpara.expects(:fragment=).with(debate)
      ncpara.expects(:text=).with("Motion made, and Question proposed, That the sitting be now adjourned. - (Miss Chloe Smith.)")
      ncpara.expects(:url=).with("#{@url}\#11071984000006")
      ncpara.expects(:sequence=).with(1)
      ncpara.expects(:column=).with("183WH")
      
      intro.expects(:k_html=).with("<h1>Westminster Hall</h1><p>&nbsp;</p><h2>Tuesday 19 July 2011</h2><p>&nbsp;</p><p>[Jim Dobbin in the Chair]</p>")
      
      timestamp = Timestamp.new
      contribution = ContributionPara.new
      
      Timestamp.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_wh_000002_p000002").returns(timestamp)
      timestamp.expects(:text=).with("9.30 am")
      
      ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_wh_000002_p000003").returns(contribution)
      contribution.expects(:fragment=).with(debate)
      contribution.expects(:text=).with('Andrew Gwynne (Denton and Reddish) (Lab): Start of speech')
      contribution.expects(:url=)
      contribution.expects(:sequence=).with(3)
      contribution.expects(:column=)
      contribution.expects(:member=).at_least_once.with("Andrew Gwynne")
      contribution.expects(:speaker_printed_name=).with("Andrew Gwynne")
      
      ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_wh_000002_p000004").returns(contribution)
      contribution.expects(:fragment=).with(debate)
      contribution.expects(:text=).with("Continuation of speech")
      contribution.expects(:url=)
      contribution.expects(:sequence=).with(4)
      contribution.expects(:member=).at_least_once.with("Andrew Gwynne")
      contribution.expects(:column=).with("184WH")
      
      ContributionPara.expects(:find_or_create_by_id).with("2009-01-01_hansard_c_wh_000002_p000005").returns(contribution)
      contribution.expects(:fragment=).with(debate)
      contribution.expects(:text=).with("Sarah Teather: I shall complete this point first. I have only four minutes left and I have barely answered any of the points raised in the debate.")
      contribution.expects(:url=)
      contribution.expects(:sequence=).with(5)
      contribution.expects(:member=).at_least_once.with("Sarah Teather")
      contribution.expects(:speaker_printed_name=).with("Sarah Teather")
      contribution.expects(:column=).with("184WH")
      
      debate.expects(:k_html=).with("<h3>School Food</h3><p>&nbsp;</p><p>Motion made, and Question proposed, That the sitting be now adjourned. - (Miss Chloe Smith.)</p><div>9.30am</div><p><b>Andrew Gwynne</b> (Denton and Reddish) (Lab):  Start of speech</p><p>&nbsp;</p><p>Continuation of speech</p><p>&nbsp;</p><p><b>Sarah Teather</b>: I shall complete this point first. I have only four minutes left and I have barely answered any of the points raised in the debate.</p>")
      
      Timestamp.expects(:find_or_create_by_id).at_least_once.returns(timestamp)
      timestamp.expects(:text=).at_least_once
      
      Debate.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_wh_000003').returns(debate)
      debate.expects(:paragraphs).at_least_once.returns([])
      ContributionPara.expects(:find_or_create_by_id).at_least_once.returns(contribution)
      contribution.expects(:member=).at_least_once
      contribution.expects(:text=).at_least_once
      contribution.expects(:speaker_printed_name=).at_least_once
      contribution.expects(:column=).at_least_once
      contribution.expects(:fragment=).at_least_once
      contribution.expects(:url=).at_least_once
      contribution.expects(:sequence=).at_least_once
      
      @parser.parse_pages
    end
    
    # should "handle the Intro properly and create Debate elements for each debate" do
    #   stub_page("test/data/backbench_business_excerpt.html")
    #   stub_saves
    #   HansardPage.expects(:new).returns(@page)
    #   
    #   section = Section.new
    #   Section.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d').returns(section)
    #   section.expects(:id).at_least_once.returns('2099-01-01_hansard_c_d')
    #   
    #   ncpara = NonContributionPara.new
    #   NonContributionPara.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000001_p000001').returns(ncpara)
    #   NonContributionPara.any_instance.stubs(:fragment=)
    #   NonContributionPara.any_instance.stubs(:text=)
    #   NonContributionPara.any_instance.stubs(:sequence=)
    #   NonContributionPara.any_instance.stubs(:url=)
    #   NonContributionPara.any_instance.stubs(:column=)
    #   
    #   intro = Intro.new
    #   Intro.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000001').returns(intro)
    #   intro.expects(:title=).with('Backbench Business')
    #   intro.expects(:section=).with(section)
    #   intro.expects(:url=)#.with("http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110719/debtext/110719-0001.htm\#11071988000001")
    #   intro.expects(:sequence=).with(1)
    #   intro.stubs(:columns=)
    #   intro.expects(:paragraphs).at_least_once.returns([])
    #   intro.expects(:id).at_least_once.returns('2099-01-01_hansard_c_d_000001')
    #   
    #   snippet1 = HansardSnippet.new
    #   HansardSnippet.expects(:new).at_least_once.returns(snippet1)
    #   
    #   snippet1.expects(:text=).with('Summer Adjournment')
    #   snippet1.expects(:column=).with("831")
    #   
    #   debate = Debate.new
    #   Debate.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000002').returns(debate)
    #   debate.expects(:id).at_least_once.returns('2099-01-01_hansard_c_d_000002')
    #   debate.expects(:title=).with("Summer Adjournment")
    #   debate.expects(:paragraphs).at_least_once.returns([])
    #   
    #   snippet1.expects(:text=).with('2.44 pm')
    #   snippet1.expects(:column=).with("831")
    #   
    #   snippet1.expects(:text=).with("Natascha Engel (North East Derbyshire) (Lab):I beg to move,")
    #   snippet1.expects(:column=).with("831")
    #   
    #   snippet1.expects(:text=).with("That this House has considered matters to be raised before the forthcoming adjournment.")
    #   snippet1.expects(:column=).with("831")
    #   
    #   snippet1.expects(:text=).with("Thank you for calling me, Mr Deputy Speaker; I thought that this moment would never arrive. A total of 66 Members want to participate in the debate, including our newest Member - my hon. Friend the Member for Inverclyde (Mr McKenzie) - who is hoping to make his maiden speech. [Hon. Members: \"Hear, hear.\"] It is unfortunate therefore that two Government statements, important though they both were, have taken almost two hours out of Back Benchers' time. To set an example of brevity and to prepare us for all the constituency carnivals and fairs at which we will be spending most of our time during the recess, I hereby declare the debate open.")
    #   snippet1.expects(:column=).with("831")
    #   
    #   snippet1.expects(:text=).with("Mr Deputy Speaker (Mr Lindsay Hoyle): We are now coming to a maiden speech, and I remind hon. Members not to intervene on it.")
    #   snippet1.expects(:column=).with("831")
    #   
    #   debate = Debate.new
    #   Debate.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000003').returns(debate)
    #   debate.expects(:title=).with('Business, innovation and skills')
    #   debate.expects(:id).at_least_once.returns('2099-01-01_hansard_c_d_000003')
    #   
    #   snippet1.expects(:text=).with('Business, innovation and skills')
    #   snippet1.expects(:column=).with("832")
    #   
    #   snippet1.expects(:text=).with('2.45 pm')
    #   snippet1.expects(:column=).with("832")
    #   
    #   snippet1.expects(:text=).with('Mr Iain McKenzie (Inverclyde) (Lab): Thank you, Mr Deputy Speaker, for calling me in this debate to make my maiden speech. I regard it as both a privilege and an honour to represent the constituency of Inverclyde. My constituency has been served extremely well by many accomplished individuals; however, I am only the second Member for Inverclyde to have been born in Inverclyde. The first was, of course, David Cairns.')
    #   snippet1.expects(:column=).with("832")      
    #   
    #   snippet1.expects(:text=).with('My two immediate predecessors in my seat, which has often had its boundaries changed, were Dr Norman Godman and the late David Cairns. Dr Godman served in the House for 18 years, and his hard work and enduring commitment to the peace process in Northern Ireland earned him a great deal of respect and admiration. David Cairns was an excellent MP for Inverclyde; his parliamentary career was cut all too short by his sudden death, and I am well aware of the great respect that all parties had for David, as did the people of Inverclyde, as reflected in the large majority he held in the 2010 general election. If I can serve my constituents half as well as David, I shall be doing well indeed.')
    #   snippet1.expects(:column=).with("832")
    #   
    #   @page.expects(:volume).at_least_once.returns('531')
    #   @page.expects(:part).at_least_once.returns('190')
    #   
    #   @parser.parse_pages
    # end
  end

end
