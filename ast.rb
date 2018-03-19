
require_relative 'tokensequence'

module ABNF
  ##
  # An abstract syntax tree, built from a TokenSequence.
  #
  class AST
    class Rule
      # @param Token<name> rulename
      # @param Alternation elements
      def initialize rulename, elements
        @rulename = rulename
        @elements = elements
      end

      attr_reader :rulename, :elements

      def to_a
        @elements.to_a
      end

      def + other
        warn "mismatched rule name (#{@rulename.inspect}, #{other.rulename.inspect})" if @rulename != other.rulename
        Rule.new(@rulename, @elements + other.elements)
      end

      def to_s
        "#{@rulename} = #{@elements}"
      end

      def match? str
        str = str.to_s.dup
        @elements.match? str
      end
    end

    class Alternation
      # @param Concatenation[] concatenations
      def initialize concatenations
        @concatenations = concatenations
      end

      attr_reader :concatenations
      alias to_a concatenations

      def each &block
        @concatenations.each(&block)
      end

      include Enumerable

      def + other
        other = other.to_a if other.respond_to? :to_a
        Alternation.new(@concatenations + other)
      end

      def to_s
        concatenations.map{|c| c.to_s }.join(' / ')
      end

      def match? str
        str = str.to_s.dup
        best = nil
        @concatenations.each do |cat|
          begin
            x = cat.match? str
#p [str, x]
            # longest match wins:
            best = x if x && (best.nil? || best.length > x.length)
            # first match wins:
            #return x if x
          rescue => e
            warn e
          end
        end
        best
        #nil
      end
    end

    class Concatenation
      # @param Repetition[] repetitions
      def initialize repetitions
        @repetitions = repetitions
      end

      attr_reader :repetitions
      alias to_a repetitions

      def each &block
        @repetitions.each(&block)
      end

      include Enumerable

      def + other
        other = other.to_a if other.respond_to? :to_a
        Concatenation.new(@repetitions + other)
      end

      def to_s
        repetitions.map{|c| c.to_s }.join(' ')
      end

      def match? str
        str = str.to_s.dup
        @repetitions.each do |rep|
          str = rep.match? str
          return nil unless str
        end
        str
      end
    end

    class Repetition
      # @param Integer               min (0+)
      # @param Integer|Symbol        max (1+ or :inf)
      # @param Primitive|Alternation inner
      def initialize min, max, inner
        @min = min
        @max = max
        @inner = inner
      end
      attr_reader :min, :max, :inner

      def to_s
        a = b = z = ''
        if ! @inner.is_a?(Primitive)
          b = '( '
          z = ' )'
        end
        if @min == 0 && @max == 1
          b = '[ '
          z = ' ]'
        elsif @min == @max
          a = @min.to_s if @min != 1
        else
          a = (@min == 0 ? '' : @min.to_s) + '*' + (@max == :inf ? '' : @max.to_s)
        end
        a + b + inner.to_s + z
      end

      def match? str
        str = str.to_s.dup
        n = 0
        until str.empty?
          break if @max != :inf && n >= @max
          x = inner.match? str
          break unless x
          str = x
          n += 1
        end
        return nil if n < @min
        str
      end
    end

    class List < Repetition
      OWS_COMMA_OWS = %r(\A [\x20\x09]* , [\x20\x09]* )x

      def to_s
        return super if @min <= 1 && @max <= 1
        a = b = z = ''
        if ! @inner.is_a?(Primitive)
          b = '( '
          z = ' )'
        end
        a = (@min == 0 ? '' : @min.to_s) + '#' + (@max == :inf ? '' : @max.to_s)
        a + b + inner.to_s + z
      end

      def match? str
        # According to spec:
        #
        #   1#element => element *( OWS "," OWS element )
        #   #element => [ 1#element ]
        #   <n>#<m>element => element <n-1>*<m-1>( OWS "," OWS element )
        #
        str = str.to_s.dup
        n = 0
        until str.empty?
          break if @max != :inf && n >= @max
          if n > 0
            # OWS "," OWS
            x = str.sub! OWS_COMMA_OWS, ''
            break unless x
          end
          x = inner.match? str
          break unless x
          str = x
          n += 1
        end
        return nil if n < @min
        str
      end
    end

    class Primitive
      # @param Token token
      def initialize ast, token
        @ast = ast
        @token = token
      end
      attr_reader :token

      def to_s
        @token.to_s
      end

      def match? str
        str = str.to_s.dup
        case @token.type
        when :name
          rule = @ast[@token.value]
          raise "undefined rule #{@token.value}" unless rule
          rule.match? str
        when :prose
          # FIXME: ???
          raise "unable to match against prose <#{@token.value}>"
        when :sstring
          return nil unless str.start_with? @token.value
          str[@token.value.length..-1]
        when :istring
          return nil unless str.downcase.start_with? @token.value.downcase
          str[@token.value.length..-1]
        when :terminal
          x = @token.value.map{|b| b.chr }.join
          return nil unless str.start_with? x
          str[x.length..-1]
        when :range
          b = str[0..0].ord
          return nil if b < @token.value[0] || b > @token.value[1]
          str[1..-1]
        else
          raise "unrecognised pritmitive #{@token.inspect}"
        end
      end
    end

    ##
    # Parse a string into an AST.
    #
    def self.from src
      self.new TokenSequence.new(src)
    end

    include Enumerable

    ##
    # Generate an AST from a TokenSequence.
    #
    def initialize seq
      @rhs_names = []

      rules = {}
      seq = seq.to_a

      ### sanitise sequence
      # strip whitespace
      seq = seq.reject{|tok| tok.type == :whitespace }
