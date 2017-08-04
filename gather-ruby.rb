require 'parser/current'
require 'unparser'
require 'find'
require 'pry'

PROJECT_DIR = "~/Developer/sms-manager-develop"

def gather_project(dir = PROJECT_DIR)
  result = {files: []}

  Find.find(File.expand_path(dir)) do |name|
    if !FileTest.directory?(name)
      if File.extname(name) == ".rb" || File.extname(name) == ".rabl" || File.extname(name) == ".rake"
        source = File.read(name)
        result[:files] << {name: name,
                           source: source,
                           top: gather_ruby_source(source)}
      end
    end
  end

  result
end

def gather_ruby_source(source)
  binding.pry
  result = {}
  ast, comments = Parser::CurrentRuby.parse_with_comments(source)
  result[:ast] = ast
  result[:comments] = comments
  result[:children] = []
  if ast.type == :begin
    elements = ast.children
  else
    elements = [ast]
  end
  elements.each do |element|
    result[:children] << gather_ruby_construct(element)
  end

  result
end

def gather_ruby_construct(node)
  nil
end
