require 'rubygems'

require 'bundler'
Bundler.setup

require 'rake'
require 'rake/testtask'

require 'mongo_mapper'
require 'time'
require 'rcov'

#parser libraries
require 'lib/parsers/commons/debates_parser'
require 'lib/parsers/commons/wh_debates_parser'
require 'lib/parsers/commons/wms_parser'
require 'lib/parsers/commons/written_answers_parser'


#indexer
require 'lib/indexer'

#persisted models
require 'models/hansard'
require 'models/section'
require 'models/fragment'
require 'models/paragraph'

#non-persisted models
require 'models/hansard_member'
require 'models/hansard_page'
require 'models/snippet'

MONGO_URL = ENV['MONGOHQ_URL'] || YAML::load(File.read("config/mongo.yml"))[:mongohq_url]

env = {}
MongoMapper.config = { env => {'uri' => MONGO_URL} }
MongoMapper.connect(env)

desc "scrape a day's worth of hansard"
task :scrape_hansard do
  date = ENV['date']

  #make sure date has been supplied and is valid
  unless date
    raise 'need to specify date=yyyy-mm-dd'
  else
    unless date =~ /^\d{4}-\d{2}-\d{2}$/
      raise 'need to specify date=yyyy-mm-dd'
    end
  end
  Date.parse(date)

  #great, go
  # parser = DebatesParser.new(date)
  # parser.parse_pages
  # 
  parser = WHDebatesParser.new(date)
  parser.parse_pages
  # 
  parser = WMSParser.new(date)
  parser.parse_pages
  # 
  # # TODO: Petitions
  # 
  parser = WrittenAnswersParser.new(date)
  parser.parse_pages
  # 
  # # TODO: Ministerial Corrections
end

desc "index a day's worth of hansard"
task :index_hansard do
  date = ENV['date']

  #make sure date has been supplied and is valid
  unless date
    raise 'need to specify date=yyyy-mm-dd'
  else
    unless date =~ /^\d{4}-\d{2}-\d{2}$/
      raise 'need to specify date=yyyy-mm-dd'
    end
  end
  Date.parse(date)
  
  #great, go
  indexer = Indexer.new
  
  hansard = Hansard.find_by_date(date)
  hansard.sections.each do |section|
    section.fragments.each do |fragment|
      if fragment.columns.size > 1
        columns = "#{fragment.columns.first} to #{fragment.columns.last}"
      else
        columns = fragment.columns.first
      end
      snippet_hash = {
        :id => fragment.id,
        :published_at => Time.parse("#{hansard.date}T00:00:01Z"),
        :search_text => fragment.paragraphs.collect { |x| x.text }.join(' '),
        :subject => fragment.title,
        :volume => hansard.volume,
        :part => hansard.part,
        :columns => columns,
        :url => fragment.url,
        :house => hansard.house,
        :section => section.name
      }
      if fragment.respond_to?("members")
        snippet_hash[:members] = fragment.members
      end
      if fragment.respond_to?("chair")
        snippet_hash[:chair] = fragment.chair
      end
      if fragment.respond_to?("number")
        snippet_hash[:question] = fragment.number
      end
      if fragment.respond_to?("department")
        snippet_hash[:department] = fragment.department
      end
      snippet = Snippet.new(snippet_hash)
      indexer.add_document(snippet)
    end
  end
end