#      # replace all comments with plain newlines
#      seq = seq.map{|tok| (tok.type == :comment) ? Token.new(:endline,'') : tok }
      seq = seq.reject{|tok| tok.type == :comment }
      # remove continuations
      seq = seq.reject{|tok| tok.type == :continuation }

      _strip seq
      until seq.empty?
        name, op, definition = _consume_rule(seq)
        if rules[name.value]
          if op.type == :EQ
            warn "overriding rule #{name.value}"
            rules[name.value] = definition
          else
            rules[name.value] += definition
          end
        else
          if op.type == :EQ_ALT
            warn "alternation for undefined rule #{name.value}"
          end
          rules[name.value] = definition
        end
        _strip seq
      end

      @lhs_names = rules.keys
      @rhs_names.uniq!
      @rule_map = {}
      @rules = rules.each_pair.map{|name, definition| @rule_map[name.downcase] = Rule.new(name, definition) }
    end

    def each &block
      @rules.each(&block)
    end

    ##
    # The set of rule names defined by this ABNF.
    #
    def defined_names
      @lhs_names
    end

    ##
    # The set of rule names consumed by rules in this
    # ABNF that are undefined.
    #
    def undefined_names
      @undef ||= @rhs_names - @lhs_names
      @undef
    end

    ##
    # The set of rule names defined by this ABNF that
    # aren't consumed by any rules in it.
    #
    def toplevel_names
      @toplevel ||= @lhs_names - @rhs_names
      @toplevel
    end

    ##
    # Get the specified rule.
    #
    def rule name
      @rule_map[name.downcase]
    end
    alias [] rule

    ##
    # Match the string against the specified rule.
    #
    def match? str, name
      rule = rule(name)
      raise "no such rule: #{name.inspect}" unless rule
      rest = rule.match? str
      return false unless rest && rest.empty?
      true
    end

    # strip all leading :endline tokens from the sequence
    def _strip seq
      seq.shift while (tok = seq.first) && tok.type == :endline
    end

    # consumes (and returns) a partial(?) rule from the start of the sequence
    def _consume_rule seq
      # rule =  rulename defined-as elements c-nl

      rulename = seq.shift
      raise "BUG: bad rulename #{rulename.inspect}" if rulename.nil? || rulename.type != :name

      raise "truncated rule for #{rulename.value}" if seq.empty?

      defined_as = nil
      case (op = seq.shift).type
      when :EQ, :EQ_ALT
        defined_as = op
      else
        raise "unexpected #{op.type.inspect}, expected :EQ or :EQ_ALT"
      end

      definition = _alternation(seq)
      raise "unexpected #{seq.first.type.inspect} after rule" unless seq.empty? || seq.first.type == :endline
      [rulename, defined_as, definition]
    end

    def _alternation seq, term=nil
      cats = []
      cats << _concatenation(seq, term)
      while !seq.empty? && seq.first.type == :ALT
        seq.shift
        cats << _concatenation(seq, term)
      end
      Alternation.new cats
    end

    def _concatenation seq, term=nil
      reps = []
      reps << _repetition(seq)
      until seq.empty? || seq.first.type == :ALT || seq.first.type == :endline || (term && seq.first.type == term)
        reps << _repetition(seq)
      end
      Concatenation.new reps
    end

    def _repetition seq
      klass = Repetition
      rep_tok = nil
      min = max = 1
      raise "truncated repetition" if seq.empty?
      case (tok = seq.shift).type
      when :repetition, :list
        klass = List if tok.type == :list
        rep_tok = tok
        min, max = tok.value
        case (tok2 = seq.first).type
        #when :LBRACKET # the ABNF allows this (??)
        when :LPAREN
          seq.shift
          inner = _alternation(seq, :RPAREN)
          raise "unterminated group" if seq.empty? || seq.shift.type != :RPAREN
        when :range, :terminal, :istring, :sstring, :prose
          inner = Primitive.new self, seq.shift
        when :name
          @rhs_names << tok2.value
          inner = Primitive.new self, seq.shift
        else
          raise "unexpected #{tok2.type.inspect} after #{tok.type.inspect}"
        end
      when :LBRACKET
        rep_tok = tok
        min = 0
        inner = _alternation(seq, :RBRACKET)
        raise "unterminated option" if seq.empty? || seq.shift.type != :RBRACKET
      when :LPAREN
        inner = _alternation(seq, :RPAREN)
        raise "unterminated group" if seq.empty? || seq.shift.type != :RPAREN
      when :range, :terminal, :istring, :sstring, :prose
        inner = Primitive.new self, tok
      when :name
        @rhs_names << tok.value
        inner = Primitive.new self, tok
      else
        raise "??#{tok.inspect}"
      end
      klass.new min, max, inner
    end
  end
end

# vim: set ts=2 sts=2 sw=2 expandtab
