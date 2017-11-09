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
        next if name == "/Users/gstanle2/.rbenv/versions/2.5.0-dev/lib/ruby/2.5.0/rexml/source.rb"
        next if name == "/Users/gstanle2/.rbenv/versions/2.5.0-dev/lib/ruby/gems/2.5.0/gems/Ron-0.1.2/lib/ron/column_order.rb"
        puts name
        source = File.read(name)
        begin
          result[:files] << {name: name,
                             source: source,
                             top: gather_ruby_file(source)}
        rescue => error
          puts error
          exit if /gather-ruby/ =~ error.to_s
        end
      end
    end
  end

  result
end

def gather_ruby_file(source)
  result = {}
  source.gsub!(/__FILE__/, "STRIPTHIS__FILE__")
  source.gsub!(/__LINE__/, "STRIPTHIS__LINE__")
  source.gsub!(/__ENCODING__/, "STRIPTHIS__ENCODING__")
  ast, comments = Parser::CurrentRuby.parse_with_comments(source)
  # result[:ast] = ast
  result[:comments] = []
  comments.each do |comment|
  binding.pry
    result[:comments] << {
      text: comment.text,
      begin: comment.loc.expression.begin_pos,
      end: comment.loc.expression.end_pos
    }
  end
  result[:children] = []
  if ast.nil?
    elements = []
  elsif ast.type == :begin
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
  result = {}
  unless node
    binding.pry
    return result
  end
  case node.type
  when :class
    result[:type] = "class"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:name] = gather_ruby_construct(node.children[0])
    result[:parent] = gather_ruby_construct(node.children[1]) unless node.children[1].nil?
    unless node.children[2].nil?
      result[:children] = []
      node.children[2..-1].each do |child|
        result[:children] << gather_ruby_construct(child)
      end
    end
  when :def
    result[:type] = "def"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:name] = node.loc.name.source
    result[:arguments] = gather_ruby_construct(node.children[1])
    result[:body] = gather_ruby_construct(node.children[2]) unless node.children[2].nil?
  when :module
    result[:type] = "module"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:name] = node.loc.name.source
    result[:children] = []
    node.children[1..-1].each do |child|
      result[:children] << gather_ruby_construct(child) unless child.nil?
    end
  when :begin
    result[:type] = "begin"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:children] = []
    node.children.each do |child|
      result[:children] << gather_ruby_construct(child)
    end
  when :send
    result[:type] = "send"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:receiver] = gather_ruby_construct(node.children[0]) unless node.children[0].nil?
    result[:name] = node.children[1].to_s
    result[:arguments] = []
    node.children[2..-1].each do |child|
      result[:arguments] << gather_ruby_construct(child)
    end
  when :const
    result[:type] = "const"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:prefix] = gather_ruby_construct(node.children[0]) unless node.children[0].nil?
    result[:name] = node.children[1].to_s
    result[:source].sub!("STRIPTHIS", "")
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:name].sub!("STRIPTHIS", "")
  when :sym
    result[:type] = "symbol"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:name] = node.children[0].to_s
  when :hash
    result[:type] = "hash"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:pairs] = []
    node.children.each do |child|
      result[:pairs] << gather_ruby_construct(child)
    end
  when :pair
    result[:type] = "pair"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:key] = gather_ruby_construct(node.children[0])
    result[:value] = gather_ruby_construct(node.children[1])
  when :true
    result[:type] = "true"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
  when :ivasgn
    result[:type] = "ivar-assign"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:variable] = node.children[0].to_s
    result[:value] = gather_ruby_construct(node.children[1]) unless node.children[1].nil?
  when :lvar
    result[:type] = "local-var"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:variable] = node.children[0].to_s
  when :ivar
    result[:type] = "instance-var"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:variable] = node.children[0].to_s
  when :args
    result[:type] = "args"
    result[:source] = node.loc.expression.source unless node.loc.expression.nil?
    result[:begin] = node.loc.expression.begin_pos unless node.loc.expression.nil?
    result[:end] = node.loc.expression.end_pos unless node.loc.expression.nil?
    result[:args] = []
    node.children.each do |child|
      result[:args] << gather_ruby_construct(child)
    end
  when :arg
    result[:type] = "argument"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:variable] = node.children[0].to_s
  when :array
    result[:type] = "array"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:elements] = []
    node.children.each do |child|
      result[:elements] << gather_ruby_construct(child)
    end
  when :str
    result[:type] = "string"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:value] = node.children[0]
  when :lvasgn
    result[:type] = "lvar-assign"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:variable] = node.children[0].to_s
    result[:value] = gather_ruby_construct(node.children[1]) unless node.children[1].nil?
  when :block
    result[:type] = "block"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:call] = gather_ruby_construct(node.children[0])
    result[:arguments] = gather_ruby_construct(node.children[1])
    result[:body] = gather_ruby_construct(node.children[2]) unless node.children[2].nil?
  when :dstr
    result[:type] = "dyn-string"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:parts] = []
    node.children.each do |child|
      result[:parts] << gather_ruby_construct(child)
    end
  when :or_asgn
    result[:type] = "or-assign"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:variable] = gather_ruby_construct(node.children[0])
    result[:value] = gather_ruby_construct(node.children[1]) unless node.children[1].nil?
  when :casgn
    result[:type] = "const-assign"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:prefix] = gather_ruby_construct(node.children[0]) unless node.children[0].nil?
    result[:name] = node.children[1].to_s
    result[:value] = gather_ruby_construct(node.children[2]) unless node.children[2].nil?
  when :defs
    result[:type] = "def-self"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:name] = node.loc.name.source
    result[:arguments] = gather_ruby_construct(node.children[2])
    result[:body] = gather_ruby_construct(node.children[3]) unless node.children[3].nil?
  when :if
    result[:type] = "if"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:condition] = gather_ruby_construct(node.children[0])
    result[:true_case] = gather_ruby_construct(node.children[1]) unless node.children[1].nil?
    result[:false_case] = gather_ruby_construct(node.children[2]) unless node.children[2].nil?
  when :return
    result[:type] = "return"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:value] = gather_ruby_construct(node.children[0]) unless node.children[0].nil?
  when :nil
    result[:type] = "nil"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
  when :optarg
    result[:type] = "optional-arg"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:name] = node.children[0].to_s
    result[:default] = gather_ruby_construct(node.children[1])
  when :and
    result[:type] = "and"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:left] = gather_ruby_construct(node.children[0])
    result[:right] = gather_ruby_construct(node.children[1])
  when :false
    result[:type] = "false"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
  when :cvasgn
    result[:type] = "class-var-assign"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:variable] = node.children[0].to_s
    result[:value] = gather_ruby_construct(node.children[1]) unless node.children[1].nil?
  when :cvar
    result[:type] = "class-var"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:variable] = node.children[0].to_s
  when :rescue
    result[:type] = "rescue-block"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:wrapped_block] = gather_ruby_construct(node.children[0]) unless node.children[0].nil?
    result[:rescue_blocks] = []
    node.children[1..-2].each do |child|
    binding.pry if child.nil?
      result[:rescue_blocks] << gather_ruby_construct(child)
    end
    result[:else_block] = gather_ruby_construct(node.children[-1]) unless node.children[-1].nil?
  when :resbody
    result[:type] = "rescue-body"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:exceptions] = gather_ruby_construct(node.children[0]) unless node.children[0].nil?
    result[:exception_var] = gather_ruby_construct(node.children[1]) unless node.children[1].nil?
    result[:body] = gather_ruby_construct(node.children[2]) unless node.children[2].nil?
  when :int
    result[:type] = "integer"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:value] = node.children[0].to_s
  when :restarg
    result[:type] = "rest-arg"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:name] = node.children[0].to_s
  when :regexp
    result[:type] = "regexp"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:expression] = gather_ruby_construct(node.children[0])
    result[:options] = gather_ruby_construct(node.children[1]) unless node.children[1].nil?
  when :regopt
    result[:type] = "regopt"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:options] = []
    node.children.each do |child|
      result[:options] << child.to_s
    end
  when :block_pass
    result[:type] = "block-pass"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:name] = gather_ruby_construct(node.children[0])
    raise "gather-ruby: there are multiple block-pass entries" if node.children.size > 1
  when :or
    result[:type] = "or"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:left] = gather_ruby_construct(node.children[0])
    result[:right] = gather_ruby_construct(node.children[1])
  when :float
    result[:type] = "integer"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:value] = node.children[0].to_s
  when :masgn
    result[:type] = "multi-assign"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:variables] = gather_ruby_construct(node.children[0])
    result[:values] = gather_ruby_construct(node.children[1]) unless node.children[1].nil?
  when :mlhs
    result[:type] = "multi-assign-lhs"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:variables] = []
    node.children.each do |child|
      result[:variables] << gather_ruby_construct(child)
    end
  when :irange
    result[:type] = "inclusive-range"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:start] = gather_ruby_construct(node.children[0])
    result[:end] = gather_ruby_construct(node.children[1])
  when :self
    result[:type] = "self"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
  when :splat
    result[:type] = "splat"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:variable] = gather_ruby_construct(node.children[0]) unless node.children[0].nil?
  when :dsym
    result[:type] = "dyn-symbol"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:parts] = []
    node.children.each do |child|
      result[:parts] << gather_ruby_construct(child)
    end
  when :kwbegin
    result[:type] = "keyword-begin"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:children] = []
    node.children.each do |child|
      result[:children] << gather_ruby_construct(child)
    end
  when :super
    result[:type] = "super"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:arguments] = []
    node.children.each do |child|
      result[:arguments] << gather_ruby_construct(child)
    end
  when :ensure
    result[:type] = "ensure-block"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:wrapped_body] = gather_ruby_construct(node.children[0]) unless node.children[0].nil?
    result[:rescue_body] = gather_ruby_construct(node.children[1]) unless node.children[1].nil?
    raise "gather-ruby: there is a 3rd ensure node" if node.children[2]
  when :case
    result[:type] = "case"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:compare_value] = gather_ruby_construct(node.children[0]) unless node.children[0].nil?
    result[:when_blocks] = []
    node.children[1..-2].each do |child|
      result[:when_blocks] << gather_ruby_construct(child)
    end
    result[:default] = gather_ruby_construct(node.children[-1]) unless node.children[-1].nil?
  when :when
    result[:type] = "when"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:comparison] = gather_ruby_construct(node.children[0])
    result[:value] = gather_ruby_construct(node.children[1]) unless node.children[1].nil?
  when :sclass
    result[:type] = "self-class"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:target] = gather_ruby_construct(node.children[0])
    result[:body] = gather_ruby_construct(node.children[1]) unless node.children[1].nil?
  when :alias
    result[:type] = "alias"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:new] = gather_ruby_construct(node.children[0])
    result[:old] = gather_ruby_construct(node.children[1])
  when :next
    result[:type] = "next"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:argument] = gather_ruby_construct(node.children[0]) unless node.children[0].nil?
  when :cbase
    result[:type] = "top-level-const"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    raise "gather-ruby: there are arguments for cbase" if node.children.size > 0
  when :kwoptarg
    result[:type] = "keyword-optional-arg"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:name] = node.children[0].to_s
    result[:default] = gather_ruby_construct(node.children[1])
  when :op_asgn
    result[:type] = "operator-assign"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:variable] = gather_ruby_construct(node.children[0])
    result[:operator] = node.children[1].to_s
    result[:value] = gather_ruby_construct(node.children[2])
  when :defined?
    result[:type] = "defined?"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:object] = gather_ruby_construct(node.children[0])
  when :xstr
    result[:type] = "exec-string"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:parts] = []
    node.children.each do |child|
      result[:parts] << gather_ruby_construct(child)
    end
  when :yield
    result[:type] = "yield"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:arguments] = []
    node.children.each do |child|
      result[:arguments] << gather_ruby_construct(child)
    end
  when :retry
    result[:type] = "retry"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    raise "gather-ruby: there are arguments for retry" if node.children.size > 0
  when :blockarg
    result[:type] = "block-argument"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:name] = node.children[0].to_s
  when :gvasgn
    result[:type] = "global-var-assign"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:variable] = node.children[0].to_s
    result[:value] = gather_ruby_construct(node.children[1]) unless node.children[1].nil?
  when :gvar
    result[:type] = "global-variable"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:name] = node.children[0].to_s
  when :back_ref
    result[:type] = "back-reference"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:name] = node.children[0].to_s
  when :erange
    result[:type] = "exclusive-range"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:start] = gather_ruby_construct(node.children[0])
    result[:end] = gather_ruby_construct(node.children[1])
  when :break
    result[:type] = "break"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:argument] = gather_ruby_construct(node.children[0]) unless node.children[0].nil?
  when :nth_ref
    result[:type] = "nth-reference"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:name] = node.children[0].to_s
  when :until
    result[:type] = "until"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:condition] = gather_ruby_construct(node.children[0])
    result[:block] = gather_ruby_construct(node.children[1]) unless node.children[1].nil?
    raise "gather-ruby: there are more children for until" if node.children.size > 2
  when :for
    result[:type] = "for"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:index] = gather_ruby_construct(node.children[0])
    result[:range] = gather_ruby_construct(node.children[1])
    result[:block] = gather_ruby_construct(node.children[2])
    raise "gather-ruby: there are more children for for" if node.children.size > 3
  when :while
    result[:type] = "while"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:condition] = gather_ruby_construct(node.children[0])
    result[:block] = gather_ruby_construct(node.children[1]) unless node.children[1].nil?
    raise "gather-ruby: there are more children for while" if node.children.size > 2
  when :while_post
    result[:type] = "while-post"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:condition] = gather_ruby_construct(node.children[0])
    result[:block] = gather_ruby_construct(node.children[1])
    raise "gather-ruby: there are more children for while-post" if node.children.size > 2
  when :match_with_lvasgn
    result[:type] = "match-regexp-expression"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:regexp] = gather_ruby_construct(node.children[0])
    result[:expression] = gather_ruby_construct(node.children[1])
    raise "gather-ruby: there are more children for match-local" if node.children.size > 2
  when :zsuper
    result[:type] = "super-no-arguments"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    raise "gather-ruby: zsuper has arguments" unless node.children.empty?
  when :and_asgn
    result[:type] = "and-assign"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:variable] = gather_ruby_construct(node.children[0])
    result[:value] = gather_ruby_construct(node.children[1]) unless node.children[1].nil?
  when :undef
    result[:type] = "undef"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:name] = gather_ruby_construct(node.children[0])
  when :csend
    result[:type] = "conditional-send"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:receiver] = gather_ruby_construct(node.children[0]) unless node.children[0].nil?
    result[:name] = node.children[1].to_s
    result[:arguments] = []
    node.children[2..-1].each do |child|
      result[:arguments] << gather_ruby_construct(child)
    end
  when :redo
    result[:type] = "redo"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    raise "gather-ruby: there are arguments for redo" if node.children.size > 0
  when :kwarg
    result[:type] = "keyword-argument"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:name] = node.children[0].to_s
  when :postexe
    result[:type] = "post-execute"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:block] = gather_ruby_construct(node.children[0])
  when :until_post
    result[:type] = "until-post"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:condition] = gather_ruby_construct(node.children[0])
    result[:block] = gather_ruby_construct(node.children[1]) unless node.children[1].nil?
    raise "gather-ruby: there are more children for until-post" if node.children.size > 2
  when :kwrestarg
    result[:type] = "keyword-rest-argument"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:name] = node.children[0].to_s
  when :kwsplat
    result[:type] = "keyword-splat"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:variable] = gather_ruby_construct(node.children[0]) unless node.children[0].nil?
  when :rational
    result[:type] = "rational"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:value] = node.loc.expression.source
  when :preexe
    result[:type] = "pre-execute"
    result[:source] = node.loc.expression.source
    result[:begin] = node.loc.expression.begin_pos
    result[:end] = node.loc.expression.end_pos
    result[:block] = gather_ruby_construct(node.children[0])
  when :iflipflop
    raise "gather-ruby: not implemented: #{node.type}"
  when :eflipflop
    raise "gather-ruby: not implemented: #{node.type}"
  when :complex
    raise "gather-ruby: not implemented: #{node.type}"
  when :shadowarg
    raise "gather-ruby: not implemented: #{node.type}"
  when :arg_expr
    raise "gather-ruby: not implemented: #{node.type}"
  when :match_current_line
    raise "gather-ruby: not implemented: #{node.type}"
  else
    raise "gather-ruby: not implemented: #{node.type}"
  end

  result
end

def gather_info(files_tree)
  binding.pry
  info = {
    classes: [],
    modules: []
  }
  
  files_tree[:files].each do |file_node|
    name = file_node[:name]
    modules = gather_info_modules(info, file_node, name)
    classes = gather_info_classes(info, file_node, name)
  end
end

def gather_info_modules(coll, node, name)
end

def gather_info_classes(coll, node, name)
end
