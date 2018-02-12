
require_relative 'tokensequence'

seq = ABNF::TokenSequence.new(DATA.read)

def flub str
  str = str.dup
  str = str.gsub('\\', '\\\\')
  str = str.gsub("\r", '\r')
  str = str.gsub("\n", '\n')
  str = str.gsub("\t", '\t')
  str = str.gsub(/[\x00-\x1F]/n) {|x| "\\x#{'%02X' % x.ord}" }
  str
end

=begin
seq.each do |tok|
  if tok.value.is_a? String
    val = "[\e[36m#{flub tok.value}\e[0m]"
  else
    val = tok.value.inspect
  end
  src = "[\e[90m#{flub tok.src}\e[0m]"
  printf "  %-21s  %s  %s\n", tok.type.inspect, val, src
end
=end

def represent tok
  case tok.type
  when :name
    "\e[36m#{tok.value}\e[0m"
  when :EQ, :EQ_ALT
    tok.value
  when :prose
    "<#{tok.value}>"
  when :sstring
    "%s\e[32m\"#{tok.value}\"\e[0m"
  when :istring
    "\e[32m\"#{tok.value}\"\e[0m"
  when :terminal
    '%x' + tok.value.map{|x| "\e[33m%02X\e[0m" % x }.join('.')
  when :range
    '%x' + tok.value.map{|x| "\e[33m%02X\e[0m" % x }.join('-')
  else
    "\e[90m<#{tok.type}>\e[0m#{tok.value}"
  end
end

def canonize node
  return "\e[33m" + node.inspect + "\e[0m" unless node.respond_to? :first
  case node.first
  when :rule
    _, rulename, definedas, definition = node
    "#{represent rulename} #{represent definedas} #{canonize definition}"
  when :alternation
    _, cats = node
    a = z = ''
    a + cats.map{|c| canonize c }.join(' / ') + z
  when :concatenation
    _, reps = node
    reps.map{|c| canonize c }.join(' ')
  when :repetition
    _, inner, min, max = node
    a = z = ''
    if inner.first != :primitive
      a = '( '
      z = ' )'
    end
    if min == 0 && max == 1
      '[ ' + canonize(inner) + ' ]'
    elsif min == max
      if min == 1
        a + canonize(inner) + z
      else
        min.to_s + a + canonize(inner) + z
      end
    else
      (min == 0 ? '' : min.to_s) + '*' + (max == :inf ? '' : max.to_s) + a + canonize(inner) + z
    end
  when :primitive
    _, tok = node
    represent tok
  else
    "??\e[31m" + node.inspect + "\e[0m"
  end
end

require_relative 'ast'
ast = ABNF::AST.new seq
ast.each {|node| puts canonize(node) }

__END__
rulelist       =  1*( rule / (*c-wsp c-nl) )

rule           =  rulename defined-as elements c-nl
                       ; continues if next line starts
                       ;  with white space

rulename       =  ALPHA *(ALPHA / DIGIT / "-")

defined-as     =  *c-wsp ("=" / "=/") *c-wsp
                       ; basic rules definition and
                       ;  incremental alternatives

elements       =  alternation *c-wsp

c-wsp          =  WSP / (c-nl WSP)

c-nl           =  comment / CRLF
                       ; comment or newline

comment        =  ";" *(WSP / VCHAR) CRLF

alternation    =  concatenation
                  *(*c-wsp "/" *c-wsp concatenation)

concatenation  =  repetition *(1*c-wsp repetition)

repetition     =  [repeat] element

repeat         =  1*DIGIT / (*DIGIT "*" *DIGIT)

element        =  rulename / group / option /
                  char-val / num-val / prose-val

group          =  "(" *c-wsp alternation *c-wsp ")"

option         =  "[" *c-wsp alternation *c-wsp "]"

;char-val       =  DQUOTE *(%x20-21 / %x23-7E) DQUOTE
;                       ; quoted string of SP and VCHAR
;                       ;  without DQUOTE

char-val       =  case-insensitive-string /
                  case-sensitive-string

case-insensitive-string =
                  [ "%i" ] quoted-string

case-sensitive-string =
                  "%s" quoted-string

quoted-string  =  DQUOTE *(%x20-21 / %x23-7E) DQUOTE
                       ; quoted string of SP and VCHAR
                       ;  without DQUOTE

num-val        =  "%" (bin-val / dec-val / hex-val)

bin-val        =  "b" 1*BIT
                  [ 1*("." 1*BIT) / ("-" 1*BIT) ]
                       ; series of concatenated bit values
                       ;  or single ONEOF range

dec-val        =  "d" 1*DIGIT
                  [ 1*("." 1*DIGIT) / ("-" 1*DIGIT) ]

hex-val        =  "x" 1*HEXDIG
                  [ 1*("." 1*HEXDIG) / ("-" 1*HEXDIG) ]

prose-val      =  "<" *(%x20-3D / %x3F-7E) ">"
                       ; bracketed string of SP and VCHAR
                       ;  without angles
                       ; prose description, to be used as
                       ;  last resort
