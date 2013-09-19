#encoding: utf-8

class HansardMember
  attr_reader :name, :index_name, :post, :party, :constituency, :search_name, :printed_name
  attr_accessor :contributions
  
  def initialize(name, search_name="", constituency="", party="", post="")
    @printed_name = name
    if name =~ / Speaker$/
      @search_name = @index_name = name.squeeze(" ").strip
    else
      if search_name == ""
        @search_name = format_search_name(name).squeeze(" ").strip
        @index_name = format_index_name(name).squeeze(" ").strip
      else
        @search_name = name.squeeze(" ").strip
        @index_name = format_index_name(name).squeeze(" ").strip
      end
    end
    @name = name.squeeze(" ").strip
    @constituency = constituency
    @party = party
    @post = post
    @contributions = []
  end
  
  private
    def format_search_name(member_name)
      if member_name =~ /^Mr |^Ms |^Mrs |^Miss |^Dr/
        parts = member_name.split(" ").reverse
        name = parts.pop
        parts.pop #drop the firstname
        member_name = "#{name} #{parts.reverse.join(" ")}"
      end
      member_name
    end
    
    def format_index_name(member_name)
      if member_name =~ /^(Mr |^Ms |^Mrs |^Miss |^Dr |^Sir )/
        member_name = member_name.gsub($1, "").strip
      end
      member_name
    end
end

class HansardContribution
  attr_reader :link, :start_column
  attr_accessor :end_column, :segments
  
  def initialize(link, start_column)
    @link = link
    @start_column = start_column
    @end_column = ""
    @segments = []
  end
end