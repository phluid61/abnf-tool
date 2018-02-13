
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
        #warn "mismatched rule name (#{@rulename.inspect}, #{other.rulename.inspect})" if @rulename != other.rulename
        Rule.new(@rulename, @elements + other.elements)
      end

      def to_s
        "#{@rulename} = #{@elements}"
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
    end

    class Primitive
      # @param Token token
      def initialize token
        @token = token
      end
      attr_reader :token

      def to_s
        @token.to_s
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
            #warn "overriding rule #{name.value}"
            rules[name.value] = definition
          else
            rules[name.value] += definition
          end
        else
          if op.type == :EQ_ALT
            #warn "alternation for undefined rule #{name.value}"
          end
          rules[name.value] = definition
        end
        _strip seq
      end

      @rules = rules.each_pair.map{|name, definition| Rule.new name, definition }
    end

    def each &block
      @rules.each(&block)
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
      rep_tok = nil
      min = max = 1
      raise "truncated repetition" if seq.empty?
      case (tok = seq.shift).type
      when :repetition
        rep_tok = tok
        min, max = tok.value
        case seq.first.type
        #when :LBRACKET # the ABNF allows this (??)
        when :LPAREN
          seq.shift
          inner = _alternation(seq, :RPAREN)
          raise "unterminated group" if seq.empty? || seq.shift.type != :RPAREN
        when :range, :terminal, :istring, :sstring, :prose, :name
          inner = Primitive.new seq.shift
        else
          raise "unexpected #{seq.first.type.inspect} after #{tok.type.inspect}"
        end
      when :LBRACKET
        rep_tok = tok
        min = 0
        inner = _alternation(seq, :RBRACKET)
        raise "unterminated option" if seq.empty? || seq.shift.type != :RBRACKET
      when :LPAREN
        inner = _alternation(seq, :RPAREN)
        raise "unterminated group" if seq.empty? || seq.shift.type != :RPAREN
      when :range, :terminal, :istring, :sstring, :prose, :name
        inner = Primitive.new tok
      else
        raise "??#{tok.inspect}"
      end
      Repetition.new min, max, inner
    end
  end
end

# vim: set ts=2 sts=2 sw=2 expandtab
