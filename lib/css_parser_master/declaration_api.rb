module CssParserMaster
  module DeclarationAPI

    def ensure_valid_declarations! 
      @declarations.each do |d|
        name = d[0]
        prop = d[1]
        if prop.kind_of? Hash
          value = prop[:value]
          important = prop[:is_important]
          @declarations[d[0]] = Declaration.new(name, value, important, @order += 1)
        end
      end
    end
          

    def each_declaration # :yields: property, value, is_important      
      ensure_valid_declarations!       
      decs = @declarations.sort { |a,b| a[1].order <=> b[1].order }
      # puts "decs: #{decs.inspect}"
      decs.each do |decl|
        yield decl[1]
      end
    end


    # Return all declarations as a string.
    #--
    # TODO: Clean-up regexp doesn't seem to work
    #++
    def declarations_to_s(options = {})
     options = {:force_important => false}.merge(options)
     str = ''
     importance = options[:force_important] # ? ' !important' : ''
     self.each_declaration do |decl| 
       str += "#{decl.to_text(importance)}"
     end                     
     str.gsub(/^[\s]+|[\n\r\f\t]*|[\s]+$/mx, '').strip
    end


    # Add a CSS declaration to the current RuleSet.
    #
    #  rule_set.add_declaration!('color', 'blue')
    #
    #  puts rule_set['color']
    #  => 'blue;'
    #
    #  rule_set.add_declaration!('margin', '0px auto !important')
    #
    #  puts rule_set['margin']
    #  => '0px auto !important;'
    #
    # If the property already exists its value will be over-written.
    def add_declaration!(property, value)        
      if value.nil? or value.empty?
        @declarations.delete(property)
        return
      end
    
      value.gsub!(/;\Z/, '')
      is_important = !value.gsub!(CssParserMaster::IMPORTANT_IN_PROPERTY_RX, '').nil?
      property = property.downcase.strip
                                
      decl = CssParserMaster::Declaration.new property.downcase.strip, value.strip, is_important, @order += 1
      # puts "new decl: #{decl.inspect}, #{decl.class}"
      @declarations[property] = decl 
    end
    alias_method :[]=, :add_declaration!

    def parse_declarations!(block) # :nodoc: 
      @declarations ||= {}  

      return unless block

      block.gsub!(/(^[\s]*)|([\s]*$)/, '')

      decs = block.split(/[\;$]+/m)

      decs.each do |decs|
        if matches = decs.match(/(.[^:]*)\:(.[^;]*)(;|\Z)/i)              
          property, value, end_of_declaration = matches.captures

          # puts "parse - property: #{property} , value: #{value}"
          add_declaration!(property, value)          
        end
      end
      
    end  
  end
end