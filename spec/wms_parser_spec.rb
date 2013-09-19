require './spec/rspec_helper.rb'
require './lib/parsers/commons/wms_parser'

describe WMSParser do
  def stub_saves
    Intro.any_instance.stubs(:save)
    NonContributionPara.any_instance.stubs(:save)
    ContributionPara.any_instance.stubs(:save)
    ContributionTable.any_instance.stubs(:save)
    Section.any_instance.stubs(:save)
    DailyPart.any_instance.stubs(:save)
    Statement.any_instance.stubs(:save)
  end
  
  def stub_daily_part
    @daily_part = DailyPart.new()
    DailyPart.expects(:find_or_create_by_id).with("2099-01-01_hansard_c").returns(@daily_part)
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
      before(:each) do
        @url = "http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110719/wmstext/110719m0001.htm"
        stub_saves
        stub_daily_part
        
        @parser = WMSParser.new("2099-01-01")
        @parser.expects(:section_prefix).returns("wms")
        @parser.expects(:link_to_first_page).returns(@url)
      end
  
      it "should create the Intro section, including the k_html field" do
        stub_page("spec/data/wms.html")
        HansardPage.expects(:new).returns(@page)
        
        section = Section.new
        Section.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_wms').returns(section)
        section.expects(:id).at_least_once.returns('2099-01-01_hansard_c_wms')
        
        intro = Intro.new
        Intro.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_wms_000001").returns(intro)
        intro.expects(:title=).with("Written Ministerial Statements")
        intro.expects(:id).at_least_once.returns("2099-01-01_hansard_c_wms_000001")
        
        ncpara = NonContributionPara.new
        NonContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_wms_000001_p000002").returns(ncpara)
        ncpara.expects(:fragment=).with(intro)
        ncpara.expects(:text=).with("Tuesday 19 July 2011")
        ncpara.expects(:sequence=).with(2)
        ncpara.expects(:url=).with("#{@url}\#11071985000016")
        ncpara.expects(:column=).with("89WS")
        
        intro.expects(:paragraphs).at_least_once.returns([ncpara])
        intro.expects(:k_html=).with("<h1>Written Ministerial Statements</h1><p>&nbsp;</p><h2>Tuesday 19 July 2011</h2>")
        
        #ignore the rest of the file, not relevant
        statement = Statement.new
        Statement.any_instance.stubs(:k_html=)
        statement.stubs(:paragraphs).returns([])
        contribution = ContributionPara.new
        Statement.expects(:find_or_create_by_id).at_least_once.returns(statement)
        
        ContributionPara.expects(:find_or_create_by_id).at_least_once.returns(contribution)
        contribution.expects(:fragment=).at_least_once
        contribution.expects(:text=).at_least_once
        contribution.expects(:url=).at_least_once
        contribution.expects(:sequence=).at_least_once
        contribution.expects(:column=).at_least_once
        contribution.expects(:member=).at_least_once
        contribution.expects(:speaker_printed_name=).at_least_once
        
        @parser.parse_pages
      end
      
      it "should create the Statement sections, including the k_html field" do
        stub_page("spec/data/wms.html")
        HansardPage.expects(:new).returns(@page)
        
        section = Section.new
        Section.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_wms').returns(section)
        section.expects(:id).at_least_once.returns('2099-01-01_hansard_c_wms')
        
        intro = Intro.new
        Intro.any_instance.stubs(:paragraphs).returns([])
        Intro.any_instance.stubs(:title=)
        Intro.any_instance.stubs(:khtml=)
        Intro.any_instance.stubs(:id).returns("intro")
        Intro.expects(:find_or_create_by_id).returns(intro)
        
        ncpara = NonContributionPara.new
        NonContributionPara.any_instance.stubs(:paragraphs).returns([])
        NonContributionPara.stubs(:text=)
        NonContributionPara.expects(:find_or_create_by_id).returns(ncpara)
        ncpara.expects(:fragment=).with(intro)
        
        statement = Statement.new
        Statement.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_wms_000002").returns(statement)
        statement.expects(:id).at_least_once.returns("2099-01-01_hansard_c_wms_000002")
        statement.expects(:department=).with("Justice")
        statement.expects(:title=).with("Secure Estate Strategy for Children and Young People")
        statement.expects(:paragraphs).at_least_once.returns([])
        statement.expects(:k_html=).with("<h3>Justice</h3><p>&nbsp;</p><h4>Secure Estate Strategy for Children and Young People</h4><p>&nbsp;</p><p><b>The Parliamentary Under-Secretary of State for Justice (Mr Crispin Blunt)</b>:Today is the launch of a consultation on the \"Strategy for the Secure Estate for Children and Young People for England and Wales\".</p><p>&nbsp;</p><p>This is a joint publication between the Ministry of Justice and the Youth Justice Board. The consultation invites views on a proposed strategy for the under-18 secure estate for the years 2011-12 to 2014-15. Custody continues to play an important part in the youth justice system for the small number of young people for whom a community sentence is not appropriate. The recent reduction in the number of young people in custody means that the secure estate is now going through a period of change. This presents an opportunity to consider the most appropriate configuration of the estate and consider whether different regimes can deliver improved outcomes.</p><p>&nbsp;</p><p>The consultation, which will run for 12 weeks, and details on how to respond can be found on the Ministry of Justice website at www.justice.gov.uk.</p>")
        
        contribution = ContributionPara.new
        ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_wms_000002_p000001").returns(contribution)
        contribution.expects(:fragment=).with(statement)
        contribution.expects(:text=).with('The Parliamentary Under-Secretary of State for Justice (Mr Crispin Blunt):Today is the launch of a consultation on the "Strategy for the Secure Estate for Children and Young People for England and Wales".')
        contribution.expects(:url=)
        contribution.expects(:sequence=).with(1)
        contribution.expects(:column=)
        contribution.expects(:member=).with("Crispin Blunt")
        contribution.expects(:speaker_printed_name=).with("The Parliamentary Under-Secretary of State for Justice (Mr Crispin Blunt)")
        
        contribution = ContributionPara.new
        ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_wms_000002_p000002").returns(contribution)
        contribution.expects(:fragment=).with(statement)
        contribution.expects(:text=).with('This is a joint publication between the Ministry of Justice and the Youth Justice Board. The consultation invites views on a proposed strategy for the under-18 secure estate for the years 2011-12 to 2014-15. Custody continues to play an important part in the youth justice system for the small number of young people for whom a community sentence is not appropriate. The recent reduction in the number of young people in custody means that the secure estate is now going through a period of change. This presents an opportunity to consider the most appropriate configuration of the estate and consider whether different regimes can deliver improved outcomes.')
        contribution.expects(:url=)
        contribution.expects(:sequence=).with(2)
        contribution.expects(:column=)
        contribution.expects(:member=).with("Crispin Blunt")
        
        contribution = ContributionPara.new
        ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_wms_000002_p000003").returns(contribution)
        contribution.expects(:fragment=).with(statement)
        contribution.expects(:text=).with('The consultation, which will run for 12 weeks, and details on how to respond can be found on the Ministry of Justice website at www.justice.gov.uk.')
        contribution.expects(:url=)
        contribution.expects(:sequence=).with(3)
        contribution.expects(:column=)
        contribution.expects(:member=).with("Crispin Blunt")
        
        statement = Statement.new
        Statement.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_wms_000003").returns(statement)
        statement.expects(:department=).with("Justice")
        statement.expects(:id).at_least_once.returns("2099-01-01_hansard_c_wms_000003")
        statement.expects(:title=).with("Deaths of Service Personnel Overseas (Inquests)")
        statement.expects(:paragraphs).at_least_once.returns([])
        statement.expects(:k_html=).with("<h4>Deaths of Service Personnel Overseas (Inquests)</h4><p>&nbsp;</p><p><b>The Parliamentary Under-Secretary of State for Justice (Mr Jonathan Djanogly)</b>:My hon. friend the Minister for the Armed Forces and I wish to make the latest of our quarterly statements to the House with details of the inquests of service personnel who have died overseas. As always, we wish to express the Government&apos;s deep</p><p>&nbsp;</p><p>and abiding gratitude to all of our service personnel who have served, or are now serving, in Iraq and Afghanistan.</p><p>&nbsp;</p><p>Once again we also extend our sincere condolences to the families of those service personnel who have made the ultimate sacrifice for their country in connection with the operations in Iraq and Afghanistan, and in particular the 11 service personnel who have died since our last statement. Our thoughts remain with all of the families.</p>")
        
        contribution = ContributionPara.new
        ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_wms_000003_p000001").returns(contribution)
        contribution.expects(:fragment=).with(statement)
        contribution.expects(:text=).with("The Parliamentary Under-Secretary of State for Justice (Mr Jonathan Djanogly):My hon. friend the Minister for the Armed Forces and I wish to make the latest of our quarterly statements to the House with details of the inquests of service personnel who have died overseas. As always, we wish to express the Government's deep")
        contribution.expects(:url=)
        contribution.expects(:sequence=).with(1)
        contribution.expects(:member=).with("Jonathan Djanogly")
        contribution.expects(:speaker_printed_name=).with("The Parliamentary Under-Secretary of State for Justice (Mr Jonathan Djanogly)")
        contribution.expects(:column=)
        
        contribution = ContributionPara.new
        ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_wms_000003_p000002").returns(contribution)
        contribution.expects(:fragment=).with(statement)
        contribution.expects(:text=).with("and abiding gratitude to all of our service personnel who have served, or are now serving, in Iraq and Afghanistan.")
        contribution.expects(:url=)
        contribution.expects(:sequence=).with(2)
        contribution.expects(:member=).with("Jonathan Djanogly")
        contribution.expects(:column=)
        
        contribution = ContributionPara.new
        ContributionPara.expects(:find_or_create_by_id).with("2099-01-01_hansard_c_wms_000003_p000003").returns(contribution)
        contribution.expects(:fragment=).with(statement)
        contribution.expects(:text=).with("Once again we also extend our sincere condolences to the families of those service personnel who have made the ultimate sacrifice for their country in connection with the operations in Iraq and Afghanistan, and in particular the 11 service personnel who have died since our last statement. Our thoughts remain with all of the families.")
        contribution.expects(:url=)
        contribution.expects(:sequence=).with(3)
        contribution.expects(:member=).with("Jonathan Djanogly")
        contribution.expects(:column=).with("109WS")
        
        @parser.parse_pages
      end
    end
    
  context "when dealing with edge cases" do
    before(:all) do
      @url = "http://www.publications.parliament.uk/pa/cm201011/cmhansrd/cm110719/text/110719w0001.htm"
      stub_saves
      stub_daily_part
      
      @parser = WMSParser.new("2099-01-01")
      @parser.expects(:section_prefix).returns("wms")
      @parser.expects(:link_to_first_page).returns(@url)
    end
    
    it "should handle tables without escaping the markup" do
      html = %Q|<div id="content-small">
        <a class="anchor" name="11071988000009"></a>
        <a class="anchor-column" name="column_831"></a>
        <a class="anchor" name="subhd_30"> </a>
        <a class="anchor" name="11071985000011"> </a>
        <a class="anchor" name="110719m0001.htm_dpthd9"> </a>
        <h3 style="text-transform:uppercase">House of Commons Commission</h3>
        <a class="anchor" name="subhd_31"> </a>
        <a class="anchor" name="110719m0001.htm_sbhd21"> </a>
        <a class="anchor" name="11071985000038"> </a>
        <h4 align="center">Catering</h4>
        
        <p>
           <a class="anchor" name="st_166"> </a>
           <a class="anchor" name="11071985000590"> </a>
           <a class="anchor" name="110719m0001.htm_spmin21"> </a>
           <a class="anchor" name="11071985000898"> </a>
           <b>Mr Crispin Blunt:</b>
           Statement goes here</p>
        <table border="1">
          <tbody>
          <tr valign="top">
            <td>Heading 1</td>
            <td class="tabletext"><a class="anchor" name="11071985000898"> </a>They don't use TH so neither can I</td>
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
      Section.expects(:find_or_create_by_id).with('2099-01-01_hansard_c_wms').returns(section)
      section.expects(:id).at_least_once.returns('2099-01-01_hansard_c_wms')
      
      statement = Statement.new
      Statement.expects(:find_or_create_by_id).returns(statement)
      statement.expects(:department=).with('House of Commons Commission')
      statement.expects(:title=).with('Catering')
      statement.expects(:paragraphs).at_least_once.returns([])
      statement.expects(:id).at_least_once.returns("statement")
      statement.expects(:k_html=).with('<h3>House of Commons Commission</h3><p>&nbsp;</p><h4>Catering</h4><p>&nbsp;</p><p><b>Mr Crispin Blunt</b>: Statement goes here</p><p>&nbsp;</p><table border="1"><tbody> <tr valign="top"> <td>Heading 1</td> <td class="tabletext"> They don&apos;t use TH so neither can I</td> </tr> <tr> <td>Ukraine</td> <td>&gt;&pound;1,000</td> </tr> </tbody></table>')
      
      contribution = ContributionPara.new
      ContributionPara.expects(:find_or_create_by_id).with("statement_p000001").returns(contribution)
      contribution.expects(:member=).with("Crispin Blunt")
      
      contrib_table = ContributionTable.new
      ContributionTable.expects(:find_or_create_by_id).with("statement_p000002").returns(contrib_table)
      
      @parser.parse_pages
    end
  end

end
