#
# RFC 5234 + RFC 7405
#

class ABNF

  ALPHA  = /(?x: [\x41-\x5A] | [\x61-\x7A] )/
  BIT    = /(?x: 0 | 1 )/
  CHAR   = /(?x: [\x01-\x7F] )/
  CR     = /(?x: \x0D )/
  CTL    = /(?x: [\x00-\x1F] | \x7F )/
  DIGIT  = /(?x: [0-9] )/
  DQUOTE = /(?x: ["] )/
  HTAB   = /(?x: \x09 )/
  LF     = /(?x: \x0A )/
  OCTET  = /(?x: [\x00-\xFF] )/n
  SP     = /(?x: \x20 )/
  VCHAR  = /(?x: [\x21-\x7E] )/

  HEXDIG = /(?x: #{DIGIT} | (?i:A|B|C|D|E|F) )/
  CRLF   = /(?x: #{CR}#{LF} )/
  WSP    = /(?x: #{SP} | #{HTAB} )/

  LWSP   = /(?x: (?: #{WSP} | #{CRLF}#{WSP} )* )/

  def initialize src
    # input (for posterity)
    @src = -"#{src}"

    # tokenise
    @tokens = []
    tmp = @src.dup
    until tmp.empty?
      if tmp.sub! %r(\A \r?\n #{WSP}+ )x, ''
        @tokens << [:continuation, $&]

      elsif tmp.sub! %r(\A \r?\n )x, ''
        @tokens << [:endline, $&]

      elsif tmp.sub! %r(\A [\x20\x09]+ )x, ''
        @tokens << [:whitespace, $&]

      elsif tmp.sub! %r(\A ; (?: #{WSP} | #{VCHAR} )* (?= \r?\n ) )x, ''
        @tokens << [:comment, $&]

      elsif tmp.sub! %r(\A %b #{BIT}+-#{BIT}+ )xi, ''
        @tokens << [:range_binary, $&, _parse_range($&, 2)]

      elsif tmp.sub! %r(\A %d #{DIGIT}+-#{DIGIT}+ )x, ''
        @tokens << [:range_decimal, $&, _parse_range($&, 10)]

      elsif tmp.sub! %r(\A %x #{HEXDIG}+-#{HEXDIG}+ )x, ''
        @tokens << [:range_hexadecimal, $&, _parse_range($&, 16)]

      elsif tmp.sub! %r(\A %b #{BIT}+(\.#{BIT}+)* )xi, ''
        @tokens << [:terminal_binary, $&, _parse_terminal($&, 2)]

      elsif tmp.sub! %r(\A %d #{DIGIT}+(\.#{DIGIT}+)* )x, ''
        @tokens << [:terminal_decimal, $&, _parse_terminal($&, 10)]

      elsif tmp.sub! %r(\A %x #{HEXDIG}+(\.#{HEXDIG}+)* )x, ''
        @tokens << [:terminal_hexadecimal, $&, _parse_terminal($&, 16)]

      elsif tmp.sub! %r(\A (?:%i)? " ([\x20-\x21\x23-\x7E]*) " )x, ''
        @tokens << [:terminal_string, $&, $1]

      # RFC 7405:
      elsif tmp.sub! %r(\A %s " ([\x20-\x21\x23-\x7E]*) " )x, ''
        @tokens << [:terminal_string_case, $&, $1]

      elsif tmp.sub! %r(\A < ([\x20-\x3D\x3F-\x7E]*) > )x, ''
        @tokens << [:prose, $&, $1]

      elsif tmp.sub! %r(\A #{DIGIT}* \* #{DIGIT}* )x, ''
        @tokens << [:repetition, $&, _parse_repetition($&)]

      elsif tmp.sub! %r(\A / )x, ''
        @tokens << [:ALT, $&]

      elsif tmp.sub! %r(\A =/ )x, ''
        @tokens << [:EQ_ALT, $&]

      elsif tmp.sub! %r(\A = )x, ''
        @tokens << [:EQ, $&]

      elsif tmp.sub! %r(\A \( )x, ''
        @tokens << [:LPAREN, $&]

      elsif tmp.sub! %r(\A \) )x, ''
        @tokens << [:RPAREN, $&]

      elsif tmp.sub! %r(\A \[ )x, ''
        @tokens << [:LBRACKET, $&]

      elsif tmp.sub! %r(\A \] )x, ''
        @tokens << [:RBRACKET, $&]

      elsif tmp.sub! %r(\A [A-Z] [A-Z0-9-]* )xi, ''
        @tokens << [:name, $&]

      else
        raise "unexpected token at #{tmp[0..20].inspect}"
      end
    end

    # TODO: now compile tokens into (tree?)
  end

  def _parse_range tok, base
    tok.sub! /^%./, ''
    tok.split('-').map {|x| x.to_i base }
  end

  def _parse_terminal tok, base
    tok.sub! /^%./, ''
    tok.split('.').map {|chunk| chunk.to_i base }
  end

  def _parse_repetition tok
    min, max = tok.split('*', -1)
    min = min.empty? ? 0    : min.to_i
    max = max.empty? ? :inf : max.to_i
    [min, max]
  end

  def canonical
    @tokens.map do |tok|
      type, val, extra = tok
      case type
      when :continuation
        "\n  "
      when :endline
        "\n"
      when :whitespace
        ' '
      when :comment
        val
      when :range_binary
        "%b#{extra[0].to_s 2}-#{extra[1].to_s 2}"
      when :range_decimal
        "%d#{extra[0].to_s 10}-#{extra[1].to_s 10}"
      when :range_hexadecimal
        "%x#{extra[0].to_s 16}-#{extra[1].to_s 16}"
      when :terminal_binary
        "%b#{extra.map{|x| x.to_s 2}.join '.'}"
      when :terminal_decimal
        "%d#{extra.map{|x| x.to_s 10}.join '.'}"
      when :terminal_hexadecimal
        "%x#{extra.map{|x| x.to_s 16}.join '.'}"
      when :terminal_string
        "\"#{extra}\""
      when :terminal_string_case
        val
      when :prose
        val
      when :repetition
        min, max = extra
        "#{min == 0 ? '' : min}*#{max == :inf ? '' : max}"
      when :ALT, :EQ_ALT, :EQ, :LPAREN, :RPAREN, :LBRACKET, :RBRACKET
        val
      when :name
        val
      end
    end.join
  end
end

# vim: set ts=2 sts=2 sw=2 expandtab
