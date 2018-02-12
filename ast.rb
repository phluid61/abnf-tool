
require_relative 'tokensequence'

module ABNF
  ##
  # An abstract syntax tree, built from a TokenSequence.
  #
  class AST
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
      @rules = []
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
        @rules << _consume_rule(seq)
        _strip seq
      end
    end

    def each &block
      @rules.each(&block)
    end

    # strip all leading :endline tokens from the sequence
    def _strip seq
      seq.shift while (tok = seq.first) && tok.type == :endline
    end

    # consumes (and returns) a rule from the start of the sequence
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
      [:rule, rulename, defined_as, definition]
    end

    def _alternation seq, term=nil
      cats = []
      cats << _concatenation(seq, term)
      while !seq.empty? && seq.first.type == :ALT
        seq.shift
        cats << _concatenation(seq, term)
      end
      [:alternation, cats]
    end

    def _concatenation seq, term=nil
      reps = []
      reps << _repetition(seq)
      until seq.empty? || seq.first.type == :ALT || seq.first.type == :endline || (term && seq.first.type == term)
        reps << _repetition(seq)
      end
      [:concatenation, reps]
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
          inner = [:primitive, seq.shift]
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
        inner = [:primitive, tok]
      else
        raise "??#{tok.inspect}"
      end
      [:repetition, inner, min, max]
    end
  end
end

# vim: set ts=2 sts=2 sw=2 expandtab
