begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "css_parser_master"
    gem.summary = %Q{Parse CSS files, access and operate on a model of the CSS rules}
    gem.description = %Q{Parse a CSS file and access/operate on rulesets, selectors, declarations etc. Includes specificity calculated according to W3C spec.}
    gem.email = "kmandrup@gmail.com"
    gem.homepage = "http://github.com/kristianmandrup/load-me"
    gem.authors = ["Kristian Mandrup", "Alex Dunae"]
    # gem.add_development_dependency "rspec", ">= 2.0.0"
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
    
    # add more gem options here    
  end   
  Jeweler::GemcutterTasks.new  
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end
