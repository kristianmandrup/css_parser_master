require File.dirname(__FILE__) + '/test_helper'

# Test cases for reading and generating CSS shorthand properties
class CssParserBasicTests < Test::Unit::TestCase
  include CssParser

  def setup
    @cp = CssParser::Parser.new
    @css = <<-EOT
      html, body, p { margin: 0px; }
      p { padding: 0px; }
      #content { font: 12px/normal sans-serif; }
    EOT
  end

  def test_finding_by_selector
    @cp.add_block!(@css)
    assert_equal 'margin: 0px;', @cp.find_by_selector('body').join(' ')
    assert_equal 'margin: 0px; padding: 0px;', @cp.find_by_selector('p').join(' ')
  end

  def test_adding_block
    @cp.add_block!(@css)
    # @cp.selector_declarations do |sel, decl|
    #   puts "sel: #{sel.inspect}"
    #   puts "decl: #{decl.inspect}"      
    # end        
    
    assert_equal 'margin: 0px;', @cp.find_by_selector('body').join
  end

  def test_adding_a_rule
    @cp.add_rule!('div', 'color: blue;')

    # @cp.selector_declarations do |sel, decl|
    #   puts "sel: #{sel.inspect}"
    #   puts "decl: #{decl.inspect}"      
    # end    
    
    assert_equal 'color: blue;', @cp.find_by_selector('div').join(' ')
  end

  def test_adding_a_rule_set
    rs = CssParser::RuleSet.new('div', 'color: blue;')
    @cp.add_rule_set!(rs)
    assert_equal 'color: blue;', @cp.find_by_selector('div').join(' ')
  end

  def test_selector_declarations
    expected = [
       {:selector => "#content p", :declarations => "color: #fff;", :specificity => 101},
       {:selector => "a", :declarations => "color: #fff;", :specificity => 1}
    ]
    
    actual = []
    rs = RuleSet.new('#content p, a', 'color: #fff;')
    @cp.add_rule_set!(rs)    
    @cp.selector_declarations do |sel, decl|
      # puts "sel: #{sel.to_text}"
      # puts "decl: #{decl[1].to_text}"      
    end    
    # assert_equal(expected, actual)
  end


  def test_toggling_uri_conversion
    # with conversion
    cp_with_conversion = Parser.new(:absolute_paths => true)
    cp_with_conversion.add_block!("body { background: url('../style/yellow.png?abc=123') };",
                                  :base_uri => 'http://example.org/style/basic.css')

    assert_equal "background: url('http://example.org/style/yellow.png?abc=123');",
                 cp_with_conversion['body'].join(' ')
    
    # without conversion
    cp_without_conversion = Parser.new(:absolute_paths => false)
    cp_without_conversion.add_block!("body { background: url('../style/yellow.png?abc=123') };",
                                     :base_uri => 'http://example.org/style/basic.css')

    assert_equal "background: url('../style/yellow.png?abc=123');",
                 cp_without_conversion['body'].join(' ')
  end

end
