module CssParserMaster
  # Exception class used for any errors encountered while downloading remote files.
  class RemoteFileError < IOError; end

  # Exception class used if a request is made to load a CSS file more than once.
  class CircularReferenceError < StandardError; end


  # == Parser class
  #
  # All CSS is converted to UTF-8.
  #
  # When calling Parser#new there are some configuaration options:
  # [<tt>absolute_paths</tt>] Convert relative paths to absolute paths (<tt>href</tt>, <tt>src</tt> and <tt>url('')</tt>. Boolean, default is <tt>false</tt>.
  # [<tt>import</tt>] Follow <tt>@import</tt> rules. Boolean, default is <tt>true</tt>.
  # [<tt>io_exceptions</tt>] Throw an exception if a link can not be found. Boolean, default is <tt>true</tt>.
  class Parser
    USER_AGENT   = "Ruby CSS Parser/#{CssParserMaster::VERSION} (http://code.dunae.ca/css_parser/)"

    STRIP_CSS_COMMENTS_RX = /\/\*.*?\*\//m
    STRIP_HTML_COMMENTS_RX = /\<\!\-\-|\-\-\>/m

    # Initial parsing
    RE_AT_IMPORT_RULE = /\@import[\s]+(url\()?["''"]?(.[^'"\s"']*)["''"]?\)?([\w\s\,^\])]*)\)?;?/

    #--
    # RE_AT_IMPORT_RULE = Regexp.new('@import[\s]*(' + RE_STRING.to_s + ')([\w\s\,]*)[;]?', Regexp::IGNORECASE) -- should handle url() even though it is not allowed
    #++

    # Array of CSS files that have been loaded.
    attr_reader   :loaded_uris

    #attr_reader   :rules

    #--
    # Class variable? see http://www.oreillynet.com/ruby/blog/2007/01/nubygems_dont_use_class_variab_1.html
    #++
    @folded_declaration_cache = {}
    class << self; attr_reader :folded_declaration_cache; end

    def initialize(options = {})
      @options = {:absolute_paths => false,
                  :import => true,
                  :io_exceptions => true}.merge(options)

      # array of RuleSets
      @rules = []
    
      
      @loaded_uris = []
    
      # unprocessed blocks of CSS
      @blocks = []
      reset!
    end

    # Get declarations by selector.
    #
    # +media_types+ are optional, and can be a symbol or an array of symbols.
    # The default value is <tt>:all</tt>.
    #
    # ==== Examples
    #  find_by_selector('#content')
    #  => 'font-size: 13px; line-height: 1.2;'
    #
    #  find_by_selector('#content', [:screen, :handheld])
    #  => 'font-size: 13px; line-height: 1.2;'
    #
    #  find_by_selector('#content', :print)
    #  => 'font-size: 11pt; line-height: 1.2;'
    #
    # Returns an array of declarations.
    def find_by_selector(selector, media_types = :all)
      out = []
      each_selector(media_types) do |sel|
        # puts "selector declaration: #{sel.declarations_to_s}"
        out << sel.declarations_to_s if sel.selector.strip == selector.strip
      end
      out
    end
    alias_method :[], :find_by_selector


    # Add a raw block of CSS.
    #
    # In order to follow +@import+ rules you must supply either a
    # +:base_dir+ or +:base_uri+ option.
    #
    # ==== Example
    #   css = <<-EOT
    #     body { font-size: 10pt }
    #     p { margin: 0px; }
    #     @media screen, print {
    #       body { line-height: 1.2 }
    #     }
    #   EOT
    #
    #   parser = CssParserMaster::Parser.new
    #   parser.add_block!(css)
    #--
    # TODO: add media_type
    #++
    def add_block!(block, options = {})
      options = {:base_uri => nil, :base_dir => nil, :charset => nil, :media_types => :all}.merge(options)
      
      block = cleanup_block(block)

      if options[:base_uri] and @options[:absolute_paths]
        block = CssParserMaster.convert_uris(block, options[:base_uri])
      end

      # Load @imported CSS
      block.scan(RE_AT_IMPORT_RULE).each do |import_rule|        
        media_types = []
        if media_string = import_rule[import_rule.length-1]
          media_string.split(/\s|\,/).each do |t|
            media_types << t.to_sym unless t.empty?
          end
        end

        import_path = import_rule[1].to_s.gsub(/['"]*/, '').strip
        
        if options[:base_uri]
          import_uri = URI.parse(options[:base_uri].to_s).merge(import_path)
          load_uri!(import_uri, options[:base_uri], media_types)
        elsif options[:base_dir]
          load_file!(import_path, options[:base_dir], media_types)
        end     
      end

      # Remove @import declarations
      block.gsub!(RE_AT_IMPORT_RULE, '')      
      parse_block_into_rule_sets!(block, options)
      
    end

    # Add a CSS rule by setting the +selectors+, +declarations+ and +media_types+.
    #
    # +media_types+ can be a symbol or an array of symbols.
    def add_rule!(selectors, declarations, media_types = :all)
      rule_set = RuleSet.new(selectors, declarations)
      # rule_set = RuleSet.new(Selectors.new(selectors), declarations)
      add_rule_set!(rule_set, media_types)
    end

    # Add a CssParserMaster RuleSet object.
    #
    # +media_types+ can be a symbol or an array of symbols.
    def add_rule_set!(ruleset, media_types = :all)
      raise ArgumentError unless ruleset.kind_of?(CssParserMaster::RuleSet)

      media_types = [media_types] if media_types.kind_of?(Symbol)

      @rules << {:media_types => media_types, :rules => ruleset}
    end

    # Iterate through RuleSet objects.
    #
    # +media_types+ can be a symbol or an array of symbols.
    def each_rule_set(media_types = :all) # :yields: rule_set
      media_types = [:all] if media_types.nil?
      media_types = [media_types] if media_types.kind_of?(Symbol)

      @rules.each do |block|
        if media_types.include?(:all) or block[:media_types].any? { |mt| media_types.include?(mt) }
          yield block[:rules]
        end
      end
    end

    # go through all selector of the parser in order of specificity
    # parse declarations for each selector
    def selector_declarations(&block)
      each_selector_sorted(:all, :order => :asc) do |sel|        
        sel.declarations.each do |dec|
          yield sel, dec              
        end
      end             
    end

    # Iterate through CSS selectors.
    #
    # +media_types+ can be a symbol or an array of symbols.
    # See RuleSet#each_selector for +options+.
    def each_selector(media_types = :all, options = {}) # :yields: selectors, declarations, specificity
      each_rule_set(media_types) do |rule_set|
        #puts rule_set
        rule_set.each_selector(options) do |selector|
          # puts "selector: #{selector.inspect}"
          yield selector
        end
      end
    end

    # Iterate through CSS selectors.
    #
    # +media_types+ can be a symbol or an array of symbols.
    # See RuleSet#each_selector for +options+.
    def each_selector_sorted(media_types = :all, options = {}) # :yields: selectors, declarations, specificity
      order = options.delete(:order) || :desc
      sels = []
      each_selector(media_types, options) do |sel|
          sels << sel
      end
      sorted_sels = sels.sort_by(&:specificity).reverse
      sorted_sels.reverse! if order == :asc
      sorted_sels.each{|s| yield s}      
    end


    # Output all CSS rules as a single stylesheet.
    def to_s(media_types = :all)
      out = ''
      each_selector(media_types) do |selector|
        out << selector.to_s
      end
      out
    end

    # Merge declarations with the same selector.
    def compact! # :nodoc:
      compacted = []

      compacted
    end

    def parse_block_into_rule_sets!(block, options = {}) # :nodoc:
      options = {:media_types => :all}.merge(options)
      media_types = options[:media_types]

      in_declarations = false

      block_depth = 0

      # @charset is ignored for now
      in_charset = false
      in_string = false
      in_at_media_rule = false

      current_selectors = ''
      current_declarations = ''

      block.scan(/([\\]?[{}\s"]|(.[^\s"{}\\]*))/).each do |matches|
      #block.scan(/((.[^{}"\n\r\f\s]*)[\s]|(.[^{}"\n\r\f]*)\{|(.[^{}"\n\r\f]*)\}|(.[^{}"\n\r\f]*)\"|(.*)[\s]+)/).each do |matches|
        token = matches[0]
        #puts "TOKEN: #{token}" unless token =~ /^[\s]*$/
        if token =~ /\A"/ # found un-escaped double quote
          in_string = !in_string
        end       

        if in_declarations
          current_declarations += token

          if token =~ /\}/ and not in_string
            current_declarations.gsub!(/\}[\s]*$/, '')
            
            in_declarations = false

            unless current_declarations.strip.empty?
              #puts "SAVING #{current_selectors} -> #{current_declarations}"
              add_rule!(current_selectors, current_declarations, media_types)
            end

            current_selectors = ''
            current_declarations = ''
          end
        elsif token =~ /@media/i
          # found '@media', reset current media_types
          in_at_media_rule = true
          media_types = []
        elsif in_at_media_rule
          if token =~ /\{/
            block_depth = block_depth + 1
            in_at_media_rule = false
          else
            token.gsub!(/[,\s]*/, '')
            media_types << token.strip.downcase.to_sym unless token.empty?
          end
        elsif in_charset or token =~ /@charset/i
          # iterate until we are out of the charset declaration
          in_charset = (token =~ /;/ ? false : true)
        else
          if token =~ /\}/ and not in_string
            block_depth = block_depth - 1
          else
            if token =~ /\{/ and not in_string
              current_selectors.gsub!(/^[\s]*/, '')
              current_selectors.gsub!(/[\s]*$/, '')
              in_declarations = true
            else
              current_selectors += token
            end
          end
        end
      end
    end

    # Load a remote CSS file.
    def load_uri!(uri, base_uri = nil, media_types = :all)
      base_uri = uri if base_uri.nil?
      src, charset = read_remote_file(uri)

      add_block!(src, {:media_types => media_types, :base_uri => base_uri})
    end
    
    # Load a local CSS file.
    def load_file!(file_name, base_dir = nil, media_types = :all)
      file_name = File.expand_path(file_name, base_dir)
      return unless File.readable?(file_name)

      src = IO.read(file_name)
      base_dir = File.dirname(file_name)

      add_block!(src, {:media_types => media_types, :base_dir => base_dir})
    end
    
    

  protected
    # Strip comments and clean up blank lines from a block of CSS.
    #
    # Returns a string.
    def cleanup_block(block) # :nodoc:
      # Strip CSS comments
      block.gsub!(STRIP_CSS_COMMENTS_RX, '')

      # Strip HTML comments - they shouldn't really be in here but 
      # some people are just crazy...
      block.gsub!(STRIP_HTML_COMMENTS_RX, '')

      # Strip lines containing just whitespace
      block.gsub!(/^\s+$/, "")

      block
    end

    # Download a file into a string.
    #
    # Returns the file's data and character set in an array.
    #--
    # TODO: add option to fail silently or throw and exception on a 404
    #++
    def read_remote_file(uri) # :nodoc:
      raise CircularReferenceError, "can't load #{uri.to_s} more than once" if @loaded_uris.include?(uri.to_s)
      @loaded_uris << uri.to_s

      begin
      #fh = open(uri, 'rb')
        fh = open(uri, 'rb', 'User-Agent' => USER_AGENT, 'Accept-Encoding' => 'gzip')

        if fh.content_encoding.include?('gzip')
          remote_src = Zlib::GzipReader.new(fh).read
        else
          remote_src = fh.read
        end

        #puts "reading #{uri} (#{fh.charset})"

        ic = Iconv.new('UTF-8//IGNORE', fh.charset)
        src = ic.iconv(remote_src)

        fh.close
        return src, fh.charset
      rescue
        raise RemoteFileError if @options[:io_exceptions]
        return '', nil
      end
    end

  private
    # Save a folded declaration block to the internal cache.
    def save_folded_declaration(block_hash, folded_declaration) # :nodoc:
      @folded_declaration_cache[block_hash] = folded_declaration
    end

    # Retrieve a folded declaration block from the internal cache.
    def get_folded_declaration(block_hash) # :nodoc:
      return @folded_declaration_cache[block_hash] ||= nil
    end

    def reset! # :nodoc:
      @folded_declaration_cache = {}
      @css_source = ''
      @css_rules = []
      @css_warnings = []
    end
  end
end
