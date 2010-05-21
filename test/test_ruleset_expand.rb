require File.dirname(__FILE__) + '/test_helper'

class RuleSetExpandingShorthandTests < Test::Unit::TestCase
  include CssParser

  def setup
    @cp = CssParser::Parser.new
  end

# ==== Dimensions shorthand
  def test_getting_dimensions_from_shorthand
    # test various shorthand forms
    ['margin: 0px auto', 'margin: 0px auto 0px', 'margin: 0px auto 0px'].each do |shorthand|
      declarations = expand_declarations(shorthand)
      assert_equal({"margin-right" => "auto", "margin-bottom" => "0px", "margin-left" => "auto", "margin-top" => "0px"}, declarations)
    end

    # test various units
    ['em', 'ex', 'in', 'px', 'pt', 'pc', '%'].each do |unit|
      shorthand = "margin: 0% -0.123#{unit} 9px -.9pc"
      declarations = expand_declarations(shorthand)
      assert_equal({"margin-right" => "-0.123#{unit}", "margin-bottom" => "9px", "margin-left" => "-.9pc", "margin-top" => "0%"}, declarations)    
    end
  end


protected
  def expand_declarations(declarations)
    ruleset = RuleSet.new(nil, declarations)
    ruleset.expand_shorthand!

    collected = {}                
    
    # ruleset.each_declaration do |prop, val, imp|
    ruleset.each_declaration do |decl|
      collected[decl.property.to_s] = decl.value.to_s
    end       
    collected  
  end
end
