require File.dirname(__FILE__) + '/test_helper'

# Test cases for reading and generating CSS shorthand properties
class CssSelectorParserTests < Test::Unit::TestCase
  include CssParser

  def setup
    @cp = CssParser::Parser.new
    @css = <<-EOT
      html, body, p { margin: 0px; }
      p { padding: 0px; }
      #content { font: 12px/normal sans-serif; }
    EOT
  end

  def test_selector_parser
    selector = CssParser::Selector.new('table', 'margin: 0px', 9999)    
    # puts selector.inspect

    selector.each_declaration do |decl|
      # puts decl.inspect
    end 

    selector = CssParser::Selector.new('table', 'margin: 0px; padding: 0px;', 9999)    
    # puts selector.inspect
  end
end