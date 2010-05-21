require 'css_parser_master/declaration_api'

module CssParserMaster
  class Selector
    include CssParserMaster::DeclarationAPI

    attr_accessor :selector, :declarations, :specificity
    
    def initialize(selector, declarations, specificity)
      @selector = selector
      @order = 0     
      @declarations = {}
      parse_declarations!(declarations)  
      # puts "init @declarations: #{@declarations}"
      @specificity = specificity 
    end

    def declarations_to_s(options = {})
      # puts "declarations_to_s: #{declarations.inspect}"
      s = declarations.map do |decl| 
        decl[1].to_text
      end.join('')
      # puts "res: #{s}"
      s
    end

    
    def to_text
      "#{selector}\n{\n#{declarations_to_s}\n} \n"
    end

  end
end
