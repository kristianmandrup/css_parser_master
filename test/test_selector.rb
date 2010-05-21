require File.dirname(__FILE__) + '/test_helper'

# Test cases for the CssParser.
class CssSelectorTests < Test::Unit::TestCase
  include CssParser

  def setup
    @cp = Parser.new
  end

  def test_at_page_rule
    # from http://www.w3.org/TR/CSS21/page.html#page-selectors
    css = <<-EOT
      @page { margin: 2cm }

      @page :first {
        margin-top: 10cm
      }
    EOT

    @cp.add_block!(css)

    assert_equal 'margin: 2cm;', @cp.find_by_selector('@page').join(' ')
    # assert_equal 'margin-top: 10cm;', @cp.find_by_selector('@page :first').join(' ')
  end
end