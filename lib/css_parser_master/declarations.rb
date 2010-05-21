module CssParserMaster
  class Declarations
    include Enumerable

    attr_reader :declarations

    def << declaration
      declarations << declaration      
    end

    def each
      @declarations.each { |dec| yield dec }
    end

    def empty?
      declarations.empty?
    end      

    def initialize(declarations)
      @declarations = declarations
    end  
  end
end
