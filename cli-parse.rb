#
# Build an AST.
#

require_relative 'tokensequence'
require_relative 'ast'

rule = nil
dump = false

srcfiles = []
until ARGV.empty?
  if ARGV.first == '--abnf'
    ARGV.shift
    srcfiles << ARGV.shift
  elsif ARGV.first =~ /\A--abnf=(.+)\z/
    srcfiles << $1
    ARGV.shift
  elsif ARGV.first == '--rule'
    ARGV.shift
    rule = ARGV.shift
  elsif ARGV.first =~ /\A--rule=(.+)\z/
    rule = $1
    ARGV.shift
  elsif ARGV.first == '--dump'
    dump = true
    ARGV.shift
  else
    break
  end
end

if rule.nil? || rule.empty?
  STDERR.puts "Must define a rule name"
  exit -1
end

src = +''.b
srcfiles.each do |fn|
  begin
    src << File.open(fn, 'r') {|fh| fh.read }
  rescue => ex
    STDERR.puts "Unable to read #{fn}: #{ex}"
    exit -2
  end
end

text = ARGF.read

begin
  seq = ABNF::TokenSequence.new(src)
rescue => ex
  STDERR.puts "Error parsing ABNF: #{ex}"
  exit -3
end

begin
  ast = ABNF::AST.new seq
rescue => ex
  STDERR.puts "Error interpreting ABNF: #{ex}"
  exit -3
end

if dump
  puts '==='
  ast.each.sort_by{|node| node.rulename.downcase }.each{|node| puts node }
  puts '==='
end

begin
  if ast.match? text, rule
    puts "match"
  else
    puts "NO MATCH"
  end
rescue => ex
  STDERR.puts "Error matching text: #{ex}"
  exit -4
end

