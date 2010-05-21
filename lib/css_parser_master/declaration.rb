module CssParserMaster
  class Declaration
    attr_accessor :property, :value, :important, :order
    
    def initialize(property, value, important = false, order = 0)
      # puts "init new declaration: #{property}"
      @property = property
      @value = value
      @important = important
      @order = order            
    end

    def [] index
      case index
      when :value
        value
      when :order
        order
      when :is_important
        important
      when :property
        property
      end
    end        
    
    def to_text(importance = nil)
      "#{property}: #{value}#{ ' !important' if important || importance};"
    end
      
  end
end