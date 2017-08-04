require 'parser/current'
require 'unparser'
require 'find'

PROJECT_DIR = "~/Developer/sms-manager-develop"

def gather_project(dir = PROJECT_DIR)
  result = {files: []}
  
  Find.find(File.expand_path(dir)) do |name|
    if !FileTest.directory?(name)
      if File.extname(name) == ".rb" || File.extname(name) == ".rabl" || File.extname(name) == ".rake"
        source = File.read(name)
        result[:files] << {name: name, source: source}
      end
    end
  end

  result
end

def gather_ruby_source(source)
end
