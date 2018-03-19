#
# Build an AST.
#

require_relative 'tokensequence'
require_relative 'ast'

if ARGV.length > 0
  io = ARGF
else
  io = DATA
end

src = io.read

seq = ABNF::TokenSequence.new(src)
ast = ABNF::AST.new seq

ast.each.sort_by{|node| node.rulename.downcase }.each{|node| puts node }
puts ''

missing = ast.undefined_names
unless missing.empty?
  puts "The following rules appear to be undefined:"
  missing.each{|name| puts "  \e[31m#{name}\e[0m" }
  puts ''
end

toplevel = ast.toplevel_names
unless toplevel.empty?
  puts "The following rules are defined but unused:"
  toplevel.each{|name| puts "  \e[32m#{name}\e[0m" }
  puts ''
end
