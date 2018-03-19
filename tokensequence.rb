
module ABNF
  class Token
    def initialize type, src, value=nil
      @type = type
      @src = src
      @value = value || src
    end
    attr_reader :type, :value, :src
    def inspect
      "\#<#{self.class.name}:#{@type} value=#{@value.inspect} src=#{@src.inspect}>"
    end

    # FIXME: ANSI/VT escape sequences are not very portable
    def to_s
      case @type
      when :name
        "\e[36m#{@value}\e[0m"
      when :EQ, :EQ_ALT
        @value
      when :prose
        "\e[90m<#{@value}>\e[0m"
      when :sstring
        "%s\e[32m\"#{@value}\"\e[0m"
      when :istring
        "\e[32m\"#{@value}\"\e[0m"
      when :terminal
        '%x' + @value.map{|x| "\e[33m%02X\e[0m" % x }.join('.')
      when :range
        '%x' + @value.map{|x| "\e[33m%02X\e[0m" % x }.join('-')
      else
        "\e[90m<#{@type}>\e[0m#{@value}"
      end
    end
  end

  ##
  # A sequence of Tokens, built from src.
  #
  # RFC 5234 + RFC 7405
  #
  class TokenSequence
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

    include Enumerable

    ##
    # Create a new TokenSequence.
    #
    # @param src [String] ABNF source
    # @param indent [mixed] - a non-negative integer, or `:auto`
    #
    def initialize src, indent=:auto
      @src = -"#{src}"
      @tokens = nil
      _tokenize indent
    end

    ##
    # Do a thing once for each token in the sequence.
    # Returns an enum if no block is given.
    #
    def each &block
      @tokens.each &block
    end

    ##
    # Returns this TokenSequence as an Array of Token objects.
    #
    def tokens
      @tokens.dup
    end
    alias to_a tokens

    def _tokenize indent
      if indent == :auto
        # read the indentation from the first (non-blank) line
        if (m = %r(\A (?:\r?\n)* ([\x20]+) )x.match(@src))
          i = m[1].length
          indent = %r(\A [\x20]{#{i}} )x
        else
          indent = nil
        end
      elsif indent
        indent = indent.to_i
        if indent > 0
          indent = %r(\A [\x20]{#{i}} )x
        else
          indent = nil
        end
      end

      @tokens = []
      tmp = @src.dup
      _outdent(tmp, indent) if indent

      until tmp.empty?
        if tmp.sub! %r(\A \r?\n #{WSP}+ )x, ''
          @tokens << Token.new(:continuation, $&.freeze)
          _outdent(tmp, indent) if indent

        elsif tmp.sub! %r(\A \r?\n )x, ''
          @tokens << Token.new(:endline, $&.freeze)

        elsif tmp.sub! %r(\A [\x20\x09]+ )x, ''
          @tokens << Token.new(:whitespace, $&.freeze)

        elsif tmp.sub! %r(\A ; ((?: #{WSP} | #{VCHAR} )*) (?= \r?\n | $ ) )x, ''
          @tokens << Token.new(:comment, $&.freeze, $1.freeze)

        elsif tmp.sub! %r(\A %b #{BIT}+-#{BIT}+ )xi, ''
          @tokens << Token.new(:range, $&.freeze, _parse_range($&, 2))

        elsif tmp.sub! %r(\A %d #{DIGIT}+-#{DIGIT}+ )x, ''
          @tokens << Token.new(:range, $&.freeze, _parse_range($&, 10))

        elsif tmp.sub! %r(\A %x #{HEXDIG}+-#{HEXDIG}+ )x, ''
          @tokens << Token.new(:range, $&.freeze, _parse_range($&, 16))

        elsif tmp.sub! %r(\A %b #{BIT}+(\.#{BIT}+)* )xi, ''
          @tokens << Token.new(:terminal, $&.freeze, _parse_terminal($&, 2))

        elsif tmp.sub! %r(\A %d #{DIGIT}+(\.#{DIGIT}+)* )x, ''
          @tokens << Token.new(:terminal, $&.freeze, _parse_terminal($&, 10))

        elsif tmp.sub! %r(\A %x #{HEXDIG}+(\.#{HEXDIG}+)* )x, ''
          @tokens << Token.new(:terminal, $&.freeze, _parse_terminal($&, 16))

        elsif tmp.sub! %r(\A (?:%i)? " ([\x20-\x21\x23-\x7E]*) " )x, ''
          @tokens << Token.new(:istring, $&.freeze, $1.freeze)

        # RFC 7405:
        elsif tmp.sub! %r(\A %s " ([\x20-\x21\x23-\x7E]*) " )x, ''
          @tokens << Token.new(:sstring, $&.freeze, $1.freeze)

        elsif tmp.sub! %r(\A < ([\x20-\x3D\x3F-\x7E]*) > )x, ''
          @tokens << Token.new(:prose, $&.freeze, $1.freeze)

        elsif tmp.sub! %r(\A #{DIGIT}* \* #{DIGIT}* )x, ''
          @tokens << Token.new(:repetition, $&.freeze, _parse_repetition($&))

        # RFC 7230, Section 7
        elsif tmp.sub! %r(\A #{DIGIT}* \# #{DIGIT}* )x, ''
          @tokens << Token.new(:list, $&.freeze, _parse_repetition($&, '#'))

        elsif tmp.sub! %r(\A #{DIGIT}+ )x, ''
          @tokens << Token.new(:repetition, $&.freeze, _parse_repetition($&))

        elsif tmp.sub! %r(\A / )x, ''
          @tokens << Token.new(:ALT, $&.freeze)

        elsif tmp.sub! %r(\A =/ )x, ''
          @tokens << Token.new(:EQ_ALT, $&.freeze)

        elsif tmp.sub! %r(\A = )x, ''
          @tokens << Token.new(:EQ, $&.freeze)

        elsif tmp.sub! %r(\A \( )x, ''
          @tokens << Token.new(:LPAREN, $&.freeze)

        elsif tmp.sub! %r(\A \) )x, ''
          @tokens << Token.new(:RPAREN, $&.freeze)

        elsif tmp.sub! %r(\A \[ )x, ''
          @tokens << Token.new(:LBRACKET, $&.freeze)

        elsif tmp.sub! %r(\A \] )x, ''
          @tokens << Token.new(:RBRACKET, $&.freeze)

        elsif tmp.sub! %r(\A [A-Z] [A-Z0-9-]* )xi, ''
          @tokens << Token.new(:name, $&.freeze)

        else
          raise "unexpected token at #{tmp[0..20].inspect}"
        end
      end
      @tokens.freeze
      self
    end

    # Consumes leading indentation from +str+ if it doesn't
    # start with a blank line.
    def _outdent str, rexp
      return if %r(\A \r?\n )x.match str
      return if str.sub! rexp, ''
      raise "line not indented at #{str[0..20].inspect}"
    end

    def _parse_range tok, base
      tok.sub! /^%./, ''
      tok.split('-').map {|x| x.to_i base }.freeze
    end

    def _parse_terminal tok, base
      tok.sub! /^%./, ''
      tok.split('.').map {|chunk| chunk.to_i base }.freeze
    end

    def _parse_repetition tok, sym='*'
      min, max = tok.split(sym, -1)
      max ||= min
      min = min.empty? ? 0    : min.to_i
      max = max.empty? ? :inf : max.to_i
      [min, max].freeze
    end
  end
end

# vim: set ts=2 sts=2 sw=2 expandtab
