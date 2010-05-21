require 'uri'
require 'digest/md5'
require 'zlib'
require 'iconv'

module CssParserMaster
  VERSION = '1.2.5'

  # Merge multiple CSS RuleSets by cascading according to the CSS 2.1 cascading rules 
  # (http://www.w3.org/TR/REC-CSS2/cascade.html#cascading-order).
  #
  # Takes one or more RuleSet objects.
  #
  # Returns a RuleSet.
  #
  # ==== Cascading
  # If a RuleSet object has its +specificity+ defined, that specificity is 
  # used in the cascade calculations.  
  #
  # If no specificity is explicitly set and the RuleSet has *one* selector, 
  # the specificity is calculated using that selector.
  #
  # If no selectors or multiple selectors are present, the specificity is 
  # treated as 0.
  #
  # ==== Example #1
  #   rs1 = RuleSet.new(nil, 'color: black;')
  #   rs2 = RuleSet.new(nil, 'margin: 0px;')
  #
  #   merged = CssParserMaster.merge(rs1, rs2)
  #
  #   puts merged
  #   => "{ margin: 0px; color: black; }"
  #
  # ==== Example #2
  #   rs1 = RuleSet.new(nil, 'background-color: black;')
  #   rs2 = RuleSet.new(nil, 'background-image: none;')
  #
  #   merged = CssParserMaster.merge(rs1, rs2)
  #
  #   puts merged
  #   => "{ background: none black; }"
  #--
  # TODO: declaration_hashes should be able to contain a RuleSet
  #       this should be a Class method
  def self.merge(*rule_sets)
    @folded_declaration_cache = {}

    # in case called like CssParser.merge([rule_set, rule_set])
    rule_sets.flatten! if rule_sets[0].kind_of?(Array)
    
    unless rule_sets.all? {|rs| rs.kind_of?(CssParser::RuleSet)}
      raise ArgumentError, "all parameters must be CssParser::RuleSets."
    end

    return rule_sets[0] if rule_sets.length == 1

    # Internal storage of CSS properties that we will keep
    properties = {}

    rule_sets.each do |rule_set|
      rule_set.expand_shorthand!
      
      specificity = rule_set.specificity
      unless specificity
        if rule_set.selectors.length == 1
          specificity = calculate_specificity(rule_set.selectors[0])
        else
          specificity = 0
        end
      end

      rule_set.each_declaration do |decl|
        
        property = decl.property
        value = decl.value
        is_important = decl.important
        
        # Add the property to the list to be folded per http://www.w3.org/TR/CSS21/cascade.html#cascading-order
        if not properties.has_key?(decl.property) or
               is_important or # step 2
               properties[property][:specificity] < specificity or # step 3
               properties[property][:specificity] == specificity # step 4    
          properties[property] = {:value => value, :specificity => specificity, :is_important => is_important}            
        end
      end
    end

    merged = RuleSet.new(nil, nil)

    # TODO: what about important
    properties.each do |property, details|
      merged[property.strip] = details[:value].strip
    end

    merged.create_shorthand!
    merged
  end

  # Calculates the specificity of a CSS selector
  # per http://www.w3.org/TR/CSS21/cascade.html#specificity
  #
  # Returns an integer.
  #
  # ==== Example
  #  CssParser.calculate_specificity('#content div p:first-line a:link')
  #  => 114
  #--
  # Thanks to Rafael Salazar and Nick Fitzsimons on the css-discuss list for their help.
  #++
  def self.calculate_specificity(selector)
    a = 0
    b = selector.scan(/\#/).length
    c = selector.scan(NON_ID_ATTRIBUTES_AND_PSEUDO_CLASSES_RX).length
    d = selector.scan(ELEMENTS_AND_PSEUDO_ELEMENTS_RX).length

    (a.to_s + b.to_s + c.to_s + d.to_s).to_i
  rescue
    return 0
  end

  # Make <tt>url()</tt> links absolute.
  #
  # Takes a block of CSS and returns it with all relative URIs converted to absolute URIs.
  #
  # "For CSS style sheets, the base URI is that of the style sheet, not that of the source document."
  # per http://www.w3.org/TR/CSS21/syndata.html#uri
  #
  # Returns a string.
  #
  # ==== Example
  #  CssParser.convert_uris("body { background: url('../style/yellow.png?abc=123') };", 
  #               "http://example.org/style/basic.css").inspect
  #  => "body { background: url('http://example.org/style/yellow.png?abc=123') };"
  def self.convert_uris(css, base_uri)
    out = ''
    base_uri = URI.parse(base_uri) unless base_uri.kind_of?(URI)

    out = css.gsub(URI_RX) do |s|
      uri = $1.to_s
      uri.gsub!(/["']+/, '')
      # Don't process URLs that are already absolute
      unless uri =~ /^[a-z]+\:\/\//i
        begin
          uri = base_uri.merge(uri) 
        rescue; end
      end
      "url('" + uri.to_s + "')"
    end
    out
  end
end

require File.dirname(__FILE__) + '/css_parser_master/rule_set'
require File.dirname(__FILE__) + '/css_parser_master/regexps'
require File.dirname(__FILE__) + '/css_parser_master/parser'