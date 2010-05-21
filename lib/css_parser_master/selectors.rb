module CssParserMaster
  class Selectors
    include Enumerable

    attr_reader :selectors

    def << selector
      selectors << selector      
    end

    def all
      map{|sel| sel.split(',') } 
    end

    def each
      selectors.each { |sel| yield sel }
    end

    def empty?
      selectors.empty?
    end      

    def initialize(selectors = []) 
      @selectors = selectors
    end  
  end
end
