require 'css_parser_master/selector'
require 'css_parser_master/selectors'
require 'css_parser_master/declaration'                             
require 'css_parser_master/declaration_api'
require 'css_parser_master/declarations' 

module CssParserMaster
  class RuleSet
    # Patterns for specificity calculations
    RE_ELEMENTS_AND_PSEUDO_ELEMENTS = /((^|[\s\+\>]+)[\w]+|\:(first\-line|first\-letter|before|after))/i
    RE_NON_ID_ATTRIBUTES_AND_PSEUDO_CLASSES = /(\.[\w]+)|(\[[\w]+)|(\:(link|first\-child|lang))/i

    include DeclarationAPI

    # Array of selector strings.
    attr_reader   :selectors
    
    # Integer with the specificity to use for this RuleSet.
    attr_accessor   :specificity

    def initialize(selectors, block, specificity = nil)
      @selectors = []
      @specificity = specificity
      @declarations = {}
      @order = 0
      parse_selectors!(selectors) if selectors
      parse_declarations!(block)
    end


    # Get the value of a property
    def get_value(property)
      return '' unless property and not property.empty?

      property = property.downcase.strip
      properties = @declarations.inject('') do |val, (key, data)|
        #puts "COMPARING #{key} #{key.inspect} against #{property} #{property.inspect}"
        importance = data[:is_important] ? ' !important' : ''
        val << "#{data[:value]}#{importance}; " if key.downcase.strip == property
        val
      end
      return properties ? properties.strip : ''
    end
    alias_method :[], :get_value

    # Iterate through selectors.
    #
    # Options
    # -  +force_important+ -- boolean
    #
    # ==== Example
    #   ruleset.each_selector do |sel, dec, spec|
    #     ...
    #   end
    def each_selector(options = {}) # :yields: selector, declarations, specificity
      declarations = declarations_to_s(options)  
      # puts "declarations: #{declarations.inspect}" 
      if @specificity
        @selectors.each { |sel| yield Selector.new sel.strip, declarations, @specificity }
      else
        @selectors.each { |sel| yield Selector.new sel.strip, declarations, CssParserMaster.calculate_specificity(sel) }
      end
    end

    # Return the CSS rule set as a string.
    def to_s
      decs = declarations_to_s
      "#{@selectors} { #{decs} }"
    end

    # Split shorthand declarations (e.g. +margin+ or +font+) into their constituent parts.
    def expand_shorthand!
      expand_dimensions_shorthand!
      expand_font_shorthand!
      expand_background_shorthand!
    end

    # Create shorthand declarations (e.g. +margin+ or +font+) whenever possible.
    def create_shorthand!
      create_background_shorthand!
      create_dimensions_shorthand!
      create_font_shorthand!
    end

private


    #--
    # TODO: way too simplistic
    #++
    def parse_selectors!(selectors) # :nodoc:
      @selectors = selectors.split(',') 
    end

public
    # Split shorthand dimensional declarations (e.g. <tt>margin: 0px auto;</tt>)
    # into their constituent parts.
    def expand_dimensions_shorthand! # :nodoc:
      ['margin', 'padding'].each do |property|

        next unless @declarations.has_key?(property)
        
        value = @declarations[property][:value]
        is_important = @declarations[property][:is_important]
        order = @declarations[property][:order]
        t, r, b, l = nil

        matches = value.scan(CssParserMaster::BOX_MODEL_UNITS_RX)

        case matches.length
          when 1
            t, r, b, l = matches[0][0], matches[0][0], matches[0][0], matches[0][0]
          when 2
            t, b = matches[0][0], matches[0][0]
            r, l = matches[1][0], matches[1][0]
          when 3
            t =  matches[0][0]
            r, l = matches[1][0], matches[1][0]
            b =  matches[2][0]
          when 4
            t =  matches[0][0]
            r = matches[1][0]
            b =  matches[2][0]
            l = matches[3][0]
        end

        values = { :is_important => is_important, :order => order }
        @declarations["#{property}-top"]    = values.merge(:value => t.to_s)
        @declarations["#{property}-right"]  = values.merge(:value => r.to_s)
        @declarations["#{property}-bottom"] = values.merge(:value => b.to_s)
        @declarations["#{property}-left"]   = values.merge(:value => l.to_s)
        @declarations.delete(property)
      end
    end

    # Convert shorthand font declarations (e.g. <tt>font: 300 italic 11px/14px verdana, helvetica, sans-serif;</tt>)
    # into their constituent parts.
    def expand_font_shorthand! # :nodoc:
      return unless @declarations.has_key?('font')

      font_props = {}

      # reset properties to 'normal' per http://www.w3.org/TR/CSS21/fonts.html#font-shorthand
      ['font-style', 'font-variant', 'font-weight', 'font-size',
       'line-height'].each do |prop|
        font_props[prop] = 'normal'
       end

      value = @declarations['font'][:value]
      is_important = @declarations['font'][:is_important]
      order = @declarations['font'][:order]

      in_fonts = false

      matches = value.scan(/("(.*[^"])"|'(.*[^'])'|(\w[^ ,]+))/)
      matches.each do |match|
        m = match[0].to_s.strip
        m.gsub!(/[;]$/, '')

        if in_fonts
          if font_props.has_key?('font-family')
            font_props['font-family'] += ', ' + m
          else
            font_props['font-family'] = m
          end
        elsif m =~ /normal|inherit/i
          ['font-style', 'font-weight', 'font-variant'].each do |font_prop|
            font_props[font_prop] = m unless font_props.has_key?(font_prop)
          end
        elsif m =~ /italic|oblique/i
          font_props['font-style'] = m
        elsif m =~ /small\-caps/i
          font_props['font-variant'] = m
        elsif m =~ /[1-9]00$|bold|bolder|lighter/i
          font_props['font-weight'] = m
        elsif m =~ CssParserMaster::FONT_UNITS_RX
          if m =~ /\//
            font_props['font-size'], font_props['line-height'] = m.split('/')
          else
            font_props['font-size'] = m
          end
          in_fonts = true
        end
      end

      font_props.each { |font_prop, font_val| @declarations[font_prop] = {:value => font_val, :is_important => is_important, :order => order} }

      @declarations.delete('font')
    end


    # Convert shorthand background declarations (e.g. <tt>background: url("chess.png") gray 50% repeat fixed;</tt>)
    # into their constituent parts.
    #
    # See http://www.w3.org/TR/CSS21/colors.html#propdef-background
    def expand_background_shorthand! # :nodoc:
      return unless @declarations.has_key?('background')

      value = @declarations['background'][:value]
      is_important = @declarations['background'][:is_important]
      order = @declarations['background'][:order]

      bg_props = {}


      if m = value.match(Regexp.union(CssParserMaster::URI_RX, /none/i)).to_s
        bg_props['background-image'] = m.strip unless m.empty?
        value.gsub!(Regexp.union(CssParserMaster::URI_RX, /none/i), '')
      end

      if m = value.match(/([\s]*^)?(scroll|fixed)([\s]*$)?/i).to_s
        bg_props['background-attachment'] = m.strip unless m.empty?
      end

      if m = value.match(/([\s]*^)?(repeat(\-x|\-y)*|no\-repeat)([\s]*$)?/i).to_s
        bg_props['background-repeat'] = m.strip unless m.empty?
      end

      if m = value.match(CssParserMaster::RE_COLOUR).to_s
        bg_props['background-color'] = m.strip unless m.empty?
      end

      value.scan(CssParserMaster::RE_BACKGROUND_POSITION).each do |m|
        if bg_props.has_key?('background-position')
          bg_props['background-position'] += ' ' + m[0].to_s.strip unless m.empty?
        else
          bg_props['background-position'] =  m[0].to_s.strip unless m.empty?
        end
      end


      if value =~ /([\s]*^)?inherit([\s]*$)?/i
        ['background-color', 'background-image', 'background-attachment', 'background-repeat', 'background-position'].each do |prop|
            bg_props["#{prop}"] = 'inherit' unless bg_props.has_key?(prop) and not bg_props[prop].empty?
        end
      end

      bg_props.each { |bg_prop, bg_val| @declarations[bg_prop] = {:value => bg_val, :is_important => is_important, :order => order} }

      @declarations.delete('background')
    end


    # Looks for long format CSS background properties (e.g. <tt>background-color</tt>) and 
    # converts them into a shorthand CSS <tt>background</tt> property.
    def create_background_shorthand! # :nodoc:
      new_value = ''
      ['background-color', 'background-image', 'background-repeat', 
       'background-position', 'background-attachment'].each do |property|
        if @declarations.has_key?(property)
          new_value += @declarations[property][:value] + ' '
          @declarations.delete(property)
        end
      end

      unless new_value.strip.empty?
        @declarations['background'] = {:value => new_value.gsub(/[\s]+/, ' ').strip}
      end
    end

    # Looks for long format CSS dimensional properties (i.e. <tt>margin</tt> and <tt>padding</tt>) and 
    # converts them into shorthand CSS properties.
    def create_dimensions_shorthand! # :nodoc:
      # geometric
      directions = ['top', 'right', 'bottom', 'left']
      ['margin', 'padding'].each do |property|
        values = {}      

        foldable = @declarations.select { |dim, val| dim == "#{property}-top" or dim == "#{property}-right" or dim == "#{property}-bottom" or dim == "#{property}-left" }
        # All four dimensions must be present
        if foldable.length == 4
          values = {}

          directions.each { |d| values[d.to_sym] = @declarations["#{property}-#{d}"][:value].downcase.strip }

          if values[:left] == values[:right]
            if values[:top] == values[:bottom] 
              if values[:top] == values[:left] # All four sides are equal
                new_value = values[:top]
              else # Top and bottom are equal, left and right are equal
                new_value = values[:top] + ' ' + values[:left]
              end
            else # Only left and right are equal
              new_value = values[:top] + ' ' + values[:left] + ' ' + values[:bottom]
            end
          else # No sides are equal
            new_value = values[:top] + ' ' + values[:right] + ' ' + values[:bottom] + ' ' + values[:left]
          end # done creating 'new_value'

          # Save the new value
          unless new_value.strip.empty?
            @declarations[property] = {:value => new_value.gsub(/[\s]+/, ' ').strip}
          end

          # Delete the shorthand values
          directions.each { |d| @declarations.delete("#{property}-#{d}") }
        end
      end # done iterating through margin and padding
    end


    # Looks for long format CSS font properties (e.g. <tt>font-weight</tt>) and 
    # tries to convert them into a shorthand CSS <tt>font</tt> property.  All 
    # font properties must be present in order to create a shorthand declaration.
    def create_font_shorthand! # :nodoc:
      ['font-style', 'font-variant', 'font-weight', 'font-size',
       'line-height', 'font-family'].each do |prop|
        return unless @declarations.has_key?(prop)
      end

      new_value = ''
      ['font-style', 'font-variant', 'font-weight'].each do |property|
        unless @declarations[property][:value] == 'normal'
          new_value += @declarations[property][:value] + ' '
        end
      end

      new_value += @declarations['font-size'][:value]

      unless @declarations['line-height'][:value] == 'normal'
        new_value += '/' + @declarations['line-height'][:value]
      end

      new_value += ' ' + @declarations['font-family'][:value]

      @declarations['font'] = {:value => new_value.gsub(/[\s]+/, ' ').strip}

      ['font-style', 'font-variant', 'font-weight', 'font-size',
       'line-height', 'font-family'].each do |prop|
       @declarations.delete(prop)
      end

    end
  end
end