namespace :kindle do
  desc "Generate an HoC Kindle periodical for the given date"
  task :generate_edition_commons do
    date = ENV['date']

    #make sure date has been supplied and is valid
    unless date
      raise 'need to specify date in yyyy-mm-dd format'
    else
      unless date =~ /^\d{4}-\d{2}-\d{2}$/
        raise 'need to specify date in yyyy-mm-dd format'
      end
    end
    parsed_date = Date.parse(date)

    display_date = "#{parsed_date.strftime("%A %d %B %Y")}"
    if display_date =~ /^(([A-Z][a-z]*day )0(\d)) [A-Z]/
      display_date = display_date.gsub($1, "#{$2}#{$3}")
    end

    #make sure there is hansard content available for the requested date
    hansard = Hansard.find("#{date}_hansard_c")
    unless hansard
      raise "No Hansard content available for #{date}"
    end
    if hansard.sections == []
      raise "No Hansard content available for #{date}"
    end
    
    rm_r "kindle"
    mkdir "kindle"
    cp "resources/masthead.gif", "kindle/masthead.gif"
    
    #create the backbone files
    opf_manifest = ""
    opf_spine = ""
    opf_guide = ""
    
    contents_file = File.open("kindle/contents.html", 'w')
    opf_file = File.open("kindle/HoC_Hansard.opf", 'w')
    ncx_file = File.open("kindle/nav-contents.ncx", 'w')
    
    contents_file.write(%Q|<html>
  <head>
    <meta content="text/html; charset=utf-8" http-equiv="Content-Type"/>
    <title>Table of Contents</title>
  </head>
  <body>
    <h1>House of Commons</h1>
    <p>&nbsp;</p>
    <h2>#{display_date}</h2>
|)
    
    opf_file.write(%Q|<?xml version='1.0' encoding='utf-8'?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="HoC_Hansard_#{date}">
  <metadata>
    <dc-metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
      <dc:title>Hansard (Commons)</dc:title>
      <dc:language>en-gb</dc:language>
      <meta content="cover-image" name="cover"/>
      <dc:creator>House of Commons</dc:creator>
      <dc:publisher>House of Commons</dc:publisher>
      <dc:subject>Parliamentary Debates</dc:subject>
      <dc:date>#{date}</dc:date>
      <dc:description>An early attempt at getting Hansard onto the Kindle</dc:description>
    </dc-metadata>
    <x-metadata>
      <output content-type="application/x-mobipocket-subscription-magazine" encoding="utf-8"/>
    </x-metadata>
  </metadata>
|)
  
    ncx_file.write(%Q|<?xml version='1.0' encoding='utf-8'?>
<!DOCTYPE ncx PUBLIC "-//NISO//DTD ncx 2005-1//EN" "http://www.daisy.org/z3986/2005/ncx-2005-1.dtd">
<ncx xmlns:mbp="http://mobipocket.com/ns/mbp" xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1" xml:lang="en-GB">
  <head>
    <meta content="Hansard_Commons_#{date}" name="dtb:uid"/>
    <meta content="2" name="dtb:depth"/>
    <meta content="0" name="dtb:totalPageCount"/>
    <meta content="0" name="dtb:maxPageNumber"/>
  </head>
  <docTitle>
    <text>House of Commons Hansard</text>
  </docTitle>
  <docAuthor>
    <text>House of Commons</text>
  </docAuthor>
  <navMap>
    <navPoint playOrder="0" class="periodical" id="periodical">
      <mbp:meta-img src="masthead.gif" name="mastheadImage"/>
      <navLabel>
        <text>Table of Contents</text>
      </navLabel>
      <content src="contents.html"/>
|)

    play_order = 0
    
    hansard.sections.each do |section|
      file_refs = []
      fragments = section.k_html_fragments
      
      case section.name
        when "Debates and Oral Answers"
          counter = 0
        when "Westminster Hall"
          counter = 200
        when "Written Ministerial Statements"
          counter = 400
        when "Petitions"
          counter = 600
        when "Written Answers"
          counter = 700
        when "Ministerial Corrections"
          counter = 900
        else
          raise "unrecognised section: #{section.name}"
      end
      
      #write the section headers
      contents_file.write(%Q|    <p>&nbsp;</p>
    <h3>#{section.name}</h3>
    <ul>
|)
      play_order += 1
      ncx_file.write(%Q|    <navPoint playOrder="#{play_order}" class="section" id="#{section.name.gsub(" ", "_")}">
      <navLabel>
        <text>#{section.name}</text>
      </navLabel>
|)
      
      fragments.each do |frag|
        counter += 1
        file_ref = counter.to_s.rjust(3, "0") #padding added for the benefit of the Debates section
        
        #write to the contents file
        file_refs << file_ref
        contents_file.write(%Q|      <li><a href="#{file_ref}.html">#{frag[:title]}</a></li>\n|)
        
        #write to the ncx file
        play_order +=1
        ncx_file.write(%Q|        <content src="#{file_ref}.html"/>
        <navPoint playOrder="#{play_order}" class="article" id="item-#{file_ref}">
          <navLabel>
            <text>#{frag[:title]}</text>
          </navLabel>
          <content src="#{file_ref}.html"/>
        </navPoint>\n|)
        
        #queue up the opf sections
        opf_manifest = %Q|#{opf_manifest}    <item href="#{file_ref}.html" media-type="application/xhtml+xml" id="#{file_ref}"/>\n|
        opf_spine = %Q|#{opf_spine}    <itemref idref="#{file_ref}"/>\n|
        opf_guide = %Q|#{opf_guide}    <reference href="#{file_ref}.html" type="text" title="#{frag[:title]}"/>\n|
        
        #create the file itself
        File.open("kindle/#{file_ref}.html", 'w') { |f| f.write(%Q|<html><body>#{frag[:html]}</body></html>|) }
      end
      
      #write the section footers
      contents_file.write(%Q|    </ul>\n|)
      ncx_file.write(%Q|    </navPoint>\n|)
    end
    
    #construct the opf_file
    opf_file.write(%Q|  <manifest>\n#{opf_manifest}    <item href="contents.html" media-type="application/xhtml+xml" id="contents"/>\n    <item href="nav-contents.ncx" media-type="application/x-dtbncx+xml" id="nav-contents"/>\n  </manifest>\n|)
    opf_file.write(%Q|  <spine toc="nav-contents">\n    <itemref idref="contents"/>\n#{opf_spine}  </spine>\n|)
    opf_file.write(%Q|  <guide>\n    <reference href="contents.html" type="toc" title="Table of Contents"/>\n#{opf_guide}  </guide>\n|)
    opf_file.write(%Q|</package>|)
    opf_file.close
    
    #close open filestreams
    contents_file.write(%Q|  </body>\n</html>|)
    contents_file.close
    ncx_file.close
    
    `cd kindle; kindlegen HoC_Hansard.opf`
  end
end

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/*_test.rb']
end

namespace :test do
  desc "rcov"
  task :rcov do
    rm_f "coverage"
    rm_f "coverage.data"
    rcov = "rcov --rails --aggregate coverage.data -Ilib \
                     --text-summary -x 'bundler/*,gems/*'"
    system("#{rcov} --html */*_test.rb")
  end
end