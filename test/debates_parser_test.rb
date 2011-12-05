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
    Debate.any_instance.stubs(:save)
    Question.any_instance.stubs(:save)
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
    @page.stubs(:volume).returns("531")
    @page.stubs(:part).returns("190")
  end
  
  context "in general" do
    setup do
      @url = "http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110719/debtext/110719-0001.htm"
      stub_saves
      stub_hansard
      
      @parser = DebatesParser.new("2099-01-01")
      @parser.expects(:section_prefix).returns("d")
      @parser.expects(:link_to_first_page).returns(@url)
    end
    
    should "pick out the timestamps" do
      stub_page("test/data/backbench_business_excerpt.html")
      HansardPage.expects(:new).returns(@page)
      @page.expects(:volume).at_least_once.returns('531')
      @page.expects(:part).at_least_once.returns('190')
      
      Section.stubs(:find_or_create_by_id).returns(Section.new)
      Fragment.stubs(:find_or_create_by_id).returns(Fragment.new)
      Fragment.any_instance.stubs(:k_html=)
      Intro.stubs(:find_or_create_by_id).returns(Intro.new)
      Intro.any_instance.stubs(:k_html=)
      Intro.any_instance.stubs(:paragraphs).returns([])
      
      paragraph = Paragraph.new
      paragraph.stubs(:member=)
      paragraph.stubs(:member).returns("test")
      Paragraph.stubs(:find_or_create_by_id).returns(paragraph)
      
      NonContributionPara.stubs(:find_or_create_by_id).returns(NonContributionPara.new)
      ContributionPara.stubs(:find_or_create_by_id).returns(ContributionPara.new)
      
      debate = Debate.new
      Debate.expects(:find_or_create_by_id).at_least_once.returns(debate)
      debate.expects(:paragraphs).at_least_once.returns([paragraph])
      debate.stubs(:k_html=)
      
      timestamp = Timestamp.new()
      Timestamp.expects(:find_or_create_by_id).at_least_once.returns(timestamp)
      timestamp.expects(:text=).with("2.44 pm")
      timestamp.expects(:text=).with("2.45 pm")
      
      @parser.parse_pages
    end
  end
    
  context "when handling Backbench Business section" do
    setup do
      @url = "http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110719/debtext/110719-0001.htm"
      stub_saves
      stub_hansard
      
      @parser = DebatesParser.new("2099-01-01")
      @parser.expects(:section_prefix).returns("d")
      @parser.expects(:link_to_first_page).returns(@url)
    end
  
    should "correctly recognise the Backbench Business section" do
      stub_page("test/data/backbench_business_header.html")
      HansardPage.expects(:new).returns(@page)
      
      section = Section.new
      Section.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d').returns(section)
      
      intro = Intro.new
      Intro.expects(:find_or_create_by_id).returns(intro)
      intro.expects(:title=).with("Backbench Business")
      intro.stubs(:paragraphs).returns([])
      intro.expects(:k_html=).with("<h3>Backbench Business</h3><p>&nbsp;</p><p>[30th Allotted Day]</p>")
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by_id).returns(ncpara)
      ncpara.expects(:fragment=).with(intro)
      ncpara.expects(:text=).with("[30th Allotted Day]")
      ncpara.expects(:sequence=).with(1)
      ncpara.expects(:url=).with("#{@url}\#11071988000020")
      ncpara.expects(:column=).with("831")
      
      @parser.parse_pages
    end
    
    should "handle the Intro properly and create Debate elements for each debate" do
      stub_page("test/data/backbench_business_excerpt.html")
      stub_saves
      HansardPage.expects(:new).returns(@page)
      
      section = Section.new
      Section.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d').returns(section)
      section.expects(:id).at_least_once.returns('2099-01-01_hansard_c_d')
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000001_p000001').returns(ncpara)
      NonContributionPara.any_instance.stubs(:fragment=)
      NonContributionPara.any_instance.stubs(:text=)
      NonContributionPara.any_instance.stubs(:sequence=)
      NonContributionPara.any_instance.stubs(:url=)
      NonContributionPara.any_instance.stubs(:column=)
      
      intro = Intro.new
      Intro.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000001').returns(intro)
      intro.expects(:title=).with('Backbench Business')
      intro.expects(:section=).with(section)
      intro.expects(:url=)
      intro.expects(:sequence=).with(1)
      intro.stubs(:columns=)
      intro.expects(:paragraphs).at_least_once.returns([])
      intro.expects(:id).at_least_once.returns('2099-01-01_hansard_c_d_000001')
      
      ncpara.expects(:text=).with("[30th Allotted Day]")
      
      debate = Debate.new
      Debate.any_instance.stubs(:paragraphs).returns([])
      Debate.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000002').returns(debate)
      debate.expects(:id).at_least_once.returns('2099-01-01_hansard_c_d_000002')
      debate.expects(:title=).with("Summer Adjournment")
      debate.expects(:k_html=).with(%Q|<h3>Summer Adjournment</h3><p>&nbsp;</p><div>2.44 pm</div><p>&nbsp;</p><p><b>Natascha Engel</b> (North East Derbyshire) (Lab):I beg to move,</p><p>&nbsp;</p><p>That this House has considered matters to be raised before the forthcoming adjournment.</p><p>&nbsp;</p><p>Thank you for calling me, Mr Deputy Speaker; I thought that this moment would never arrive. A total of 66 Members want to participate in the debate, including our newest Member - my hon. Friend the Member for Inverclyde (Mr McKenzie) - who is hoping to make his maiden speech. [Hon. Members: "Hear, hear."] It is unfortunate therefore that two Government statements, important though they both were, have taken almost two hours out of Back Benchers&apos; time. To set an example of brevity and to prepare us for all the constituency carnivals and fairs at which we will be spending most of our time during the recess, I hereby declare the debate open.</p><p>&nbsp;</p><p><b>Mr Deputy Speaker (Mr Lindsay Hoyle)</b>: We are now coming to a maiden speech, and I remind hon. Members not to intervene on it.</p>|)
      
      timestamp = Timestamp.new
      Timestamp.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000002_p000001").returns(timestamp)
      timestamp.expects(:text=).with("2.44 pm")
      timestamp.expects(:column=).with("831")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000002_p000002").returns(contribution)
      contribution.expects(:text=).with("Natascha Engel (North East Derbyshire) (Lab):I beg to move,")
      contribution.expects(:column=).with("831")
      contribution.expects(:member=).with("Natascha Engel")
      contribution.expects(:speaker_printed_name=).with("Natascha Engel")
      
      ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000002_p000003").returns(contribution)
      contribution.expects(:text=).with("That this House has considered matters to be raised before the forthcoming adjournment.")
      contribution.expects(:column=).with("831")
      contribution.expects(:member=).with("Natascha Engel")
      
      ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000002_p000004").returns(contribution)
      contribution.expects(:text=).with("Thank you for calling me, Mr Deputy Speaker; I thought that this moment would never arrive. A total of 66 Members want to participate in the debate, including our newest Member - my hon. Friend the Member for Inverclyde (Mr McKenzie) - who is hoping to make his maiden speech. [Hon. Members: \"Hear, hear.\"] It is unfortunate therefore that two Government statements, important though they both were, have taken almost two hours out of Back Benchers' time. To set an example of brevity and to prepare us for all the constituency carnivals and fairs at which we will be spending most of our time during the recess, I hereby declare the debate open.")
      contribution.expects(:column=).with("831")
      contribution.expects(:member=).with("Natascha Engel")
      
      ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000002_p000005").returns(contribution)
      contribution.expects(:text=).with("Mr Deputy Speaker (Mr Lindsay Hoyle): We are now coming to a maiden speech, and I remind hon. Members not to intervene on it.")
      contribution.expects(:column=).with("831")
      contribution.expects(:member=).with("Lindsay Hoyle")
      contribution.expects(:speaker_printed_name=).with("Mr Deputy Speaker (Mr Lindsay Hoyle)")
      
      debate = Debate.new
      Debate.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000003').returns(debate)
      debate.expects(:title=).with('Business, innovation and skills')
      debate.expects(:id).at_least_once.returns('2099-01-01_hansard_c_d_000003')
      
      Timestamp.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000003_p000001').returns(timestamp)
      timestamp.expects(:text=).with("2.45 pm")
      timestamp.expects(:column=).with("832")
      
      ContributionPara.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000003_p000002').returns(contribution)
      contribution.expects(:text=).with('Mr Iain McKenzie (Inverclyde) (Lab): Thank you, Mr Deputy Speaker, for calling me in this debate to make my maiden speech. I regard it as both a privilege and an honour to represent the constituency of Inverclyde. My constituency has been served extremely well by many accomplished individuals; however, I am only the second Member for Inverclyde to have been born in Inverclyde. The first was, of course, David Cairns.')
      contribution.expects(:member=).with("Iain McKenzie")
      contribution.expects(:speaker_printed_name=).with("Mr Iain McKenzie")
      contribution.expects(:column=).with("832")
      
      ContributionPara.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000003_p000003').returns(contribution)
      contribution.expects(:text=).with('My two immediate predecessors in my seat, which has often had its boundaries changed, were Dr Norman Godman and the late David Cairns. Dr Godman served in the House for 18 years, and his hard work and enduring commitment to the peace process in Northern Ireland earned him a great deal of respect and admiration. David Cairns was an excellent MP for Inverclyde; his parliamentary career was cut all too short by his sudden death, and I am well aware of the great respect that all parties had for David, as did the people of Inverclyde, as reflected in the large majority he held in the 2010 general election. If I can serve my constituents half as well as David, I shall be doing well indeed.')
      contribution.expects(:column=).with("832")
      contribution.expects(:member=).with("Iain McKenzie")
      
      @page.expects(:volume).at_least_once.returns('531')
      @page.expects(:part).at_least_once.returns('190')
      
      @parser.parse_pages
    end
  end

  context "when handling the Oral Answers section" do
    setup do
      @url = "http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110719/debtext/110719-0001.htm"
      stub_saves
      stub_hansard
      
      @parser = DebatesParser.new("2099-01-01")
      @parser.expects(:section_prefix).returns("d")
      @parser.expects(:link_to_first_page).returns(@url)
    end
    
    should "find and deal with the main heading and both intros" do
      stub_page("test/data/debates_and_oral_answers_header.html")
      stub_saves
      HansardPage.expects(:new).returns(@page)
      
      section = Section.new
      Section.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d').returns(section)
      section.expects(:id).at_least_once.returns('2099-01-01_hansard_c_d')
      
      intro = Intro.new
      Intro.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000001').returns(intro)
      intro.expects(:title=).with('House of Commons')
      intro.expects(:section=).with(section)
      intro.expects(:url=).with("#{@url}\#11071988000007")
      intro.expects(:sequence=).with(1)
      intro.stubs(:columns=)
      intro.expects(:paragraphs).at_least_once.returns([])
      intro.expects(:id).at_least_once.returns('2099-01-01_hansard_c_d_000001')
      intro.expects(:k_html=).with("<h1>House of Commons</h1><p>&nbsp;</p><h2>Tuesday 19 July 2011</h2><p>&nbsp;</p><p>The House met at half-past Eleven o'clock</p><p>&nbsp;</p><h3>Prayers</h3><p>&nbsp;</p><p>[Mr Speaker in the Chair]</p>")
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000001_p000001').returns(ncpara)
      ncpara.expects(:text=).with("Tuesday 19 July 2011")
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000001_p000002').returns(ncpara)
      ncpara.expects(:text=).with("The House met at half-past Eleven o'clock")
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000001_p000003').returns(ncpara)
      ncpara.expects(:text=).with("Prayers")
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000001_p000004').returns(ncpara)
      ncpara.expects(:text=).with("[Mr Speaker in the Chair]")
      
      intro = Intro.new
      Intro.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000002').returns(intro)
      intro.expects(:id).at_least_once.returns('2099-01-01_hansard_c_d_000002')
      intro.expects(:title=).with("Oral Answers to Questions")
      intro.stubs(:paragraphs).returns([])
      intro.expects(:k_html=).with("<h3>Oral Answers to Questions</h3>")
            
      @parser.parse_pages
    end
    
    should "create a Question for each question found" do
      stub_page("test/data/debates_and_oral_answers.html")
      stub_saves
      HansardPage.expects(:new).returns(@page)
      
      section = Section.new
      Section.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d').returns(section)
      section.expects(:id).at_least_once.returns('2099-01-01_hansard_c_d')
      
      intro = Intro.new
      Intro.any_instance.stubs(:paragraphs).returns([])
      intro.stubs(:text=)
      intro.stubs(:id).returns("intro")
      Intro.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000001').returns(intro)
      intro.stubs(:k_html=)
      Intro.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000002').returns(intro)
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by_id).with('intro_p000001').returns(ncpara)
      NonContributionPara.expects(:find_or_create_by_id).with('intro_p000002').returns(ncpara)
      NonContributionPara.expects(:find_or_create_by_id).with('intro_p000003').returns(ncpara)
      NonContributionPara.expects(:find_or_create_by_id).with('intro_p000004').returns(ncpara)
      
      question = Question.new
      Question.any_instance.stubs(:paragraphs).returns([])
      Question.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000003").returns(question)
      question.expects(:id).at_least_once.returns("2099-01-01_hansard_c_d_000003")
      question.expects(:department=).with("Foreign and Commonwealth Office")
      question.expects(:title=).with("Syria")
      question.expects(:number=).with("66855")
      question.expects(:k_html=).with("<h3>Foreign and Commonwealth Office</h3><p>&nbsp;</p><p>The Secretary of State was asked - </p><p>&nbsp;</p><h4>Syria</h4><p>&nbsp;</p><p>1. <b>Mr David Hanson</b> (Delyn) (Lab): When he next expects to discuss the situation in Syria with his US counterpart. [66855]</p><p>&nbsp;</p><p><b>The Secretary of State for Foreign and Commonwealth Affairs (Mr William Hague)</b>: I am in regular contact with Secretary Clinton and I last discussed Syria with her on Friday.</p><p>&nbsp;</p><p><b>Mr Hanson</b>: I thank the Foreign Secretary for that answer. Given the recent violence, including the reported shooting of unarmed protesters, does he agree with Secretary of State Clinton that the Syrian Government have lost legitimacy? Given the level of violence, particularly the attacks on the US embassy and the French embassy, what steps is he taking to ensure the security of British citizens who work for the United Kingdom and are operating in Syria now?</p><p>&nbsp;</p><p><b>Mr Hague</b>: The right hon. Gentleman raises some important issues in relation to recent events in Syria. We absolutely deplore the continuing violence against protesters. Reports overnight from the city of Homs suggest that between 10 and 14 people were killed, including a 12-year-old child. We have condemned the attacks on the American and French embassies and we called in the Syrian ambassador last Wednesday to deliver our protests and to demand that Syria observes the requirements of the Vienna convention. The US and British Governments are united in saying that President Assad is losing legitimacy and should reform or step aside, and that continues to be our message.</p><p>&nbsp;</p><p><b>Mr Philip Hollobone</b> (Kettering) (Con): Iran has been involved in training Syrian troops and providing materi&eacute;l assistance, including crowd-dispersal equipment. What assessment has the Foreign Secretary made of the dark hand of Iran in fomenting trouble in the middle east and in supporting illegitimate regimes?</p><p>&nbsp;</p><p><b>Mr Hague</b>: Iran has certainly been involved in the way that my hon. Friend describes, and I set out a few weeks ago that I believed it to be involved in that way. It shows the extraordinary hypocrisy of the Iranian leadership</p><p>&nbsp;</p><p>on this that it has been prepared to encourage protests in Egypt, Tunisia and other countries while it has brutally repressed protest in its own country and is prepared to connive in doing so in Syria.</p><p>&nbsp;</p><p><b>Stephen Twigg</b> (Liverpool, West Derby) (Lab/Co-op): Does the Foreign Secretary agree that the world has been far too slow in its response to the appalling abuses of human rights in Syria? Surely, after the events of the weekend and the past few days in particular, there is now an urgent need for a clear and strong United Nations Security Council resolution.</p><p>&nbsp;</p><p><b>Mr Hague</b>: I think the world has been not so much slow as not sufficiently united on this. It has not been possible for the Arab League to arrive at a clear, strong position, which makes the situation entirely different to that in Libya, where the Arab League called on the international community to assist and intervene. There has not been the necessary unity at the United Nations Security Council and at times Russia has threatened to veto any resolution. Our resolution, which was put forward with our EU partners, remains very much on the table and certainly has the support of nine countries. We would like the support of more than nine countries to be able to put it to a vote in the Security Council, but it is very much on the table and we reserve the right at any time to press it to a vote in the United Nations. The hon. Gentleman is quite right to say that recent events add further to the case for doing so.</p>")
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000003_p000001").returns(ncpara)
      ncpara.expects(:text=).with("The Secretary of State was asked - ")
      ncpara.expects(:fragment=).with(question)
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000003_p000002").returns(contribution)
      contribution.expects(:text=).with("1. Mr David Hanson (Delyn) (Lab): When he next expects to discuss the situation in Syria with his US counterpart. [66855]")
      contribution.expects(:member=).with("David Hanson")
      contribution.expects(:speaker_printed_name=).with("Mr David Hanson")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000003_p000003").returns(contribution)
      contribution.expects(:text=).with("The Secretary of State for Foreign and Commonwealth Affairs (Mr William Hague): I am in regular contact with Secretary Clinton and I last discussed Syria with her on Friday.")
      contribution.expects(:member=).with("William Hague")
      contribution.expects(:speaker_printed_name=).with("The Secretary of State for Foreign and Commonwealth Affairs (Mr William Hague)")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000003_p000004").returns(contribution)
      contribution.expects(:text=).with("Mr Hanson: I thank the Foreign Secretary for that answer. Given the recent violence, including the reported shooting of unarmed protesters, does he agree with Secretary of State Clinton that the Syrian Government have lost legitimacy? Given the level of violence, particularly the attacks on the US embassy and the French embassy, what steps is he taking to ensure the security of British citizens who work for the United Kingdom and are operating in Syria now?")
      contribution.expects(:member=).with("David Hanson")
      contribution.expects(:speaker_printed_name=).with("Mr Hanson")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000003_p000005").returns(contribution)
      contribution.expects(:text=).with("Mr Hague: The right hon. Gentleman raises some important issues in relation to recent events in Syria. We absolutely deplore the continuing violence against protesters. Reports overnight from the city of Homs suggest that between 10 and 14 people were killed, including a 12-year-old child. We have condemned the attacks on the American and French embassies and we called in the Syrian ambassador last Wednesday to deliver our protests and to demand that Syria observes the requirements of the Vienna convention. The US and British Governments are united in saying that President Assad is losing legitimacy and should reform or step aside, and that continues to be our message.")
      contribution.expects(:member=).with("William Hague")
      contribution.expects(:speaker_printed_name=).with("Mr Hague")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000003_p000006").returns(contribution)
      contribution.expects(:text=).with("Mr Philip Hollobone (Kettering) (Con): Iran has been involved in training Syrian troops and providing materi\303\251l assistance, including crowd-dispersal equipment. What assessment has the Foreign Secretary made of the dark hand of Iran in fomenting trouble in the middle east and in supporting illegitimate regimes?")
      contribution.expects(:member=).with("Philip Hollobone")
      contribution.expects(:speaker_printed_name=).with("Mr Philip Hollobone")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000003_p000007").returns(contribution)
      contribution.expects(:text=).with("Mr Hague: Iran has certainly been involved in the way that my hon. Friend describes, and I set out a few weeks ago that I believed it to be involved in that way. It shows the extraordinary hypocrisy of the Iranian leadership")
      contribution.expects(:member=).with("William Hague")
      contribution.expects(:speaker_printed_name=).with("Mr Hague")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000003_p000008").returns(contribution)
      contribution.expects(:text=).with("on this that it has been prepared to encourage protests in Egypt, Tunisia and other countries while it has brutally repressed protest in its own country and is prepared to connive in doing so in Syria.")
      contribution.expects(:member=).with("William Hague")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000003_p000009").returns(contribution)
      contribution.expects(:text=).with("Stephen Twigg (Liverpool, West Derby) (Lab/Co-op): Does the Foreign Secretary agree that the world has been far too slow in its response to the appalling abuses of human rights in Syria? Surely, after the events of the weekend and the past few days in particular, there is now an urgent need for a clear and strong United Nations Security Council resolution.")
      contribution.expects(:member=).with("Stephen Twigg")
      contribution.expects(:speaker_printed_name=).with("Stephen Twigg")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000003_p000010").returns(contribution)
      contribution.expects(:text=).with("Mr Hague: I think the world has been not so much slow as not sufficiently united on this. It has not been possible for the Arab League to arrive at a clear, strong position, which makes the situation entirely different to that in Libya, where the Arab League called on the international community to assist and intervene. There has not been the necessary unity at the United Nations Security Council and at times Russia has threatened to veto any resolution. Our resolution, which was put forward with our EU partners, remains very much on the table and certainly has the support of nine countries. We would like the support of more than nine countries to be able to put it to a vote in the Security Council, but it is very much on the table and we reserve the right at any time to press it to a vote in the United Nations. The hon. Gentleman is quite right to say that recent events add further to the case for doing so.")
      contribution.expects(:member=).with("William Hague")
      contribution.expects(:speaker_printed_name=).with("Mr Hague")
      
      question = Question.new
      Question.any_instance.stubs(:paragraphs).returns([])
      Question.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000004").returns(question)
      question.expects(:id).at_least_once.returns("2099-01-01_hansard_c_d_000004")
      question.expects(:department=).with("Foreign and Commonwealth Office")
      question.expects(:title=).with("Nuclear Non-proliferation and Disarmament")
      question.expects(:number=).with("66858")
      question.expects(:k_html=).with("<h4>Nuclear Non-proliferation and Disarmament</h4><p>&nbsp;</p><p>3. <b>Paul Flynn</b> (Newport West) (Lab): What recent progress his Department has made on nuclear non-proliferation and disarmament. [66858]</p><p>&nbsp;</p><p><b>The Parliamentary Under-Secretary of State for Foreign and Commonwealth Affairs (Alistair Burt)</b>: We continue to work across all three pillars of the non-proliferation treaty to build on the success of last year&apos;s review conference in New York. I am particularly proud of the work we have done towards ensuring the first conference of nuclear weapon states, which was held recently in Paris - the P5 conference - in which further progress was made, particularly towards disarmament.</p>")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000004_p000001").returns(contribution)
      contribution.expects(:text=).with("3. Paul Flynn (Newport West) (Lab): What recent progress his Department has made on nuclear non-proliferation and disarmament. [66858]")
      contribution.expects(:member=).with("Paul Flynn")
      contribution.expects(:speaker_printed_name=).with("Paul Flynn")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000004_p000002").returns(contribution)
      contribution.expects(:text=).with("The Parliamentary Under-Secretary of State for Foreign and Commonwealth Affairs (Alistair Burt): We continue to work across all three pillars of the non-proliferation treaty to build on the success of last year's review conference in New York. I am particularly proud of the work we have done towards ensuring the first conference of nuclear weapon states, which was held recently in Paris - the P5 conference - in which further progress was made, particularly towards disarmament.")
      contribution.expects(:member=).with("Alistair Burt")
      contribution.expects(:speaker_printed_name=).with("The Parliamentary Under-Secretary of State for Foreign and Commonwealth Affairs (Alistair Burt)")
      
      @parser.parse_pages
    end
    
    should "deal with the Topical Questions section" do
      stub_page("test/data/topical_questions.html")
      stub_saves
      HansardPage.expects(:new).returns(@page)
      
      section = Section.new
      Section.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d').returns(section)
      section.expects(:id).at_least_once.returns('2099-01-01_hansard_c_d')
      
      intro = Intro.new
      Intro.any_instance.stubs(:paragraphs).returns([])
      intro.stubs(:text=)
      intro.stubs(:id).returns("intro")
      Intro.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000001').returns(intro)
      Intro.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000002').returns(intro)
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by_id).with('intro_p000001').returns(ncpara)
      NonContributionPara.expects(:find_or_create_by_id).with('intro_p000002').returns(ncpara)
      NonContributionPara.expects(:find_or_create_by_id).with('intro_p000003').returns(ncpara)
      NonContributionPara.expects(:find_or_create_by_id).with('intro_p000004').returns(ncpara)
      
      question = Question.new
      Question.any_instance.stubs(:paragraphs).returns([])
      Question.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000003").returns(question)
      question.expects(:id).at_least_once.returns("2099-01-01_hansard_c_d_000003")
      question.expects(:department=).with("Foreign and Commonwealth Office")
      question.expects(:title=).with("Nuclear Non-proliferation and Disarmament")
      question.expects(:number=).with("66858")
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000003_p000001").returns(ncpara)
      ncpara.expects(:text=).with("The Secretary of State was asked - ")
      ncpara.expects(:fragment=).with(question)
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000003_p000002").returns(contribution)
      contribution.expects(:text=).with("3. Paul Flynn (Newport West) (Lab): What recent progress his Department has made on nuclear non-proliferation and disarmament. [66858]")
      contribution.expects(:member=).with("Paul Flynn")
      contribution.expects(:speaker_printed_name=).with("Paul Flynn")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000003_p000003").returns(contribution)
      contribution.expects(:text=).with("The Parliamentary Under-Secretary of State for Foreign and Commonwealth Affairs (Alistair Burt): We continue to work across all three pillars of the non-proliferation treaty to build on the success of last year's review conference in New York. I am particularly proud of the work we have done towards ensuring the first conference of nuclear weapon states, which was held recently in Paris - the P5 conference - in which further progress was made, particularly towards disarmament.")
      contribution.expects(:member=).with("Alistair Burt")
      contribution.expects(:speaker_printed_name=).with("The Parliamentary Under-Secretary of State for Foreign and Commonwealth Affairs (Alistair Burt)")
      
      question = Question.new
      Question.any_instance.stubs(:paragraphs).returns([])
      Question.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000004").returns(question)
      question.expects(:id).at_least_once.returns("2099-01-01_hansard_c_d_000004")
      question.expects(:department=).with("Foreign and Commonwealth Office")
      question.expects(:title=).with("Topical Questions - T1")
      question.expects(:number=).with("66880")
      question.expects(:k_html=).with("<h4>Topical Questions</h4><p>&nbsp;</p><p>T1. [66880] <b>Harriett Baldwin</b> (West Worcestershire) (Con): If he will make a statement on his departmental responsibilities.</p><p>&nbsp;</p><p><b>The Secretary of State for Foreign and Commonwealth Affairs (Mr William Hague)</b>: Statement goes here</p>")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000004_p000001").returns(contribution)
      contribution.expects(:text=).with("T1. [66880] Harriett Baldwin (West Worcestershire) (Con): If he will make a statement on his departmental responsibilities.")
      contribution.expects(:member=).with("Harriett Baldwin")
      contribution.expects(:speaker_printed_name=).with("Harriett Baldwin")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000004_p000002").returns(contribution)
      contribution.expects(:text=).with("The Secretary of State for Foreign and Commonwealth Affairs (Mr William Hague): Statement goes here")
      contribution.expects(:member=).with("William Hague")
      contribution.expects(:speaker_printed_name=).with("The Secretary of State for Foreign and Commonwealth Affairs (Mr William Hague)")
      
      question = Question.new
      Question.any_instance.stubs(:paragraphs).returns([])
      Question.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000005").returns(question)
      question.expects(:id).at_least_once.returns("2099-01-01_hansard_c_d_000005")
      question.expects(:department=).with("Foreign and Commonwealth Office")
      question.expects(:title=).with("Topical Questions - T2")
      question.expects(:number=).with("66881")
      question.expects(:k_html=).with("<p>T2. [66881] <b>Stephen Mosley</b> (City of Chester) (Con): One of the remaining issues in South Sudan is that of Abyei. Will my right hon. Friend give us an update on what action is being taken to ensure that the promised referendum in Abyei goes ahead successfully?</p><p>&nbsp;</p><p><b>Mr Hague</b>: The urgent thing has been to bring peace and order to Abyei, and that is something that I have discussed with those in the north and south in Sudan, as well as with the Ethiopian Prime Minister and Foreign Minister on my visit to Ethiopia 10 days or so ago. Up to 4,200 Ethiopian troops will go to Abyei, and we have been active in quickly passing the necessary United Nations authority for them to do so. That is designed to pave the way for political progress in Abyei, but the most urgent thing has been to get that Ethiopian force there and to prevent continuing violence.</p>")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000005_p000001").returns(contribution)
      contribution.expects(:text=).with("T2. [66881] Stephen Mosley (City of Chester) (Con): One of the remaining issues in South Sudan is that of Abyei. Will my right hon. Friend give us an update on what action is being taken to ensure that the promised referendum in Abyei goes ahead successfully?")
      contribution.expects(:member=).with("Stephen Mosley")
      contribution.expects(:speaker_printed_name=).with("Stephen Mosley")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000005_p000002").returns(contribution)
      contribution.expects(:text=).with("Mr Hague: The urgent thing has been to bring peace and order to Abyei, and that is something that I have discussed with those in the north and south in Sudan, as well as with the Ethiopian Prime Minister and Foreign Minister on my visit to Ethiopia 10 days or so ago. Up to 4,200 Ethiopian troops will go to Abyei, and we have been active in quickly passing the necessary United Nations authority for them to do so. That is designed to pave the way for political progress in Abyei, but the most urgent thing has been to get that Ethiopian force there and to prevent continuing violence.")
      contribution.expects(:member=).with("William Hague")
      contribution.expects(:speaker_printed_name=).with("Mr Hague")
      
      @parser.parse_pages
    end
    
    should "not treat the first Debate as another Question" do
      stub_page("test/data/topical_questions_end.html")
      stub_saves
      HansardPage.expects(:new).returns(@page)
      
      section = Section.new
      Section.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d').returns(section)
      section.expects(:id).at_least_once.returns('2099-01-01_hansard_c_d')
      
      intro = Intro.new
      Intro.any_instance.stubs(:paragraphs).returns([])
      intro.stubs(:text=)
      intro.stubs(:id).returns("intro")
      Intro.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000001').returns(intro)
      Intro.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_d_000002').returns(intro)
      
      ncpara = NonContributionPara.new
      NonContributionPara.expects(:find_or_create_by_id).with('intro_p000001').returns(ncpara)
      NonContributionPara.expects(:find_or_create_by_id).with('intro_p000002').returns(ncpara)
      NonContributionPara.expects(:find_or_create_by_id).with('intro_p000003').returns(ncpara)
      NonContributionPara.expects(:find_or_create_by_id).with('intro_p000004').returns(ncpara)
      
      question = Question.new
      Question.any_instance.stubs(:paragraphs).returns([])
      Question.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000003").returns(question)
      question.expects(:id).at_least_once.returns("2099-01-01_hansard_c_d_000003")
      question.expects(:department=).with("Foreign and Commonwealth Office")
      question.expects(:title=).with("Topical Questions - T1")
      question.expects(:number=).with("66880")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000003_p000001").returns(contribution)
      contribution.expects(:text=).with("T1. [66880] Harriett Baldwin (West Worcestershire) (Con): If he will make a statement on his departmental responsibilities.")
      contribution.expects(:member=).with("Harriett Baldwin")
      contribution.expects(:speaker_printed_name=).with("Harriett Baldwin")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000003_p000002").returns(contribution)
      contribution.expects(:text=).with("The Secretary of State for Foreign and Commonwealth Affairs (Mr William Hague): Statement goes here")
      contribution.expects(:member=).with("William Hague")
      contribution.expects(:speaker_printed_name=).with("The Secretary of State for Foreign and Commonwealth Affairs (Mr William Hague)")
      
      debate = Debate.new
      Debate.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000004").returns(debate)
      debate.expects(:id).at_least_once.returns("2099-01-01_hansard_c_d_000004")
      debate.stubs(:paragraphs).returns([])
      debate.expects(:k_html=).with("<h3>Point of Order</h3><p>&nbsp;</p><div>12.34 pm</div><p>&nbsp;</p><p><b>Hilary Benn</b> (Leeds Central) (Lab): On a point of order, Mr Speaker. Thank you for taking this point of order, which, for reasons that will readily become apparent, is time critical. Last night, a Member on the Government Benches objected to my hon. Friend the Member for Kilmarnock and Loudoun (Cathy Jamieson) being put on to the Select Committee on Culture, Media and Sport. This was done in the knowledge that it would prevent her from being able to attend today&apos;s very important Committee meeting, at which Rebekah Brooks, James Murdoch and Rupert Murdoch are giving evidence. There is, however, a motion on the Order Paper, tabled by the Committee of Selection, that will allow the House to vote to put this right, but it will not be debated until later. Is there anything you can do, Mr Speaker, to enable it to be taken now, or earlier, so that my hon. Friend can take her place alongside the other members of the Committee when they meet at 2.30 this afternoon?</p>")
      
      timestamp = Timestamp.new
      Timestamp.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000004_p000001").returns(timestamp)
      timestamp.expects(:text=).with("12.34 pm")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_d_000004_p000002").returns(contribution)
      contribution.expects(:text=)
      contribution.expects(:member=).with("Hilary Benn")
      contribution.expects(:speaker_printed_name=).with("Hilary Benn")
      
      @parser.parse_pages
    end
  end
end
