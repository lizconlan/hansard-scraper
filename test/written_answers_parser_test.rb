require 'test/unit'
require 'mocha'
require 'shoulda'

require 'lib/parsers/commons/written_answers_parser'

class WrittenAnswersParserTest < Test::Unit::TestCase
  def stub_saves
    Intro.any_instance.stubs(:save)
    NonContributionPara.any_instance.stubs(:save)
    ContributionPara.any_instance.stubs(:save)
    ContributionTable.any_instance.stubs(:save)
    Section.any_instance.stubs(:save)
    Hansard.any_instance.stubs(:save)
    Question.any_instance.stubs(:save)
  end
  
  def stub_hansard
    @hansard = Hansard.new()
    Hansard.expects(:find_or_create_by_id).with("2099-01-01_hansard_c").returns(@hansard)
  end
  
  def stub_page(file, mock_html=nil)
    if mock_html
      html = mock_html
    else
      html = File.read(file)
    end
    @page = mock()
    @page.expects(:next_url).returns(nil)
    @page.expects(:doc).at_least_once.returns(Nokogiri::HTML(html))
    @page.expects(:url).at_least_once.returns(@url)
    @page.expects(:volume).at_least_once.returns("531")
    @page.expects(:part).at_least_once.returns("190")
  end
  
  context "in general" do
      setup do
        @url = "http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110719/text/110719w0001.htm"
        stub_saves
        stub_hansard
        
        @parser = WrittenAnswersParser.new("2099-01-01")
        @parser.expects(:section_prefix).returns("w")
        @parser.expects(:link_to_first_page).returns(@url)
      end
  
      should "create the Intro section, including the k_html field" do
        stub_page("test/data/written_answers.html")
        HansardPage.expects(:new).returns(@page)
        
        section = Section.new
        Section.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_w').returns(section)
        section.expects(:id).at_least_once.returns('2099-01-01_hansard_c_w')
        
        intro = Intro.new
        Intro.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_w_000001").returns(intro)
        intro.expects(:title=).with("Written Answers to Questions")
        intro.expects(:id).at_least_once.returns("2099-01-01_hansard_c_w_000001")
        
        ncpara = NonContributionPara.new
        NonContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_w_000001_p000002").returns(ncpara)
        ncpara.expects(:fragment=).with(intro)
        ncpara.expects(:text=).with("Tuesday 19 July 2011")
        ncpara.expects(:sequence=).with(2)
        ncpara.expects(:url=).with("#{@url}\#110719112000009")
        ncpara.expects(:column=).with("773W")
        
        intro.expects(:paragraphs).at_least_once.returns([ncpara])
        intro.expects(:k_html=).with("<h1>Written Answers to Questions</h1><p>&nbsp;</p><h2>Tuesday 19 July 2011</h2>")
        
        #ignore the rest of the file, not relevant
        contribution = ContributionPara.new
        question = Question.new
        question.expects(:id).at_least_once.returns("question")
        
        ContributionPara.expects(:find_or_create_by_id).at_least_once.returns(contribution)
        contribution.expects(:fragment=).at_least_once
        contribution.expects(:text=).at_least_once
        contribution.expects(:url=).at_least_once
        contribution.expects(:sequence=).at_least_once
        contribution.expects(:column=).at_least_once
        contribution.expects(:member=).at_least_once
        contribution.expects(:speaker_printed_name=).at_least_once
        
        Question.expects(:find_or_create_by_id).at_least_once.returns(question)
        question.expects(:k_html=).at_least_once
        question.expects(:paragraphs).at_least_once.returns([])
        
        @parser.parse_pages
      end
      
      should "create the Question sections, including the k_html field" do
        stub_page("test/data/written_answers.html")
        HansardPage.expects(:new).returns(@page)
        
        section = Section.new
        Section.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_w').returns(section)
        section.expects(:id).at_least_once.returns('2099-01-01_hansard_c_w')
        
        intro = Intro.new
        Intro.any_instance.stubs(:paragraphs).returns([])
        Intro.any_instance.stubs(:title=)
        Intro.any_instance.stubs(:id).returns("intro")
        Intro.expects(:find_or_create_by_id).returns(intro)
        
        ncpara = NonContributionPara.new
        NonContributionPara.any_instance.stubs(:pargraphs).returns([])
        NonContributionPara.stubs(:text=)
        NonContributionPara.expects(:find_or_create_by_id).returns(ncpara)
        
        question = Question.new
        Question.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_w_000002").returns(question)
        question.expects(:id).at_least_once.returns("2099-01-01_hansard_c_w_000002")
        question.expects(:paragraphs).at_least_once.returns([])
        question.expects(:k_html=).with('<h3>House of Commons Commission</h3><p>&nbsp;</p><h4>Catering</h4><p>&nbsp;</p><p><b>Mr Leigh</b>: To ask the hon. Member for Caithness, Sutherland and Easter Ross, representing the House of Commons Commission when the House of Commons Commission will respond to the First Report of the Administration Committee, Session 2010-12, on Catering and Retail Services in the House of Commons, HC 560; and if he will make a statement. [67391]</p><p>&nbsp;</p><p><b>John Thurso</b>: The Commission welcomes the Administration Committee&apos;s report on Catering and Retail Services in the House of Commons and is grateful to the Committee for its work. The Commission agrees with most of the recommendations, including all those which the Management Board has recommended be accepted. It has asked that the remainder be discussed with the Committee by officials of the House Service, after which the Commission will consider them again. That is expected to be in September.</p>')
        
        contribution = ContributionPara.new
        ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_w_000002_p000001").returns(contribution)
        contribution.expects(:fragment=).with(question)
        contribution.expects(:text=).with('Mr Leigh: To ask the hon. Member for Caithness, Sutherland and Easter Ross, representing the House of Commons Commission when the House of Commons Commission will respond to the First Report of the Administration Committee, Session 2010-12, on Catering and Retail Services in the House of Commons, HC 560; and if he will make a statement. [67391]')
        contribution.expects(:url=)
        contribution.expects(:sequence=).with(1)
        contribution.expects(:column=)
        contribution.expects(:member=).with("Mr Leigh")
        contribution.expects(:speaker_printed_name=).with("Mr Leigh")
        
        contribution = ContributionPara.new
        ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_w_000002_p000002").returns(contribution)
        contribution.expects(:fragment=).with(question)
        contribution.expects(:text=).with("John Thurso: The Commission welcomes the Administration Committee's report on Catering and Retail Services in the House of Commons and is grateful to the Committee for its work. The Commission agrees with most of the recommendations, including all those which the Management Board has recommended be accepted. It has asked that the remainder be discussed with the Committee by officials of the House Service, after which the Commission will consider them again. That is expected to be in September.")
        contribution.expects(:url=)
        contribution.expects(:sequence=).with(2)
        contribution.expects(:member=).with("John Thurso")
        contribution.expects(:column=)
        
        question = Question.new
        Question.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_w_000003').returns(question)
        question.expects(:id).at_least_once.returns("2099-01-01_hansard_c_w_000003")
        question.expects(:paragraphs).at_least_once.returns([])
        question.expects(:k_html=).with('<h4>Smartphone Applications</h4><p>&nbsp;</p><p><b>Priti Patel</b>: To ask the hon. Member for Caithness, Sutherland and Easter Ross, representing the House of Commons Commission pursuant to the answer of 1 December 2010, Official Report, column 824W, on smartphone applications, what recent progress has been made in the development of smartphone applications for Parliament. [67110]</p><p>&nbsp;</p><p><b>John Thurso</b>: The development of a smartphone application, designed primarily for those visiting Parliament, has been halted. The quotes received from the procurement exercise were too expensive and it has been decided not to continue at this stage. Further work will be undertaken in due course to explore a more cost-effective method of providing visitor information via smartphones.</p>')
        
        contribution = ContributionPara.new
        ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_w_000003_p000001").returns(contribution)
        contribution.expects(:fragment=).with(question)
        contribution.expects(:text=).with('Priti Patel: To ask the hon. Member for Caithness, Sutherland and Easter Ross, representing the House of Commons Commission pursuant to the answer of 1 December 2010, Official Report, column 824W, on smartphone applications, what recent progress has been made in the development of smartphone applications for Parliament. [67110]')
        contribution.expects(:url=)
        contribution.expects(:sequence=).with(1)
        contribution.expects(:column=)
        contribution.expects(:member=).with("Priti Patel")
        contribution.expects(:speaker_printed_name=).with("Priti Patel")
        
        contribution = ContributionPara.new
        ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_w_000003_p000002").returns(contribution)
        contribution.expects(:fragment=).with(question)
        contribution.expects(:text=).with("John Thurso: The development of a smartphone application, designed primarily for those visiting Parliament, has been halted. The quotes received from the procurement exercise were too expensive and it has been decided not to continue at this stage. Further work will be undertaken in due course to explore a more cost-effective method of providing visitor information via smartphones.")
        contribution.expects(:url=)
        contribution.expects(:sequence=).with(2)
        contribution.expects(:member=).with("John Thurso")
        contribution.expects(:column=)
        
        question = Question.new
        Question.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_w_000004').returns(question)
        question.expects(:id).at_least_once.returns('2099-01-01_hansard_c_w_000004')
        question.expects(:paragraphs).at_least_once.returns([])
        question.expects(:k_html=).with("<h3>Home Department</h3><p>&nbsp;</p><h4>Animal Experiments: Scotland</h4><p>&nbsp;</p><p><b>Mr Bain</b>: To ask the Secretary of State for the Home Department how many places in Scotland were designated as a (a) supplying establishment, (b) breeding establishment and (c) scientific procedure establishment under the Animals (Scientific Procedures) Act 1986 at the end of 2010. [67046]</p><p>&nbsp;</p><p><b>Lynne Featherstone</b>: As at 31 December 2010, there were 32 establishments in Scotland designated as scientific procedure establishments under the Animals (Scientific Procedures) Act 1986. Of these, 13 were also designated as breeding establishments and 19 as supplying establishments.</p>")
        
        contribution = ContributionPara.new
        ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_w_000004_p000001").returns(contribution)
        contribution.expects(:fragment=).with(question)
        contribution.expects(:text=).with('Mr Bain: To ask the Secretary of State for the Home Department how many places in Scotland were designated as a (a) supplying establishment, (b) breeding establishment and (c) scientific procedure establishment under the Animals (Scientific Procedures) Act 1986 at the end of 2010. [67046]')
        contribution.expects(:url=)
        contribution.expects(:sequence=).with(1)
        contribution.expects(:column=)
        contribution.expects(:member=).with("Mr Bain")
        contribution.expects(:speaker_printed_name=).with("Mr Bain")
        
        contribution = ContributionPara.new
        ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_w_000004_p000002").returns(contribution)
        contribution.expects(:fragment=).with(question)
        contribution.expects(:text=).with("Lynne Featherstone: As at 31 December 2010, there were 32 establishments in Scotland designated as scientific procedure establishments under the Animals (Scientific Procedures) Act 1986. Of these, 13 were also designated as breeding establishments and 19 as supplying establishments.")
        contribution.expects(:url=)
        contribution.expects(:sequence=).with(2)
        contribution.expects(:member=).with("Lynne Featherstone")
        contribution.expects(:column=)
        
        @parser.parse_pages
      end
    end
    
  context "when dealing with edge cases" do
    setup do
      @url = "http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110719/text/110719w0001.htm"
      stub_saves
      stub_hansard
      
      @parser = WrittenAnswersParser.new("2099-01-01")
      @parser.expects(:section_prefix).returns("w")
      @parser.expects(:link_to_first_page).returns(@url)
    end
    
    should "handle tables without escaping the markup" do
      html = %Q|<div id="content-small">
        <a class="anchor" name="11071988000009"></a>
        <a class="anchor-column" name="column_831"></a>
        <a class="anchor" name="dpthd_2"> </a>
        <a class="anchor" name="110719112000002"> </a>
        <a class="anchor" name="110719w0001.htm_dpthd0"> </a>
        <h3 style="text-transform:uppercase">House of Commons Commission</h3>
        <a class="anchor" name="subhd_48"> </a>
        <a class="anchor" name="110719w0001.htm_sbhd0"> </a>
        <a class="anchor" name="110719112000010"> </a>
        <h3 align="center">Catering</h3>
        <p>
           <a class="anchor" name="qn_0"> </a>
           <a class="anchor" name="110719w0001.htm_wqn0"> </a>
           <a class="anchor" name="110719112000085"> </a>
           <a class="anchor" name="110719112001598"> </a>
           <b>Mr Leigh:</b>
           Question goes here [0123456]
        </p>
        <table border="1">
          <tbody>
          <tr valign="top">
            <td>Heading 1</td>
            <td class="tabletext">They don't use TH so neither can I</td>
          </tr>
          <tr>
            <td>Ukraine</td>
            <td>>£1,000</td>
          </tr>
          </tbody>
        </table>
      </div>|
      stub_page("", html)
      HansardPage.expects(:new).returns(@page)
      
      section = Section.new
      Section.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_w').returns(section)
      section.expects(:id).at_least_once.returns('2099-01-01_hansard_c_w')
      
      question = Question.new
      Question.expects(:find_or_create_by_id).returns(question)
      question.expects(:department=).with('House of Commons Commission')
      question.expects(:title=).with('Catering')
      question.expects(:k_html=).with('<h3>House of Commons Commission</h3><p>&nbsp;</p><h4>Catering</h4><p>&nbsp;</p><p><b>Mr Leigh</b>: Question goes here [0123456]</p><p>&nbsp;</p><table border="1"><tbody> <tr valign="top"> <td>Heading 1</td> <td class="tabletext">They don&apos;t use TH so neither can I</td> </tr> <tr> <td>Ukraine</td> <td>&gt;&pound;1,000</td> </tr> </tbody></table>')
      question.expects(:paragraphs).at_least_once.returns([])
      question.expects(:id).at_least_once.returns("question")
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by_id).with("question_p000001").returns(contribution)
      contribution.expects(:member=).with("Mr Leigh")
      
      contrib_table = ContributionTable.new
      ContributionTable.expects(:find_or_create_by_id).with("question_p000002").returns(contrib_table)
      
      @parser.parse_pages
    end
  end

end
