# frozen_string_literal: true

require "test_helper"

class ParseTest < Test::Unit::TestCase
  include YARP::DSL

  test "empty string" do
    YARP.parse("") => YARP::ParseResult[node: YARP::Program[statements: YARP::Statements[body: []]]]
  end

  test "comment inline" do
    YARP.parse("# comment") => YARP::ParseResult[comments: [YARP::Comment[type: :inline]]]
  end

  test "comment __END__" do
    source = <<~RUBY
      __END__
      comment
    RUBY

    YARP.parse(source) => YARP::ParseResult[comments: [YARP::Comment[type: :__END__]]]
  end

  test "comment embedded document" do
    source = <<~RUBY
      =begin
      comment
      =end
    RUBY

    YARP.parse(source) => YARP::ParseResult[comments: [YARP::Comment[type: :embdoc]]]
  end

  test "alias bare" do
    expected = AliasNode(
      KEYWORD_ALIAS("alias"),
      SymbolNode(nil, IDENTIFIER("foo"), nil),
      SymbolNode(nil, IDENTIFIER("bar"), nil)
    )

    assert_parses expected, "alias foo bar"
  end

  test "alias symbols" do
    expected = AliasNode(
      KEYWORD_ALIAS("alias"),
      SymbolNode(SYMBOL_BEGIN(":"), IDENTIFIER("foo"), nil),
      SymbolNode(SYMBOL_BEGIN(":"), IDENTIFIER("bar"), nil)
    )

    assert_parses expected, "alias :foo :bar"
  end

  test "alias global variables" do
    expected = AliasNode(
      KEYWORD_ALIAS("alias"),
      GlobalVariableRead(GLOBAL_VARIABLE("$foo")),
      GlobalVariableRead(GLOBAL_VARIABLE("$bar"))
    )

    assert_parses expected, "alias $foo $bar"
  end

  test "alias backreference global variables" do
    expected = AliasNode(
      KEYWORD_ALIAS("alias"),
      GlobalVariableRead(GLOBAL_VARIABLE("$a")),
      GlobalVariableRead(BACK_REFERENCE("$'"))
    )

    assert_parses expected, "alias $a $'"
  end

  test "and keyword" do
    assert_parses AndNode(expression("1"), KEYWORD_AND("and"), expression("2")), "1 and 2"
  end

  test "and operator" do
    assert_parses AndNode(expression("1"), AMPERSAND_AMPERSAND("&&"), expression("2")), "1 && 2"
  end

  test "array literal" do
    expected = ArrayNode(
      BRACKET_LEFT("["),
      [
        IntegerLiteral(INTEGER("1")),
        FloatLiteral(FLOAT("1.0")),
        RationalLiteral(RATIONAL_NUMBER("1r")),
        ImaginaryLiteral(IMAGINARY_NUMBER("1i"))
      ],
      BRACKET_RIGHT("]")
    )

    assert_parses expected, "[1, 1.0, 1r, 1i]"
  end

  test "array literal empty" do
    assert_parses ArrayNode(BRACKET_LEFT("["), [], BRACKET_RIGHT("]")), "[]"
  end

  test "array with splat" do
    expected = ArrayNode(
      BRACKET_LEFT("["),
      [StarNode(
         IDENTIFIER("a"),
         CallNode(nil, nil, IDENTIFIER("a"), nil, nil, nil, "a")
       )],
      BRACKET_RIGHT("]")
    )

    assert_parses expected, "[*a]"
  end

  test "empty array literal" do
    assert_parses ArrayNode(BRACKET_LEFT("["), [], BRACKET_RIGHT("]")), "[\n]\n"
  end

  test "empty parenteses" do
    assert_parses ParenthesesNode(PARENTHESIS_LEFT("("), Statements([]), PARENTHESIS_RIGHT(")")), "()"
  end


  test "parentesized expression" do
    expected = ParenthesesNode(
      PARENTHESIS_LEFT("("),
      Statements(
        [CallNode(
           IntegerLiteral(INTEGER("1")),
           nil,
           PLUS("+"),
           nil,
           ArgumentsNode([IntegerLiteral(INTEGER("1"))]),
           nil,
           "+"
         )]
      ),
      PARENTHESIS_RIGHT(")")
    )

    assert_parses expected, "(1 + 1)"
  end

  test "parentesized with multiple statements" do
    expected = ParenthesesNode(
      PARENTHESIS_LEFT("("),
      Statements(
        [CallNode(nil, nil, IDENTIFIER("a"), nil, nil, nil, "a"),
         CallNode(nil, nil, IDENTIFIER("b"), nil, nil, nil, "b"),
         CallNode(nil, nil, IDENTIFIER("c"), nil, nil, nil, "c")]
      ),
      PARENTHESIS_RIGHT(")")
    )
    assert_parses expected, "(a; b; c)"
  end

  test "parentesized with empty statements" do
    assert_parses ParenthesesNode(PARENTHESIS_LEFT("("), Statements([]), PARENTHESIS_RIGHT(")")), "(\n;\n;\n)"
  end

  test "binary !=" do
    assert_parses CallNode(expression("1"), nil, BANG_EQUAL("!="), nil, ArgumentsNode([expression("2")]), nil, "!="), "1 != 2"
  end

  test "binary !~" do
    assert_parses CallNode(expression("1"), nil, BANG_TILDE("!~"), nil, ArgumentsNode([expression("2")]), nil, "!~"), "1 !~ 2"
  end

  test "binary ==" do
    assert_parses CallNode(expression("1"), nil, EQUAL_EQUAL("=="), nil, ArgumentsNode([expression("2")]), nil, "=="), "1 == 2"
  end

  test "binary ===" do
    assert_parses CallNode(expression("1"), nil, EQUAL_EQUAL_EQUAL("==="), nil, ArgumentsNode([expression("2")]), nil, "==="), "1 === 2"
  end

  test "binary =~" do
    assert_parses CallNode(expression("1"), nil, EQUAL_TILDE("=~"), nil, ArgumentsNode([expression("2")]), nil, "=~"), "1 =~ 2"
  end

  test "binary <=>" do
    assert_parses CallNode(expression("1"), nil, LESS_EQUAL_GREATER("<=>"), nil, ArgumentsNode([expression("2")]), nil, "<=>"), "1 <=> 2"
  end

  test "binary >" do
    assert_parses CallNode(expression("1"), nil, GREATER(">"), nil, ArgumentsNode([expression("2")]), nil, ">"), "1 > 2"
  end

  test "binary >=" do
    assert_parses CallNode(expression("1"), nil, GREATER_EQUAL(">="), nil, ArgumentsNode([expression("2")]), nil, ">="), "1 >= 2"
  end

  test "binary <" do
    assert_parses CallNode(expression("1"), nil, LESS("<"), nil, ArgumentsNode([expression("2")]), nil, "<"), "1 < 2"
  end

  test "binary <=" do
    assert_parses CallNode(expression("1"), nil, LESS_EQUAL("<="), nil, ArgumentsNode([expression("2")]), nil, "<="), "1 <= 2"
  end

  test "binary ^" do
    assert_parses CallNode(expression("1"), nil, CARET("^"), nil, ArgumentsNode([expression("2")]), nil, "^"), "1 ^ 2"
  end

  test "binary |" do
    assert_parses CallNode(expression("1"), nil, PIPE("|"), nil, ArgumentsNode([expression("2")]), nil, "|"), "1 | 2"
  end

  test "binary &" do
    assert_parses CallNode(expression("1"), nil, AMPERSAND("&"), nil, ArgumentsNode([expression("2")]), nil, "&"), "1 & 2"
  end

  test "binary >>" do
    assert_parses CallNode(expression("1"), nil, GREATER_GREATER(">>"), nil, ArgumentsNode([expression("2")]), nil, ">>"), "1 >> 2"
  end

  test "binary <<" do
    assert_parses CallNode(expression("1"), nil, LESS_LESS("<<"), nil, ArgumentsNode([expression("2")]), nil, "<<"), "1 << 2"
  end

  test "binary -" do
    assert_parses CallNode(expression("1"), nil, MINUS("-"), nil, ArgumentsNode([expression("2")]), nil, "-"), "1 - 2"
  end

  test "binary +" do
    assert_parses CallNode(expression("1"), nil, PLUS("+"), nil, ArgumentsNode([expression("2")]), nil, "+"), "1 + 2"
  end

  test "binary %" do
    assert_parses CallNode(expression("1"), nil, PERCENT("%"), nil, ArgumentsNode([expression("2")]), nil, "%"), "1 % 2"
  end

  test "binary /" do
    assert_parses CallNode(expression("1"), nil, SLASH("/"), nil, ArgumentsNode([expression("2")]), nil, "/"), "1 / 2"
  end

  test "binary / with no space" do
    expected = CallNode(
      CallNode(
        expression("1"),
        nil,
        SLASH("/"),
        nil,
        ArgumentsNode([expression("2")]),
        nil,
        "/"
      ),
      nil,
      SLASH("/"),
      nil,
      ArgumentsNode([expression("3")]),
      nil,
      "/"
    )

    assert_parses expected, "1/2/3"
  end

  test "binary *" do
    assert_parses CallNode(expression("1"), nil, STAR("*"), nil, ArgumentsNode([expression("2")]), nil, "*"), "1 * 2"
  end

  test "binary **" do
    assert_parses CallNode(expression("1"), nil, STAR_STAR("**"), nil, ArgumentsNode([expression("2")]), nil, "**"), "1**2"
  end

  test "break" do
    expected = BreakNode(
      KEYWORD_BREAK("break"),
      nil,
    )

    assert_parses expected, "break"
  end

  test "break 1" do
    expected = BreakNode(
      KEYWORD_BREAK("break"),
      ArgumentsNode([
        expression("1"),
      ]),
    )
    assert_parses expected, "break 1"
  end

  test "break 1, 2, 3" do
    expected = BreakNode(
      KEYWORD_BREAK("break"),
      ArgumentsNode([
        expression("1"),
        expression("2"),
        expression("3"),
      ]),
    )
    assert_parses expected, "break 1, 2, 3"
  end

  test "break 1, 2,\n3" do
    expected = BreakNode(
      KEYWORD_BREAK("break"),
      ArgumentsNode([
        expression("1"),
        expression("2"),
        expression("3"),
      ]),
    )
    assert_parses expected, "break 1, 2,\n3"
  end

  test "break()" do
    expected = BreakNode(
      KEYWORD_BREAK("break"),
      ArgumentsNode([
        expression("()"),
      ]),
    )
    assert_parses expected, "break()"
  end

  test "break(1)" do
    expected = BreakNode(
      KEYWORD_BREAK("break"),
      ArgumentsNode([
        expression("(1)"),
      ]),
    )

    assert_parses expected, "break(1)"
  end

  test "break (1), (2), (3)" do
    expected = BreakNode(
      KEYWORD_BREAK("break"),
      ArgumentsNode([
        expression("(1)"),
        expression("(2)"),
        expression("(3)"),
      ]),
    )
    assert_parses expected, "break (1), (2), (3)"
  end

  test "break [1, 2, 3]" do
    expected = BreakNode(
      KEYWORD_BREAK("break"),
      ArgumentsNode([
        expression("[1, 2, 3]"),
      ]),
    )
    assert_parses expected, "break [1, 2, 3]"
  end

  test "break multiple statements inside of parentheses" do
    expected = BreakNode(
      KEYWORD_BREAK("break"),
      ArgumentsNode([
        ParenthesesNode(
          PARENTHESIS_LEFT("("),
          Statements([expression("1"), expression("2")]),
          PARENTHESIS_RIGHT(")")
        )
      ])
    )

    assert_parses expected, <<~RUBY
      break(
        1
        2
      )
    RUBY
  end

  test "call with ? identifier" do
    assert_parses CallNode(nil, nil, IDENTIFIER("a?"), nil, nil, nil, "a?"), "a?"
  end

  test "call with ! identifier" do
    assert_parses CallNode(nil, nil, IDENTIFIER("a!"), nil, nil, nil, "a!"), "a!"
  end

  test "call with ::" do
    expected = CallNode(
      expression("a"),
      COLON_COLON("::"),
      IDENTIFIER("b"),
      nil,
      nil,
      nil,
      "b"
    )

    assert_parses expected, "a::b"
  end

  test "call with .() shorthand" do
    expected = CallNode(
      CallNode(nil, nil, IDENTIFIER("a"), nil, nil, nil, "a"),
      DOT("."),
      NOT_PROVIDED(""),
      PARENTHESIS_LEFT("("),
      nil,
      PARENTHESIS_RIGHT(")"),
      "call"
    )

    assert_parses expected, "a.()"
  end

  test "call with .() shorthand and arguments" do
    expected = CallNode(
      expression("a"),
      DOT("."),
      NOT_PROVIDED(""),
      PARENTHESIS_LEFT("("),
      ArgumentsNode([expression("1"), expression("2"), expression("3")]),
      PARENTHESIS_RIGHT(")"),
      "call"
    )

    assert_parses expected, "a.(1, 2, 3)"
  end

  test "call with no parentheses or arguments" do
    expected = CallNode(
      CallNode(
        expression("a"),
        DOT("."),
        IDENTIFIER("b"),
        nil,
        nil,
        nil,
        "b"
      ),
      DOT("."),
      IDENTIFIER("c"),
      nil,
      nil,
      nil,
      "c"
    )

    assert_parses expected, "a.b.c"
  end

  test "call with parentheses and no arguments" do
    expected = CallNode(
      nil,
      nil,
      IDENTIFIER("a"),
      PARENTHESIS_LEFT("("),
      nil,
      PARENTHESIS_RIGHT(")"),
      "a"
    )

    assert_parses expected, "a()"
  end

  test "call with parentheses and arguments" do
    expected = CallNode(
      nil,
      nil,
      IDENTIFIER("a"),
      PARENTHESIS_LEFT("("),
      ArgumentsNode([expression("b"), expression("c")]),
      PARENTHESIS_RIGHT(")"),
      "a"
    )

    assert_parses expected, "a(b, c)"
  end

  test "call nested with parentheses and no arguments" do
    expected = CallNode(
      expression("a"),
      DOT("."),
      IDENTIFIER("b"),
      PARENTHESIS_LEFT("("),
      nil,
      PARENTHESIS_RIGHT(")"),
      "b"
    )

    assert_parses expected, "a.b()"
  end

  test "call nested with parentheses and arguments" do
    expected = CallNode(
      expression("a"),
      DOT("."),
      IDENTIFIER("b"),
      PARENTHESIS_LEFT("("),
      ArgumentsNode([expression("c"), expression("d")]),
      PARENTHESIS_RIGHT(")"),
      "b"
    )

    assert_parses expected, "a.b(c, d)"
  end

  test "call with =" do
    expected = CallNode(
      CallNode(nil, nil, IDENTIFIER("foo"), nil, nil, nil, "foo"),
      DOT("."),
      EQUAL("="),
      nil,
      ArgumentsNode([IntegerLiteral(INTEGER("1"))]),
      nil,
      "bar="
    )

    assert_parses expected, "foo.bar = 1"
  end

  test "safe call" do
    expected = CallNode(
      expression("a"),
      AMPERSAND_DOT("&."),
      IDENTIFIER("b"),
      nil,
      nil,
      nil,
      "b"
    )

    assert_parses expected, "a&.b"
  end

  test "safe call with &.() shorthand and no arguments" do
    expected = CallNode(
      expression("a"),
      AMPERSAND_DOT("&."),
      NOT_PROVIDED(""),
      PARENTHESIS_LEFT("("),
      nil,
      PARENTHESIS_RIGHT(")"),
      "call"
    )

    assert_parses expected, "a&.()"
  end

  test "safe call with parentheses and no arguments" do
    expected = CallNode(
      expression("a"),
      AMPERSAND_DOT("&."),
      IDENTIFIER("b"),
      PARENTHESIS_LEFT("("),
      nil,
      PARENTHESIS_RIGHT(")"),
      "b"
    )

    assert_parses expected, "a&.b()"
  end

  test "safe call with parentheses and arguments" do
    expected = CallNode(
      expression("a"),
      AMPERSAND_DOT("&."),
      IDENTIFIER("b"),
      PARENTHESIS_LEFT("("),
      ArgumentsNode([expression("c")]),
      PARENTHESIS_RIGHT(")"),
      "b"
    )

    assert_parses expected, "a&.b(c)"
  end

  test "call without parentheses" do
    expected = CallNode(
      nil,
      nil,
      IDENTIFIER("a"),
      nil,
      ArgumentsNode([expression("b"), expression("c")]),
      nil,
      "a"
    )

    assert_parses expected, "a b, c"
  end

  test "call without parentheses with a receiver" do
    expected = CallNode(
      expression("a"),
      DOT("."),
      IDENTIFIER("b"),
      nil,
      ArgumentsNode([expression("c"), expression("d")]),
      nil,
      "b"
    )

    assert_parses expected, "a.b c, d"
  end

  test "character literal" do
    assert_parses StringNode(STRING_BEGIN("?"), STRING_CONTENT("a"), nil, "a"), "?a"
  end

  test "class" do
    expected = ClassNode(
      Scope([IDENTIFIER("a")]),
      KEYWORD_CLASS("class"),
      ConstantRead(CONSTANT("A")),
      nil,
      nil,
      Statements([
        LocalVariableWrite(
          IDENTIFIER("a"),
          EQUAL("="),
          IntegerLiteral(INTEGER("1"))
        )
      ]),
      KEYWORD_END("end")
    )

    assert_parses expected, "class A a = 1 end"
  end

  test "class with superclass" do
    expected = ClassNode(
      Scope([IDENTIFIER("a")]),
      KEYWORD_CLASS("class"),
      ConstantRead(CONSTANT("A")),
      LESS("<"),
      ConstantRead(CONSTANT("B")),
      Statements([
        LocalVariableWrite(
          IDENTIFIER("a"),
          EQUAL("="),
          IntegerLiteral(INTEGER("1"))
        )
      ]),
      KEYWORD_END("end")
    )

    assert_parses expected, "class A < B a = 1 end"
  end

  test "class variable read" do
    assert_parses ClassVariableRead(CLASS_VARIABLE("@@abc")), "@@abc"
  end

  test "class variable write" do
    assert_parses ClassVariableWrite(CLASS_VARIABLE("@@abc"), EQUAL("="), expression("1")), "@@abc = 1"
  end

  test "constant path" do
    assert_parses ConstantPathNode(ConstantRead(CONSTANT("A")), COLON_COLON("::"), ConstantRead(CONSTANT("B"))), "A::B"
  end

  test "constant path with multiple levels" do
    expected = ConstantPathNode(
      ConstantRead(CONSTANT("A")),
      COLON_COLON("::"),
      ConstantPathNode(
        ConstantRead(CONSTANT("B")),
        COLON_COLON("::"),
        ConstantRead(CONSTANT("C"))
      )
    )

    assert_parses expected, "A::B::C"
  end

  test "constant path with variable parent" do
    expected = ConstantPathNode(
      CallNode(nil, nil, IDENTIFIER("a"), nil, nil, nil, "a"),
      COLON_COLON("::"),
      ConstantRead(CONSTANT("B"))
    )

    assert_parses expected, "a::B"
  end

  test "constant read" do
    assert_parses ConstantRead(CONSTANT("ABC")), "ABC"
  end

  test "top-level constant read" do
    assert_parses ConstantPathNode(nil, COLON_COLON("::"), ConstantRead(CONSTANT("A"))), "::A"
  end

  test "top-level constant assignment" do
    expected = ConstantPathWriteNode(
      ConstantPathNode(nil, COLON_COLON("::"), ConstantRead(CONSTANT("A"))),
      EQUAL("="),
      IntegerLiteral(INTEGER("1"))
    )

    assert_parses expected, "::A = 1"
  end

  test "top-level constant path read" do
    expected = ConstantPathNode(
      ConstantPathNode(nil, COLON_COLON("::"), ConstantRead(CONSTANT("A"))),
      COLON_COLON("::"),
      ConstantRead(CONSTANT("B"))
    )

    assert_parses expected, "::A::B"
  end

  test "top-level constant path assignment" do
    expected = ConstantPathWriteNode(
      ConstantPathNode(
        ConstantPathNode(nil, COLON_COLON("::"), ConstantRead(CONSTANT("A"))),
        COLON_COLON("::"),
        ConstantRead(CONSTANT("B"))
      ),
      EQUAL("="),
      IntegerLiteral(INTEGER("1"))
    )

    assert_parses expected, "::A::B = 1"
  end

  test "top level constant with method inside" do
    expected = CallNode(
      ConstantPathNode(nil, COLON_COLON("::"), ConstantRead(CONSTANT("A"))),
      COLON_COLON("::"),
      IDENTIFIER("foo"),
      nil,
      nil,
      nil,
      "foo"
    )

    assert_parses expected, "::A::foo"
  end

  test "constant path write single" do
    assert_parses ConstantPathWriteNode(ConstantRead(CONSTANT("A")), EQUAL("="), expression("1")), "A = 1"
  end

  test "constant path write multiple" do
    expected = ConstantPathWriteNode(
      ConstantPathNode(ConstantRead(CONSTANT("A")), COLON_COLON("::"), ConstantRead(CONSTANT("B"))),
      EQUAL("="),
      expression("1")
    )

    assert_parses expected, "A::B = 1"
  end

  test "def without parentheses" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      IDENTIFIER("a"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def a\nend"
  end

  test "def with parentheses" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      IDENTIFIER("a"),
      PARENTHESIS_LEFT("("),
      ParametersNode([], [], nil, [], nil, nil),
      PARENTHESIS_RIGHT(")"),
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def a()\nend"
  end

  test "def with scope" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      IDENTIFIER("a"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([expression("b = 1")]),
      KEYWORD_END("end"),
      Scope([IDENTIFIER("b")])
    )

    assert_parses expected, "def a\nb = 1\nend"
  end

  test "def with required parameter" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      IDENTIFIER("a"),
      nil,
      ParametersNode([RequiredParameterNode(IDENTIFIER("b"))], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([IDENTIFIER("b")])
    )

    assert_parses expected, "def a b\nend"
  end

  test "def with keyword parameter (no parenthesis)" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      IDENTIFIER("a"),
      nil,
      ParametersNode([], [], nil, [KeywordParameterNode(LABEL("b:"), nil)], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([LABEL("b")])
    )

    assert_parses expected, "def a b:\nend"
  end

  test "def with keyword parameter (parenthesis)" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      IDENTIFIER("a"),
      PARENTHESIS_LEFT("("),
      ParametersNode([], [], nil, [KeywordParameterNode(LABEL("b:"), nil)], nil, nil),
      PARENTHESIS_RIGHT(")"),
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([LABEL("b")])
    )

    assert_parses expected, "def a(b:)\nend"
  end

  test "def with multiple required parameters" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      IDENTIFIER("a"),
      nil,
      ParametersNode(
        [
          RequiredParameterNode(IDENTIFIER("b")),
          RequiredParameterNode(IDENTIFIER("c")),
          RequiredParameterNode(IDENTIFIER("d"))
        ],
        [],
        nil,
        [],
        nil,
        nil
      ),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([IDENTIFIER("b"), IDENTIFIER("c"), IDENTIFIER("d")])
    )

    assert_parses expected, "def a b, c, d\nend"
  end

  test "def with required and optional parameters" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      IDENTIFIER("a"),
      nil,
      ParametersNode(
        [RequiredParameterNode(IDENTIFIER("b"))],
        [OptionalParameterNode(IDENTIFIER("c"), EQUAL("="), expression("2"))],
        nil,
        [],
        nil,
        nil
      ),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([IDENTIFIER("b"), IDENTIFIER("c")])
    )

    assert_parses expected, "def a b, c = 2\nend"
  end

  test "def with optional parameters" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      IDENTIFIER("a"),
      nil,
      ParametersNode(
        [],
        [
          OptionalParameterNode(IDENTIFIER("b"), EQUAL("="), expression("1")),
          OptionalParameterNode(IDENTIFIER("c"), EQUAL("="), expression("2"))
        ],
        nil,
        [],
        nil,
        nil
      ),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([IDENTIFIER("b"), IDENTIFIER("c")])
    )

    assert_parses expected, "def a b = 1, c = 2\nend"
  end

  test "def with optional keyword parameters (no parenthesis)" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      IDENTIFIER("a"),
      nil,
      ParametersNode(
        [],
        [KeywordParameterNode(LABEL("c:"), expression("1"))],
        nil,
        [KeywordParameterNode(LABEL("b:"), nil)],
        nil,
        nil
      ),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([LABEL("b"), LABEL("c")])
    )

    assert_parses expected, "def a b:, c: 1 \nend"
  end

  test "def with optional keyword parameters (parenthesis)" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      IDENTIFIER("a"),
      PARENTHESIS_LEFT("("),
      ParametersNode(
        [],
        [KeywordParameterNode(LABEL("c:"), expression("1"))],
        nil,
        [KeywordParameterNode(LABEL("b:"), nil)],
        nil,
        nil
      ),
      PARENTHESIS_RIGHT(")"),
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([LABEL("b"), LABEL("c")])
    )

    assert_parses expected, "def a(b:, c: 1)\nend"
  end

  test "def with optional keyword parameters and line break" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      IDENTIFIER("a"),
      PARENTHESIS_LEFT("("),
      ParametersNode(
        [],
        [KeywordParameterNode(LABEL("b:"), expression("1"))],
        nil,
        [KeywordParameterNode(LABEL("c:"), nil)],
        nil,
        nil
      ),
      PARENTHESIS_RIGHT(")"),
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([LABEL("b"), LABEL("c")])
    )

    assert_parses expected, <<~RUBY
      def a(b:
        1, c:)
      end
    RUBY
  end

  test "def with rest parameter" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      IDENTIFIER("a"),
      nil,
      ParametersNode([], [], RestParameterNode(STAR("*"), IDENTIFIER("b")), [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([IDENTIFIER("b")])
    )

    assert_parses expected, "def a *b\nend"
  end

  test "def with rest parameter without name" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      IDENTIFIER("a"),
      nil,
      ParametersNode([], [], RestParameterNode(STAR("*"), nil), [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([STAR("*")])
    )

    assert_parses expected, "def a *\nend"
  end

  test "def with keyword rest parameter" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      IDENTIFIER("a"),
      nil,
      ParametersNode([], [], nil, [], KeywordRestParameterNode(STAR_STAR("**"), IDENTIFIER("b")), nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([IDENTIFIER("b")])
    )

    assert_parses expected, "def a **b\nend"
  end

  test "def with keyword rest parameter without name" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      IDENTIFIER("a"),
      nil,
      ParametersNode([], [], nil, [], KeywordRestParameterNode(STAR_STAR("**"), nil), nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def a **\nend"
  end

  test "def with forwarding parameter" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      IDENTIFIER("a"),
      nil,
      ParametersNode([], [], nil, [], ForwardingParameterNode(DOT_DOT_DOT("...")), nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([DOT_DOT_DOT("...")])
    )

    assert_parses expected, "def a ...\nend"
  end

  test "def with block parameter" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      IDENTIFIER("a"),
      nil,
      ParametersNode([], [], nil, [], nil, BlockParameterNode(IDENTIFIER("b"), Location(6, 7))),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([IDENTIFIER("b")])
    )

    assert_parses expected, "def a &b\nend"
  end

  test "def with block parameter without name" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      IDENTIFIER("a"),
      nil,
      ParametersNode([], [], nil, [], nil, BlockParameterNode(nil, Location(6, 7))),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def a &\nend"
  end

  test "def with **nil" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      IDENTIFIER("m"),
      nil,
      ParametersNode(
        [RequiredParameterNode(IDENTIFIER("a"))],
        [],
        nil,
        [KeywordParameterNode(LABEL("b:"), nil)],
        NoKeywordsParameterNode(KEYWORD_NIL("nil")),
        nil
      ),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([IDENTIFIER("a"), LABEL("b")])
    )

    assert_parses expected, "def m a, b:, **nil\nend"
  end

  test "method call with label keyword args" do
    expected = CallNode(
      nil,
      nil,
      IDENTIFIER("hi"),
      nil,
      ArgumentsNode(
        [HashNode(
           nil,
           [AssocNode(
              SymbolNode(nil, LABEL("there"), LABEL_END(":")),
              nil,
              SymbolNode(SYMBOL_BEGIN(":"), IDENTIFIER("friend"), nil)
            )],
           nil
         )]
      ),
      nil,
      "hi"
    )

    assert_parses expected, "hi there: :friend"
  end

  test "method call with rocket keyword args" do
    expected = CallNode(
      nil,
      nil,
      IDENTIFIER("hi"),
      nil,
      ArgumentsNode(
        [AssocNode(
           SymbolNode(SYMBOL_BEGIN(":"), IDENTIFIER("there"), nil),
           EQUAL_GREATER("=>"),
           SymbolNode(SYMBOL_BEGIN(":"), IDENTIFIER("friend"), nil)
         )]
      ),
      nil,
      "hi"
    )
    assert_parses expected, "hi :there => :friend"
  end

  test "method call with mixed format keyword args" do
    expected = CallNode(
      nil,
      nil,
      IDENTIFIER("hi"),
      nil,
      ArgumentsNode(
        [HashNode(
           nil,
           [AssocSplatNode(
              HashNode(BRACE_LEFT("{"), [], BRACE_RIGHT("}")),
              Location(22, 24)
            ),
            AssocNode(
              SymbolNode(nil, LABEL("whatup"), LABEL_END(":")),
              nil,
              SymbolNode(SYMBOL_BEGIN(":"), IDENTIFIER("dog"), nil)
            )],
           nil
         )]
      ),
      nil,
      "hi"
    )
    assert_parses expected, "hi :there => :friend, **{}, whatup: :dog"
  end

  test "method call with parens + keyword args" do
    expected = CallNode(
      nil,
      nil,
      IDENTIFIER("hi"),
      PARENTHESIS_LEFT("("),
      ArgumentsNode(
        [HashNode(
           nil,
           [AssocSplatNode(
              HashNode(BRACE_LEFT("{"), [], BRACE_RIGHT("}")),
              Location(22, 24)
            ),
            AssocNode(
              SymbolNode(nil, LABEL("whatup"), LABEL_END(":")),
              nil,
              SymbolNode(SYMBOL_BEGIN(":"), IDENTIFIER("dog"), nil)
            )],
           nil
         )]
      ),
      PARENTHESIS_RIGHT(")"),
      "hi"
    )
    assert_parses expected, "hi(:there => :friend, **{}, whatup: :dog)"
  end

  test "method call with explicit hash" do
    expected = CallNode(
      nil,
      nil,
      IDENTIFIER("hi"),
      nil,
      ArgumentsNode(
        [IntegerLiteral(INTEGER("123")),
         HashNode(
           BRACE_LEFT("{"),
           [AssocNode(
              SymbolNode(SYMBOL_BEGIN(":"), IDENTIFIER("there"), nil),
              EQUAL_GREATER("=>"),
              SymbolNode(SYMBOL_BEGIN(":"), IDENTIFIER("friend"), nil)
            ),
            AssocSplatNode(
              HashNode(BRACE_LEFT("{"), [], BRACE_RIGHT("}")),
              Location(29, 31)
            ),
            AssocNode(
              SymbolNode(nil, LABEL("whatup"), LABEL_END(":")),
              nil,
              SymbolNode(SYMBOL_BEGIN(":"), IDENTIFIER("dog"), nil)
            )],
           BRACE_RIGHT("}")
         )]
      ),
      nil,
      "hi"
    )
    assert_parses expected, "hi 123, { :there => :friend, **{}, whatup: :dog }"
  end

  test "method call with ..." do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      IDENTIFIER("a"),
      PARENTHESIS_LEFT("("),
      ParametersNode(
        [],
        [],
        nil,
        [],
        ForwardingParameterNode(DOT_DOT_DOT("...")),
        nil
      ),
      PARENTHESIS_RIGHT(")"),
      nil,
      Statements(
        [CallNode(
           nil,
           nil,
           IDENTIFIER("b"),
           PARENTHESIS_LEFT("("),
           ArgumentsNode([ForwardingArgumentsNode(DOT_DOT_DOT("..."))]),
           PARENTHESIS_RIGHT(")"),
           "b"
         )]
      ),
      KEYWORD_END("end"),
      Scope([DOT_DOT_DOT("...")])
    )

    assert_parses expected, "def a(...); b(...); end"
  end


  test "method call with ... after args" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      IDENTIFIER("a"),
      PARENTHESIS_LEFT("("),
      ParametersNode(
        [],
        [],
        nil,
        [],
        ForwardingParameterNode(DOT_DOT_DOT("...")),
        nil
      ),
      PARENTHESIS_RIGHT(")"),
      nil,
      Statements(
        [CallNode(
           nil,
           nil,
           IDENTIFIER("b"),
           PARENTHESIS_LEFT("("),
           ArgumentsNode(
             [IntegerLiteral(INTEGER("1")),
              IntegerLiteral(INTEGER("2")),
              ForwardingArgumentsNode(DOT_DOT_DOT("..."))]
           ),
           PARENTHESIS_RIGHT(")"),
           "b"
         )]
      ),
      KEYWORD_END("end"),
      Scope([DOT_DOT_DOT("...")])
    )

    assert_parses expected, "def a(...); b(1, 2, ...); end"
  end

  test "method call with interpolated ..." do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      IDENTIFIER("a"),
      PARENTHESIS_LEFT("("),
      ParametersNode(
        [],
        [],
        nil,
        [],
        ForwardingParameterNode(DOT_DOT_DOT("...")),
        nil
      ),
      PARENTHESIS_RIGHT(")"),
      nil,
      Statements(
        [InterpolatedStringNode(
           STRING_BEGIN("\""),
           [StringNode(nil, STRING_CONTENT("foo"), nil, "foo"),
            StringInterpolatedNode(
              EMBEXPR_BEGIN("\#{"),
              Statements(
                [CallNode(
                   nil,
                   nil,
                   IDENTIFIER("b"),
                   PARENTHESIS_LEFT("("),
                   ArgumentsNode([ForwardingArgumentsNode(DOT_DOT_DOT("..."))]),
                   PARENTHESIS_RIGHT(")"),
                   "b"
                 )]
              ),
              EMBEXPR_END("}")
            )],
           STRING_END("\"")
         )]
      ),
      KEYWORD_END("end"),
      Scope([DOT_DOT_DOT("...")])
    )

    assert_parses expected, "def a(...); \"foo\#{b(...)}\"; end"
  end

  test "method call with *rest" do
    expected = CallNode(
      nil,
      nil,
      IDENTIFIER("foo"),
      PARENTHESIS_LEFT("("),
      ArgumentsNode(
        [StarNode(IDENTIFIER("rest"), CallNode(nil, nil, IDENTIFIER("rest"), nil, nil, nil, "rest"))]
      ),
      PARENTHESIS_RIGHT(")"),
      "foo"
    )
    assert_parses expected, "foo(*rest)"
  end

  test "method call with *" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      IDENTIFIER("a"),
      PARENTHESIS_LEFT("("),
      ParametersNode([], [], RestParameterNode(STAR("*"), nil), [], nil, nil),
      PARENTHESIS_RIGHT(")"),
      nil,
      Statements(
        [CallNode(
          nil,
          nil,
          IDENTIFIER("b"),
          PARENTHESIS_LEFT("("),
          ArgumentsNode([StarNode(STAR("*"), nil)]),
          PARENTHESIS_RIGHT(")"),
          "b"
         )]
      ),
      KEYWORD_END("end"),
      Scope([STAR("*")])
    )

    assert_parses expected, "def a(*); b(*); end"
  end

  test "def with identifier receiver" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      expression("a"),
      DOT("."),
      IDENTIFIER("b"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def a.b\nend"
  end

  test "def - with identifier receiver" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      expression("a"),
      DOT("."),
      MINUS("-"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def a.-;end"
  end

  test "def with local variable identifier receiver" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      IDENTIFIER("a"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "a = 1; def a\nend"
  end

  test "def with colon_colon nil receiver" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      NilNode(KEYWORD_NIL("nil")),
      COLON_COLON("::"),
      IDENTIFIER("a"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def nil::a\nend"
  end

  test "def with nil receiver" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      NilNode(KEYWORD_NIL("nil")),
      DOT("."),
      IDENTIFIER("a"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def nil.a\nend"
  end

  test "def with self receiver" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      SelfNode(KEYWORD_SELF("self")),
      DOT("."),
      IDENTIFIER("a"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def self.a\nend"
  end

  test "def with true receiver" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      TrueNode(KEYWORD_TRUE("true")),
      DOT("."),
      IDENTIFIER("a"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def true.a\nend"
  end

  test "def with false receiver" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      FalseNode(KEYWORD_FALSE("false")),
      DOT("."),
      IDENTIFIER("a"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def false.a\nend"
  end

  test "def with constant receiver" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      ConstantRead(CONSTANT("Const")),
      DOT("."),
      IDENTIFIER("a"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "Const = 1; def Const.a\nend"
  end

  test "def with instance variable receiver" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      InstanceVariableRead(INSTANCE_VARIABLE("@var")),
      DOT("."),
      IDENTIFIER("a"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def @var.a\nend"
  end

  test "def with class variable receiver" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      ClassVariableRead(CLASS_VARIABLE("@@var")),
      DOT("."),
      IDENTIFIER("a"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def @@var.a\nend"
  end

  test "def with global variable receiver" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      GlobalVariableRead(GLOBAL_VARIABLE("$var")),
      DOT("."),
      IDENTIFIER("a"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def $var.a\nend"
  end

  test "def with __FILE__ receiver" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      SourceFileNode(KEYWORD___FILE__("__FILE__")),
      DOT("."),
      IDENTIFIER("a"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def __FILE__.a\nend"
  end

  test "def with __LINE__ receiver" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      SourceLineNode(KEYWORD___LINE__("__LINE__")),
      DOT("."),
      IDENTIFIER("a"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def __LINE__.a\nend"
  end

  test "def with __ENCODING__ receiver" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      SourceEncodingNode(KEYWORD___ENCODING__("__ENCODING__")),
      DOT("."),
      IDENTIFIER("a"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def __ENCODING__.a\nend"
  end

  test "def with expression as receiver" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      ParenthesesNode(
        PARENTHESIS_LEFT("("),
        CallNode(nil, nil, IDENTIFIER("b"), nil, nil, nil, "b"),
        PARENTHESIS_RIGHT(")")
      ),
      DOT("."),
      IDENTIFIER("a"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def (b).a\nend"
  end

  test "def with assignment expression as receiver" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      ParenthesesNode(
        PARENTHESIS_LEFT("("),
        LocalVariableWrite(
          IDENTIFIER("c"),
          EQUAL("="),
          CallNode(nil, nil, IDENTIFIER("b"), nil, nil, nil, "b")
        ),
        PARENTHESIS_RIGHT(")")
      ),
      DOT("."),
      IDENTIFIER("a"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def (c = b).a\nend"
  end

  test "def with literal expression as receiver" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      ParenthesesNode(
        PARENTHESIS_LEFT("("),
        IntegerLiteral(INTEGER("1")),
        PARENTHESIS_RIGHT(")")
      ),
      DOT("."),
      IDENTIFIER("a"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def (1).a\nend"
  end

  test "def with expression as reciever and colon colon operator" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      ParenthesesNode(
        PARENTHESIS_LEFT("("),
        CallNode(nil, nil, IDENTIFIER("a"), nil, nil, nil, "a"),
        PARENTHESIS_RIGHT(")")
      ),
      COLON_COLON("::"),
      IDENTIFIER("b"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def (a)::b\nend"
  end

  test "defined? without parentheses" do
    assert_parses DefinedNode(nil, expression("1"), nil, Location(0, 8)), "defined? 1"
  end

  test "defined? with parentheses" do
    assert_parses DefinedNode(PARENTHESIS_LEFT("("), expression("1"), PARENTHESIS_RIGHT(")"), Location(0, 8)), "defined?(1)"
  end

  test "defined? binding power" do
    expected =
      AndNode(
        DefinedNode(nil, expression("1"), nil, Location(0, 8)),
        KEYWORD_AND("and"),
        DefinedNode(nil, expression("2"), nil, Location(15, 23))
      )

    assert_parses expected, "defined? 1 and defined? 2"
  end

  test "not without parentheses" do
    expected = CallNode(
      CallNode(nil, nil, IDENTIFIER("foo"), nil, nil, nil, "foo"),
      nil,
      KEYWORD_NOT("not"),
      nil,
      nil,
      nil,
      "!"
    )

    assert_parses expected, "not foo"
  end

  test "not with parentheses" do
    expected = CallNode(
      CallNode(nil, nil, IDENTIFIER("foo"), nil, nil, nil, "foo"),
      nil,
      KEYWORD_NOT("not"),
      PARENTHESIS_LEFT("("),
      nil,
      PARENTHESIS_RIGHT(")"),
      "!"
    )

    assert_parses expected, "not(foo)"
  end

  test "not binding power" do
    expected =
      AndNode(
        CallNode(
          CallNode(nil, nil, IDENTIFIER("foo"), nil, nil, nil, "foo"),
          nil,
          KEYWORD_NOT("not"),
          nil,
          nil,
          nil,
          "!"
        ),
        KEYWORD_AND("and"),
        CallNode(
          CallNode(nil, nil, IDENTIFIER("bar"), nil, nil, nil, "bar"),
          nil,
          KEYWORD_NOT("not"),
          nil,
          nil,
          nil,
          "!"
        )
      )

    assert_parses expected, "not foo and not bar"
  end

  test "false" do
    assert_parses FalseNode(KEYWORD_FALSE("false")), "false"
  end

  test "float" do
    assert_parses FloatLiteral(FLOAT("1.0")), "1.0"
  end

  test "global variable read" do
    assert_parses GlobalVariableRead(GLOBAL_VARIABLE("$abc")), "$abc"
  end

  test "global variable write" do
    assert_parses GlobalVariableWrite(GLOBAL_VARIABLE("$abc"), EQUAL("="), expression("1")), "$abc = 1"
  end

  test "identifier" do
    assert_parses CallNode(nil, nil, IDENTIFIER("a"), nil, nil, nil, "a"), "a"
  end

  test "if" do
    assert_parses IfNode(KEYWORD_IF("if"), expression("true"), Statements([expression("1")]), nil, KEYWORD_END("end")), "if true; 1; end"
  end

  test "if modifier" do
    assert_parses IfNode(KEYWORD_IF("if"), expression("true"), Statements([expression("1")]), nil, nil), "1 if true"
  end

  test "if else" do
    expected = IfNode(
      KEYWORD_IF("if"),
      expression("true"),
      Statements([expression("1")]),
      ElseNode(
        KEYWORD_ELSE("else"),
        Statements([expression("2")]),
        KEYWORD_END("end")
      ),
      KEYWORD_END("end")
    )

    assert_parses expected, "if true\n1 else 2 end"
  end

  test "if elsif" do
    expected = IfNode(
      KEYWORD_IF("if"),
      TrueNode(KEYWORD_TRUE("true")),
      Statements([TrueNode(KEYWORD_TRUE("true"))]),
      IfNode(
        KEYWORD_ELSIF("elsif"),
        FalseNode(KEYWORD_FALSE("false")),
        Statements([FalseNode(KEYWORD_FALSE("false"))]),
        IfNode(
          KEYWORD_ELSIF("elsif"),
          NilNode(KEYWORD_NIL("nil")),
          Statements([NilNode(KEYWORD_NIL("nil"))]),
          ElseNode(
            KEYWORD_ELSE("else"),
            Statements([SelfNode(KEYWORD_SELF("self"))]),
            KEYWORD_END("end")
          ),
          nil
        ),
        nil
      ),
      KEYWORD_END("end")
    )

    assert_parses expected, "if true then true elsif false then false elsif nil then nil else self end"
  end

  test "imaginary" do
    assert_parses ImaginaryLiteral(IMAGINARY_NUMBER("1i")), "1i"
  end

  test "instance variable read" do
    assert_parses InstanceVariableRead(INSTANCE_VARIABLE("@abc")), "@abc"
  end

  test "instance variable write" do
    assert_parses InstanceVariableWrite(INSTANCE_VARIABLE("@abc"), EQUAL("="), expression("1")), "@abc = 1"
  end

  test "local variable write" do
    assert_parses LocalVariableWrite(IDENTIFIER("abc"), EQUAL("="), expression("1")), "abc = 1"
  end

  test "module" do
    expected = ModuleNode(
      Scope([IDENTIFIER("a")]),
      KEYWORD_MODULE("module"),
      ConstantRead(CONSTANT("A")),
      Statements([
        LocalVariableWrite(
          IDENTIFIER("a"),
          EQUAL("="),
          IntegerLiteral(INTEGER("1"))
        )
      ]),
      KEYWORD_END("end")
    )

    assert_parses expected, "module A a = 1 end"
  end

  test "next" do
    expected = NextNode(
      KEYWORD_NEXT("next"),
      nil,
    )

    assert_parses expected, "next"
  end

  test "next 1" do
    expected = NextNode(
      KEYWORD_NEXT("next"),
      ArgumentsNode([
        expression("1"),
      ]),
    )
    assert_parses expected, "next 1"
  end

  test "next 1, 2, 3" do
    expected = NextNode(
      KEYWORD_NEXT("next"),
      ArgumentsNode([
        expression("1"),
        expression("2"),
        expression("3"),
      ]),
    )
    assert_parses expected, "next 1, 2, 3"
  end

  test "next 1, 2,\n3" do
    expected = NextNode(
      KEYWORD_NEXT("next"),
      ArgumentsNode([
        expression("1"),
        expression("2"),
        expression("3"),
      ]),
    )
    assert_parses expected, "next 1, 2,\n3"
  end

  test "next()" do
    expected = NextNode(
      KEYWORD_NEXT("next"),
      ArgumentsNode([
        expression("()"),
      ]),
    )
    assert_parses expected, "next()"
  end

  test "next(1)" do
    expected = NextNode(
      KEYWORD_NEXT("next"),
      ArgumentsNode([
        expression("(1)"),
      ]),
    )

    assert_parses expected, "next(1)"
  end

  test "next (1), (2), (3)" do
    expected = NextNode(
      KEYWORD_NEXT("next"),
      ArgumentsNode([
        expression("(1)"),
        expression("(2)"),
        expression("(3)"),
      ]),
    )
    assert_parses expected, "next (1), (2), (3)"
  end

  test "next [1, 2, 3]" do
    expected = NextNode(
      KEYWORD_NEXT("next"),
      ArgumentsNode([
        expression("[1, 2, 3]"),
      ]),
    )
    assert_parses expected, "next [1, 2, 3]"
  end

  test "next multiple statements inside of parentheses" do
    expected = NextNode(
      KEYWORD_NEXT("next"),
      ArgumentsNode([
        ParenthesesNode(
          PARENTHESIS_LEFT("("),
          Statements([expression("1"), expression("2")]),
          PARENTHESIS_RIGHT(")")
        )
      ])
    )

    assert_parses expected, <<~RUBY
      next(
        1
        2
      )
    RUBY
  end

  test "nil" do
    assert_parses NilNode(KEYWORD_NIL("nil")), "nil"
  end

  test "or keyword" do
    assert_parses OrNode(expression("1"), KEYWORD_OR("or"), expression("2")), "1 or 2"
  end

  test "or operator" do
    assert_parses OrNode(expression("1"), PIPE_PIPE("||"), expression("2")), "1 || 2"
  end

  test "operator and assignment" do
    assert_parses OperatorAndAssignmentNode(expression("a"), AMPERSAND_AMPERSAND_EQUAL("&&="), expression("b")), "a &&= b"
  end

  test "operator or assignment" do
    assert_parses OperatorOrAssignmentNode(expression("a"), PIPE_PIPE_EQUAL("||="), expression("b")), "a ||= b"
  end

  test "operator assignment" do
    assert_parses OperatorAssignmentNode(expression("a"), PLUS_EQUAL("+="), expression("b")), "a += b"
  end

  test "post execution" do
    assert_parses PostExecutionNode(KEYWORD_END_UPCASE("END"), BRACE_LEFT("{"), Statements([expression("1")]), BRACE_RIGHT("}")), "END { 1 }"
  end

  test "pre execution" do
    assert_parses PreExecutionNode(KEYWORD_BEGIN_UPCASE("BEGIN"), BRACE_LEFT("{"), Statements([expression("1")]), BRACE_RIGHT("}")), "BEGIN { 1 }"
  end

  test "range inclusive" do
    assert_parses RangeNode(expression("1"), DOT_DOT(".."), expression("2")), "1..2"
  end

  test "range exclusive" do
    assert_parses RangeNode(expression("1"), DOT_DOT_DOT("..."), expression("2")), "1...2"
  end

  test "rational" do
    assert_parses RationalLiteral(RATIONAL_NUMBER("1r")), "1r"
  end

  test "redo" do
    assert_parses RedoNode(KEYWORD_REDO("redo")), "redo"
  end

  test "xstring, `, no interpolation" do
    assert_parses XStringNode(BACKTICK("`"), STRING_CONTENT("foo"), STRING_END("`")), "`foo`"
  end

  test "xstring with interpolation" do
    expected = InterpolatedXStringNode(
      BACKTICK("`"),
      [
        StringNode(nil, STRING_CONTENT("foo "), nil, "foo "),
        StringInterpolatedNode(
          EMBEXPR_BEGIN("\#{"),
          Statements([expression("bar")]),
          EMBEXPR_END("}")
        ),
       StringNode(nil, STRING_CONTENT(" baz"), nil, " baz")
      ],
      STRING_END("`")
    )

    assert_parses expected, "`foo \#{bar} baz`"
  end

  test "xstring with %x" do
    assert_parses XStringNode(PERCENT_LOWER_X("%x["), STRING_CONTENT("foo"), STRING_END("]")), "%x[foo]"
  end

  test "regular expression, /, no interpolation" do
    assert_parses RegularExpressionNode(REGEXP_BEGIN("/"), STRING_CONTENT("abc"), REGEXP_END("/i")), "/abc/i"
  end

  test "regular expression with interpolation" do
    expected = InterpolatedRegularExpressionNode(
      REGEXP_BEGIN("/"),
      [
        StringNode(nil, STRING_CONTENT("aaa "), nil, "aaa "),
        StringInterpolatedNode(
          EMBEXPR_BEGIN("\#{"),
          Statements([expression("bbb")]),
          EMBEXPR_END("}")
        ),
       StringNode(nil, STRING_CONTENT(" ccc"), nil, " ccc")
      ],
      REGEXP_END("/")
    )

    assert_parses expected, "/aaa \#{bbb} ccc/"
  end

  test "regular expression with interpolated variable" do
    expected = InterpolatedRegularExpressionNode(
      REGEXP_BEGIN("/"),
      [
        StringNode(nil, STRING_CONTENT("aaa "), nil, "aaa "),
        expression("$bbb")
      ],
      REGEXP_END("/")
    )

    assert_parses expected, "/aaa \#$bbb/"
  end

  test "regular expression with %r" do
    assert_parses RegularExpressionNode(REGEXP_BEGIN("%r{"), STRING_CONTENT("abc"), REGEXP_END("}i")), "%r{abc}i"
  end

  test "regular expression with named capture groups" do
    expected = ArrayNode(
      BRACKET_LEFT("["),
      [
        CallNode(
          RegularExpressionNode(
            REGEXP_BEGIN("/"),
            STRING_CONTENT("(?<foo>bar)"),
            REGEXP_END("/")
          ),
          nil,
          EQUAL_TILDE("=~"),
          nil,
          ArgumentsNode([expression("baz")]),
          nil,
          "=~"
        ),
        # This is the important bit of the test here, that this is a local
        # variable and not a method call.
        LocalVariableRead(IDENTIFIER("foo"))
      ],
      BRACKET_RIGHT("]")
    )

    assert_parses expected, "[/(?<foo>bar)/ =~ baz, foo]"
  end

  test "retry" do
    assert_parses RetryNode(KEYWORD_RETRY("retry")), "retry"
  end

  test "return" do
    expected = ReturnNode(
      KEYWORD_RETURN("return"),
      nil,
    )

    assert_parses expected, "return"
  end

  test "return 1" do
    expected = ReturnNode(
      KEYWORD_RETURN("return"),
      ArgumentsNode([
        expression("1"),
      ]),
    )
    assert_parses expected, "return 1"
  end

  test "return 1, 2, 3" do
    expected = ReturnNode(
      KEYWORD_RETURN("return"),
      ArgumentsNode([
        expression("1"),
        expression("2"),
        expression("3"),
      ]),
    )
    assert_parses expected, "return 1, 2, 3"
  end

  test "return 1, 2,\n3" do
    expected = ReturnNode(
      KEYWORD_RETURN("return"),
      ArgumentsNode([
        expression("1"),
        expression("2"),
        expression("3"),
      ]),
    )
    assert_parses expected, "return 1, 2,\n3"
  end

  test "return()" do
    expected = ReturnNode(
      KEYWORD_RETURN("return"),
      ArgumentsNode([
        expression("()"),
      ]),
    )
    assert_parses expected, "return()"
  end

  test "return(1)" do
    expected = ReturnNode(
      KEYWORD_RETURN("return"),
      ArgumentsNode([
        expression("(1)"),
      ]),
    )

    assert_parses expected, "return(1)"
  end

  test "return (1), (2), (3)" do
    expected = ReturnNode(
      KEYWORD_RETURN("return"),
      ArgumentsNode([
        expression("(1)"),
        expression("(2)"),
        expression("(3)"),
      ]),
    )
    assert_parses expected, "return (1), (2), (3)"
  end

  test "return [1, 2, 3]" do
    expected = ReturnNode(
      KEYWORD_RETURN("return"),
      ArgumentsNode([expression("[1, 2, 3]")])
    )

    assert_parses expected, "return [1, 2, 3]"
  end

  test "return multiple statements inside of parentheses" do
    expected = ReturnNode(
      KEYWORD_RETURN("return"),
      ArgumentsNode([
        ParenthesesNode(
          PARENTHESIS_LEFT("("),
          Statements([expression("1"), expression("2")]),
          PARENTHESIS_RIGHT(")")
        )
      ])
    )

    assert_parses expected, <<~RUBY
      return(
        1
        2
      )
    RUBY
  end

  test "self" do
    assert_parses SelfNode(KEYWORD_SELF("self")), "self"
  end

  test "source encoding" do
    assert_parses SourceEncodingNode(KEYWORD___ENCODING__("__ENCODING__")), "__ENCODING__"
  end

  test "source file" do
    assert_parses SourceFileNode(KEYWORD___FILE__("__FILE__")), "__FILE__"
  end

  test "source line" do
    assert_parses SourceLineNode(KEYWORD___LINE__("__LINE__")), "__LINE__"
  end

  test "string empty" do
    assert_parses StringNode(STRING_BEGIN("'"), STRING_CONTENT(""), STRING_END("'"), ""), "''"
  end

  test "string interpolation disallowed" do
    assert_parses StringNode(STRING_BEGIN("'"), STRING_CONTENT("abc"), STRING_END("'"), "abc"), "'abc'"
  end

  test "%q string interpolation disallowed" do
    assert_parses StringNode(STRING_BEGIN("%q{"), STRING_CONTENT("abc"), STRING_END("}"), "abc"), "%q{abc}"
  end

  test "string interpolation allowed, but not used" do
    assert_parses StringNode(STRING_BEGIN("\""), STRING_CONTENT("abc"), STRING_END("\""), "abc"), "\"abc\""
  end

  test "%Q string interpolation allowed, but not used" do
    expected = StringNode(
      STRING_BEGIN("%Q{"),
      STRING_CONTENT("abc"),
      STRING_END("}"),
      "abc"
    )

    assert_parses expected, "%Q{abc}"
  end

  test "% string interpolation allowed, but not used" do
    expected = StringNode(
      STRING_BEGIN("%{"),
      STRING_CONTENT("abc"),
      STRING_END("}"),
      "abc"
    )

    assert_parses expected, "%{abc}"
  end

  test "string interpolation allowed, sed" do
    expected = InterpolatedStringNode(
      STRING_BEGIN("\""),
      [
        StringNode(nil, STRING_CONTENT("aaa "), nil, "aaa "),
        StringInterpolatedNode(
          EMBEXPR_BEGIN("\#{"),
          Statements([CallNode(nil, nil, IDENTIFIER("bbb"), nil, nil, nil, "bbb")]),
          EMBEXPR_END("}")
        ),
        StringNode(nil, STRING_CONTENT(" ccc"), nil, " ccc")
      ],
      STRING_END("\"")
    )

    assert_parses expected, "\"aaa \#{bbb} ccc\""
  end

  test "string interpolation allowed, not actually interpolated" do
    assert_parses StringNode(STRING_BEGIN("\""), STRING_CONTENT("\#@---"), STRING_END("\""), "\#@---"), "\"#@---\""
  end

  test "%Q string interpolation allowed, sed" do
    expected = InterpolatedStringNode(
      STRING_BEGIN("%Q{"),
      [
        StringNode(nil, STRING_CONTENT("aaa "), nil, "aaa "),
        StringInterpolatedNode(
          EMBEXPR_BEGIN("\#{"),
          Statements([CallNode(nil, nil, IDENTIFIER("bbb"), nil, nil, nil, "bbb")]),
          EMBEXPR_END("}")
        ),
        StringNode(nil, STRING_CONTENT(" ccc"), nil, " ccc")
      ],
      STRING_END("}")
    )

    assert_parses expected, "%Q{aaa \#{bbb} ccc}"
  end

  test "% string interpolation allowed, sed" do
    expected = InterpolatedStringNode(
      STRING_BEGIN("%{"),
      [
        StringNode(nil, STRING_CONTENT("aaa "), nil, "aaa "),
        StringInterpolatedNode(
          EMBEXPR_BEGIN("\#{"),
          Statements([CallNode(nil, nil, IDENTIFIER("bbb"), nil, nil, nil, "bbb")]),
          EMBEXPR_END("}")
        ),
        StringNode(nil, STRING_CONTENT(" ccc"), nil, " ccc")
      ],
      STRING_END("}")
    )

    assert_parses expected, "%{aaa \#{bbb} ccc}"
  end

  test "% string with any non-closing token" do
    %w[! @ $ % ^ & * _ + - | : ; " ' , . ~ ? / ` # \\].each do |token|
      expected = StringNode(
        STRING_BEGIN("%#{token}"),
        STRING_CONTENT("abc"),
        STRING_END(token),
        "abc"
      )

      assert_parses expected, "%#{token}abc#{token}"
    end
  end

  test "% string with any closing token" do
    [["{", "}"], ["[", "]"], ["(", ")"]].each do |(opening, closing)|
      expected = StringNode(
        STRING_BEGIN("%#{opening}"),
        STRING_CONTENT("abc"),
        STRING_END(closing),
        "abc"
      )

      assert_parses expected, "%#{opening}abc#{closing}"
    end
  end

  test "string list" do
    expected = ArrayNode(
      PERCENT_LOWER_W("%w["),
      [
        StringNode(nil, STRING_CONTENT("a"), nil, "a"),
        StringNode(nil, STRING_CONTENT("b"), nil, "b"),
        StringNode(nil, STRING_CONTENT("c"), nil, "c")
      ],
      STRING_END("]")
    )

    assert_parses expected, "%w[a b c]"
  end

  test "string list with interpolation allowed but not used" do
    expected = ArrayNode(
      PERCENT_UPPER_W("%W["),
      [
        StringNode(nil, STRING_CONTENT("a"), nil, "a"),
        StringNode(nil, STRING_CONTENT("b"), nil, "b"),
        StringNode(nil, STRING_CONTENT("c"), nil, "c")
      ],
      STRING_END("]")
    )

    assert_parses expected, "%W[a b c]"
  end

  test "string list with interpolation allowed and used" do
    expected = ArrayNode(
      PERCENT_UPPER_W("%W["),
      [
        StringNode(nil, STRING_CONTENT("a"), nil, "a"),
        InterpolatedStringNode(
          nil,
          [
            StringNode(nil, STRING_CONTENT("b"), nil, "b"),
            StringInterpolatedNode(
              EMBEXPR_BEGIN("\#{"),
              Statements([expression("c")]),
              EMBEXPR_END("}")
            ),
            StringNode(nil, STRING_CONTENT("d"), nil, "d")
          ],
          nil
        ),
        StringNode(nil, STRING_CONTENT("e"), nil, "e")
      ],
      STRING_END("]")
    )

    assert_parses expected, "%W[a b\#{c}d e]"
  end

  test "string with \\ escapes" do
    assert_parses StringNode(STRING_BEGIN("'"), STRING_CONTENT("\\\\ foo \\\\ bar"), STRING_END("'"), "\\ foo \\ bar"), "'\\\\ foo \\\\ bar'"
  end

  test "string with ' escapes" do
    assert_parses StringNode(STRING_BEGIN("'"), STRING_CONTENT("\\' foo \\' bar"), STRING_END("'"), "' foo ' bar"), "'\\' foo \\' bar'"
  end

  test "string with octal escapes" do
    assert_parses StringNode(STRING_BEGIN("\""), STRING_CONTENT("\\7 \\43 \\141"), STRING_END("\""), "\a # a"), "\"\\7 \\43 \\141\""
  end

  test "string with hexadecimal escapes" do
    assert_parses StringNode(STRING_BEGIN("\""), STRING_CONTENT("\\x7 \\x23 \\x61"), STRING_END("\""), "\a # a"), "\"\\x7 \\x23 \\x61\""
  end

  test "string with embedded global variables" do
    expected = InterpolatedStringNode(STRING_BEGIN("\""), [expression("$foo")], STRING_END("\""))
    assert_parses expected, "\"\#$foo\""
  end

  test "string with embedded instance variables" do
    expected = InterpolatedStringNode(STRING_BEGIN("\""), [expression("@foo")], STRING_END("\""))
    assert_parses expected, "\"\#@foo\""
  end

  test "string with embedded class variables" do
    expected = InterpolatedStringNode(STRING_BEGIN("\""), [expression("@@foo")], STRING_END("\""))
    assert_parses expected, "\"\#@@foo\""
  end

  test "super" do
    assert_parses ForwardingSuperNode(KEYWORD_SUPER("super")), "super"
  end

  test "super()" do
    assert_parses SuperNode(KEYWORD_SUPER("super"), PARENTHESIS_LEFT("("), nil, PARENTHESIS_RIGHT(")")), "super()"
  end

  test "super(1)" do
    assert_parses SuperNode(KEYWORD_SUPER("super"), PARENTHESIS_LEFT("("), ArgumentsNode([expression("1")]), PARENTHESIS_RIGHT(")")), "super(1)"
  end

  test "super(1, 2, 3)" do
    assert_parses SuperNode(KEYWORD_SUPER("super"), PARENTHESIS_LEFT("("), ArgumentsNode([expression("1"), expression("2"), expression("3")]), PARENTHESIS_RIGHT(")")), "super(1, 2, 3)"
  end

  test "symbol" do
    assert_parses SymbolNode(SYMBOL_BEGIN(":"), IDENTIFIER("a"), nil), ":a"
  end

  test "symbol with keyword" do
    assert_parses SymbolNode(SYMBOL_BEGIN(":"), KEYWORD_DO("do"), nil), ":do"
  end

  test "symbol with instance variable" do
    assert_parses SymbolNode(SYMBOL_BEGIN(":"), INSTANCE_VARIABLE("@a"), nil), ":@a"
  end

  test "symbol with class variable" do
    assert_parses SymbolNode(SYMBOL_BEGIN(":"), CLASS_VARIABLE("@@a"), nil), ":@@a"
  end

  test "symbol with global variable" do
    assert_parses SymbolNode(SYMBOL_BEGIN(":"), GLOBAL_VARIABLE("$a"), nil), ":$a"
  end

  test "symbol with operators" do
    operators = {
      "&" => :AMPERSAND,
      "`" => :BACKTICK,
      "!@" => :BANG_AT,
      "!~" => :BANG_TILDE,
      "!" => :BANG,
      "[]" => :BRACKET_LEFT_RIGHT,
      "[]=" => :BRACKET_LEFT_RIGHT_EQUAL,
      "^" => :CARET,
      "==" => :EQUAL_EQUAL,
      "===" => :EQUAL_EQUAL_EQUAL,
      "=~" => :EQUAL_TILDE,
      ">=" => :GREATER_EQUAL,
      ">>" => :GREATER_GREATER,
      ">" => :GREATER,
      "<=>" => :LESS_EQUAL_GREATER,
      "<=" => :LESS_EQUAL,
      "<<" => :LESS_LESS,
      "<" => :LESS,
      "-@" => :MINUS_AT,
      "-" => :MINUS,
      "%" => :PERCENT,
      "|" => :PIPE,
      "+@" => :PLUS_AT,
      "+" => :PLUS,
      "/" => :SLASH,
      "**" => :STAR_STAR,
      "*" => :STAR,
      "~@" => :TILDE_AT,
      "~" => :TILDE
    }

    operators.each do |operator, method_name|
      contents = method(method_name).call(operator)
      assert_parses SymbolNode(SYMBOL_BEGIN(":"), contents, nil), ":#{operator}"
    end
  end

  test "symbol list" do
    expected = ArrayNode(
      PERCENT_LOWER_I("%i["),
      [
        SymbolNode(nil, STRING_CONTENT("a"), nil),
        SymbolNode(nil, STRING_CONTENT("b"), nil),
        SymbolNode(nil, STRING_CONTENT("c"), nil)
      ],
      STRING_END("]")
    )

    assert_parses expected, "%i[a b c]"
  end

  test "symbol list with ignored interpolation" do
    expected = ArrayNode(
      PERCENT_LOWER_I("%i["),
      [SymbolNode(nil, STRING_CONTENT("a"), nil),
       SymbolNode(nil, STRING_CONTENT("b\#{1}"), nil),
       SymbolNode(nil, STRING_CONTENT("\#{2}c"), nil),
       SymbolNode(nil, STRING_CONTENT("d\#{3}f"), nil)],
      STRING_END("]")
    )

    assert_parses expected, "%i[a b\#{1} \#{2}c d\#{3}f]"
  end

  test "symbol list with interpreted interpolation" do
    expected = ArrayNode(
      PERCENT_UPPER_I("%I["),
      [SymbolNode(nil, STRING_CONTENT("a"), nil),
       InterpolatedSymbolNode(
         nil,
         [SymbolNode(nil, STRING_CONTENT("b"), nil),
          StringInterpolatedNode(
            EMBEXPR_BEGIN("\#{"),
            Statements([IntegerLiteral(INTEGER("1"))]),
            EMBEXPR_END("}")
          )],
         nil
       ),
       InterpolatedSymbolNode(
         nil,
         [StringInterpolatedNode(
            EMBEXPR_BEGIN("\#{"),
            Statements([IntegerLiteral(INTEGER("2"))]),
            EMBEXPR_END("}")
          ),
          SymbolNode(nil, STRING_CONTENT("c"), nil)],
         nil
       ),
       InterpolatedSymbolNode(
         nil,
         [SymbolNode(nil, STRING_CONTENT("d"), nil),
          StringInterpolatedNode(
            EMBEXPR_BEGIN("\#{"),
            Statements([IntegerLiteral(INTEGER("3"))]),
            EMBEXPR_END("}")
          ),
          SymbolNode(nil, STRING_CONTENT("f"), nil)],
         nil
       )],
      STRING_END("]")
    )

    assert_parses expected, "%I[a b\#{1} \#{2}c d\#{3}f]"
  end

  test "dynamic symbol" do
    expected = SymbolNode(SYMBOL_BEGIN(":'"), STRING_CONTENT("abc"), STRING_END("'"))
    assert_parses expected, ":'abc'"
  end

  test "dynamic symbol with interpolation" do
    expected = InterpolatedSymbolNode(
      SYMBOL_BEGIN(":\""),
      [StringNode(nil, STRING_CONTENT("abc"), nil, "abc"),
       StringInterpolatedNode(
         EMBEXPR_BEGIN("\#{"),
         Statements([expression("1")]),
         EMBEXPR_END("}")
       )],
      STRING_END("\"")
    )
    assert_parses expected, ":\"abc\#{1}\""
  end

  test "alias with dynamic symbol" do
    expected = AliasNode(
      KEYWORD_ALIAS("alias"),
      SymbolNode(SYMBOL_BEGIN(":'"), STRING_CONTENT("abc"), STRING_END("'")),
      SymbolNode(SYMBOL_BEGIN(":'"), STRING_CONTENT("def"), STRING_END("'"))
    )
    assert_parses expected, "alias :'abc' :'def'"
  end

  test "alias with dynamic symbol with interpolation" do
    expected = AliasNode(
      KEYWORD_ALIAS("alias"),
      InterpolatedSymbolNode(
        SYMBOL_BEGIN(":\""),
        [StringNode(nil, STRING_CONTENT("abc"), nil, "abc"),
         StringInterpolatedNode(
           EMBEXPR_BEGIN("\#{"),
           Statements([expression("1")]),
           EMBEXPR_END("}")
         )],
        STRING_END("\"")
      ),
      SymbolNode(SYMBOL_BEGIN(":'"), STRING_CONTENT("def"), STRING_END("'"))
    )
    assert_parses expected, "alias :\"abc\#{1}\" :'def'"
  end

  test "undef with dynamic symbols" do
    expected = UndefNode(
      KEYWORD_UNDEF("undef"),
      [SymbolNode(SYMBOL_BEGIN(":'"), STRING_CONTENT("abc"), STRING_END("'"))]
    )
    assert_parses expected, "undef :'abc'"
  end

  test "undef with dynamic symbols with interpolation" do
    expected = UndefNode(
      KEYWORD_UNDEF("undef"),
      [InterpolatedSymbolNode(
         SYMBOL_BEGIN(":\""),
         [StringNode(nil, STRING_CONTENT("abc"), nil, "abc"),
          StringInterpolatedNode(
            EMBEXPR_BEGIN("\#{"),
            Statements([expression("1")]),
            EMBEXPR_END("}")
          )],
         STRING_END("\"")
       )]
    )
    assert_parses expected, "undef :\"abc\#{1}\""
  end

  test "%s symbol" do
    expected = SymbolNode(SYMBOL_BEGIN("%s["), STRING_CONTENT("abc"), STRING_END("]"))
    assert_parses expected, "%s[abc]"
  end

  test "alias with %s symbol" do
    expected = AliasNode(
      KEYWORD_ALIAS("alias"),
      SymbolNode(SYMBOL_BEGIN("%s["), STRING_CONTENT("abc"), STRING_END("]")),
      SymbolNode(SYMBOL_BEGIN("%s["), STRING_CONTENT("def"), STRING_END("]"))
    )
    assert_parses expected, "alias %s[abc] %s[def]"
  end

  test "ternary" do
    expected = Ternary(
      CallNode(nil, nil, IDENTIFIER("a"), nil, nil, nil, "a"),
      QUESTION_MARK("?"),
      CallNode(nil, nil, IDENTIFIER("b"), nil, nil, nil, "b"),
      COLON(":"),
      CallNode(nil, nil, IDENTIFIER("c"), nil, nil, nil, "c")
    )

    assert_parses expected, "a ? b : c"
  end

  test "true" do
    assert_parses TrueNode(KEYWORD_TRUE("true")), "true"
  end

  test "unary !" do
    assert_parses CallNode(expression("1"), nil, BANG("!"), nil, nil, nil, "!"), "!1"
  end

  test "unary -" do
    assert_parses CallNode(expression("1"), nil, MINUS("-"), nil, nil, nil, "-@"), "-1"
  end

  test "unary ~" do
    assert_parses CallNode(expression("1"), nil, TILDE("~"), nil, nil, nil, "~"), "~1"
  end

  test "undef bare" do
    assert_parses UndefNode(KEYWORD_UNDEF("undef"), [SymbolNode(nil, IDENTIFIER("a"), nil)]), "undef a"
  end

  test "undef bare, multiple" do
    assert_parses UndefNode(KEYWORD_UNDEF("undef"), [SymbolNode(nil, IDENTIFIER("a"), nil), SymbolNode(nil, IDENTIFIER("b"), nil)]), "undef a, b"
  end

  test "undef symbol" do
    assert_parses UndefNode(KEYWORD_UNDEF("undef"), [SymbolNode(SYMBOL_BEGIN(":"), IDENTIFIER("a"), nil)]), "undef :a"
  end

  test "undef symbol, multiple" do
    expected = UndefNode(
      KEYWORD_UNDEF("undef"),
      [
        SymbolNode(SYMBOL_BEGIN(":"), IDENTIFIER("a"), nil),
        SymbolNode(SYMBOL_BEGIN(":"), IDENTIFIER("b"), nil),
        SymbolNode(SYMBOL_BEGIN(":"), IDENTIFIER("c"), nil)
      ]
    )

    assert_parses expected, "undef :a, :b, :c"
  end

  test "unless" do
    assert_parses UnlessNode(KEYWORD_UNLESS("unless"), expression("true"), Statements([expression("1")]), nil, KEYWORD_END("end")), "unless true; 1; end"
  end

  test "unless modifier" do
    assert_parses UnlessNode(KEYWORD_UNLESS("unless"), expression("true"), Statements([expression("1")]), nil, nil), "1 unless true"
  end

  test "unless else" do
    expected = UnlessNode(
      KEYWORD_UNLESS("unless"),
      expression("true"),
      Statements([expression("1")]),
      ElseNode(
        KEYWORD_ELSE("else"),
        Statements([expression("2")]),
        KEYWORD_END("end")
      ),
      KEYWORD_END("end")
    )

    assert_parses expected, "unless true\n1 else 2 end"
  end

  test "unless elsif" do
    expected = UnlessNode(
      KEYWORD_UNLESS("unless"),
      TrueNode(KEYWORD_TRUE("true")),
      Statements([TrueNode(KEYWORD_TRUE("true"))]),
      IfNode(
        KEYWORD_ELSIF("elsif"),
        FalseNode(KEYWORD_FALSE("false")),
        Statements([FalseNode(KEYWORD_FALSE("false"))]),
        IfNode(
          KEYWORD_ELSIF("elsif"),
          NilNode(KEYWORD_NIL("nil")),
          Statements([NilNode(KEYWORD_NIL("nil"))]),
          ElseNode(
            KEYWORD_ELSE("else"),
            Statements([SelfNode(KEYWORD_SELF("self"))]),
            KEYWORD_END("end")
          ),
          nil
        ),
        nil
      ),
      KEYWORD_END("end")
    )

    assert_parses expected, "unless true then true elsif false then false elsif nil then nil else self end"
  end

  test "until" do
    assert_parses UntilNode(KEYWORD_UNTIL("until"), expression("true"), Statements([expression("1")])), "until true; 1; end"
  end

  test "until modifier" do
    assert_parses UntilNode(KEYWORD_UNTIL("until"), expression("true"), Statements([expression("1")])), "1 until true"
  end

  test "while" do
    assert_parses WhileNode(KEYWORD_WHILE("while"), expression("true"), Statements([expression("1")])), "while true; 1; end"
  end

  test "while modifier" do
    assert_parses WhileNode(KEYWORD_WHILE("while"), expression("true"), Statements([expression("1")])), "1 while true"
  end

  test "yield" do
    assert_parses YieldNode(KEYWORD_YIELD("yield"), nil, nil, nil), "yield"
  end

  test "yield()" do
    assert_parses YieldNode(KEYWORD_YIELD("yield"), PARENTHESIS_LEFT("("), nil, PARENTHESIS_RIGHT(")")), "yield()"
  end

  test "yield(1)" do
    assert_parses YieldNode(KEYWORD_YIELD("yield"), PARENTHESIS_LEFT("("), ArgumentsNode([expression("1")]), PARENTHESIS_RIGHT(")")), "yield(1)"
  end

  test "yield(1, 2, 3)" do
    assert_parses YieldNode(KEYWORD_YIELD("yield"), PARENTHESIS_LEFT("("), ArgumentsNode([expression("1"), expression("2"), expression("3")]), PARENTHESIS_RIGHT(")")), "yield(1, 2, 3)"
  end

  test "TERM < FACTOR" do
    expected = CallNode(
      expression("1"),
      nil,
      PLUS("+"),
      nil,
      ArgumentsNode([
        CallNode(expression("2"), nil, STAR("*"), nil, ArgumentsNode([expression("3")]), nil, "*")
      ]),
      nil,
      "+"
    )

    assert_parses expected, "1 + 2 * 3"
  end

  test "FACTOR < EXPONENT" do
    expected = CallNode(
      expression("1"),
      nil,
      STAR("*"),
      nil,
      ArgumentsNode([
        CallNode(expression("2"), nil, STAR_STAR("**"), nil, ArgumentsNode([expression("3")]), nil, "**")
      ]),
      nil,
      "*"
    )

    assert_parses expected, "1 * 2 ** 3"
  end

  test "FACTOR > TERM" do
    expected = CallNode(
      CallNode(expression("1"), nil, STAR("*"), nil, ArgumentsNode([expression("2")]), nil, "*"),
      nil,
      PLUS("+"),
      nil,
      ArgumentsNode([expression("3")]),
      nil,
      "+"
    )

    assert_parses expected, "1 * 2 + 3"
  end

  test "MODIFIER left associativity" do
    expected = IfNode(
      KEYWORD_IF("if"),
      expression("c"),
      Statements([IfNode(KEYWORD_IF("if"), expression("b"), Statements([expression("a")]), nil, nil)]),
      nil,
      nil
    )

    assert_parses expected, "a if b if c"
  end

  test "begin statements" do
    expected = BeginNode(
      KEYWORD_BEGIN("begin"),
      Statements([expression("a")]),
      nil,
      nil,
      nil,
      KEYWORD_END("end"),
    )

    assert_parses expected, "begin\na\nend"
    assert_parses expected, "begin; a; end"
    assert_parses expected, "begin a\n end"
    assert_parses expected, "begin a; end"
  end


  test "begin rescue, else" do
    expected = BeginNode(
      KEYWORD_BEGIN("begin"),
      Statements([CallNode(nil, nil, IDENTIFIER("a"), nil, nil, nil, "a")]),
      RescueNode(
        KEYWORD_RESCUE("rescue"),
        [],
        nil,
        nil,
        Statements([CallNode(nil, nil, IDENTIFIER("b"), nil, nil, nil, "b")]),
        nil
      ),
      ElseNode(
        KEYWORD_ELSE("else"),
        Statements([CallNode(nil, nil, IDENTIFIER("c"), nil, nil, nil, "c")]),
        SEMICOLON(";")
      ),
      nil,
      KEYWORD_END("end")
    )

    assert_parses expected, "begin; a; rescue; b; else; c; end"
  end

  test "begin rescue, else and ensure" do
    expected = BeginNode(
      KEYWORD_BEGIN("begin"),
      Statements([CallNode(nil, nil, IDENTIFIER("a"), nil, nil, nil, "a")]),
      RescueNode(
        KEYWORD_RESCUE("rescue"),
        [],
        nil,
        nil,
        Statements([CallNode(nil, nil, IDENTIFIER("b"), nil, nil, nil, "b")]),
        nil
      ),
      ElseNode(
        KEYWORD_ELSE("else"),
        Statements([CallNode(nil, nil, IDENTIFIER("c"), nil, nil, nil, "c")]),
        SEMICOLON(";")
      ),
      EnsureNode(
        KEYWORD_ENSURE("ensure"),
        Statements([CallNode(nil, nil, IDENTIFIER("d"), nil, nil, nil, "d")]),
        KEYWORD_END("end")
      ),
      nil
    )

    assert_parses expected, "begin; a; rescue; b; else; c; ensure; d; end"
  end


  test "endless method definition without arguments" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      IDENTIFIER("foo"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      EQUAL("="),
      Statements([expression("123")]),
      nil,
      Scope([])
    )

    assert_parses expected, "def foo = 123"
  end

  test "endless method definition with arguments" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      IDENTIFIER("foo"),
      PARENTHESIS_LEFT("("),
      ParametersNode([RequiredParameterNode(IDENTIFIER("bar"))], [], nil, [], nil, nil),
      PARENTHESIS_RIGHT(")"),
      EQUAL("="),
      Statements([expression("123")]),
      nil,
      Scope([IDENTIFIER("bar")])
    )

    assert_parses expected, "def foo(bar) = 123"
  end

  test "singleton class defintion" do
    expected = SClassNode(
      Scope([]),
      KEYWORD_CLASS("class"),
      LESS_LESS("<<"),
      expression("self"),
      Statements([]),
      KEYWORD_END("end"),
    )

    assert_parses expected, "class << self\nend"
    assert_parses expected, "class << self;end"
  end

  test "singleton class definition with method invocation for rhs" do
    expected = SClassNode(
      Scope([]),
      KEYWORD_CLASS("class"),
      LESS_LESS("<<"),
      CallNode(
        CallNode(nil, nil, IDENTIFIER("foo"), nil, nil, nil, "foo"),
        DOT("."),
        IDENTIFIER("bar"),
        nil,
        nil,
        nil,
        "bar"
      ),
      Statements([]),
      KEYWORD_END("end"),
    )

    assert_parses expected, "class << foo.bar\nend"
    assert_parses expected, "class << foo.bar;end"
  end

  test "singleton class defintion with statement" do
    expected = SClassNode(
      Scope([]),
      KEYWORD_CLASS("class"),
      LESS_LESS("<<"),
      expression("self"),
      Statements(
        [CallNode(
          IntegerLiteral(INTEGER("1")),
          nil,
          PLUS("+"),
          nil,
          ArgumentsNode([IntegerLiteral(INTEGER("2"))]),
          nil,
          "+"
        )]
      ),
      KEYWORD_END("end"),
    )

    assert_parses expected, "class << self\n1 + 2\nend"
    assert_parses expected, "class << self;1 + 2;end"
  end

  test "for loop" do
    expected = ForNode(
      KEYWORD_FOR("for"),
      expression("i"),
      KEYWORD_IN("in"),
      expression("1..10"),
      nil,
      Statements([expression("i")]),
      KEYWORD_END("end"),
    )

    assert_parses expected, "for i in 1..10\ni\nend"
  end

  test "for loop with do keyword" do
    expected = ForNode(
      KEYWORD_FOR("for"),
      expression("i"),
      KEYWORD_IN("in"),
      expression("1..10"),
      KEYWORD_DO_LOOP("do"),
      Statements([expression("i")]),
      KEYWORD_END("end"),
    )

    assert_parses expected, "for i in 1..10 do\ni\nend"
  end

  test "for loop no newlines" do
    expected = ForNode(
      KEYWORD_FOR("for"),
      expression("i"),
      KEYWORD_IN("in"),
      expression("1..10"),
      nil,
      Statements([expression("i")]),
      KEYWORD_END("end"),
    )

    assert_parses expected, "for i in 1..10 i end"
  end

  test "for loop with semicolons" do
    expected = ForNode(
      KEYWORD_FOR("for"),
      expression("i"),
      KEYWORD_IN("in"),
      expression("1..10"),
      nil,
      Statements([expression("i")]),
      KEYWORD_END("end"),
    )

    assert_parses expected, "for i in 1..10; i; end"
  end

  test "for loop with 2 indexes" do
    expected = ForNode(
      KEYWORD_FOR("for"),
      MultiTargetNode([
        expression("i"),
        expression("j"),
      ]),
      KEYWORD_IN("in"),
      expression("1..10"),
      nil,
      Statements([expression("i")]),
      KEYWORD_END("end"),
    )

    assert_parses expected, "for i,j in 1..10\ni\nend"
  end

  test "for loop with 3 indexes" do
    expected = ForNode(
      KEYWORD_FOR("for"),
      MultiTargetNode([
        expression("i"),
        expression("j"),
        expression("k"),
      ]),
      KEYWORD_IN("in"),
      expression("1..10"),
      nil,
      Statements([expression("i")]),
      KEYWORD_END("end"),
    )

    assert_parses expected, "for i,j,k in 1..10\ni\nend"
  end

  test "rescue modifier" do
    expected = RescueModifierNode(
      CallNode(nil, nil, IDENTIFIER("foo"), nil, nil, nil, "foo"),
      KEYWORD_RESCUE("rescue"),
      NilNode(KEYWORD_NIL("nil"))
    )

    assert_parses expected, "foo rescue nil"
    assert_parses expected, "foo rescue\nnil"
  end

  test "rescue modifier within a ternary operator" do
    expected = Ternary(
      RescueModifierNode(
        CallNode(nil, nil, IDENTIFIER("foo"), nil, nil, nil, "foo"),
        KEYWORD_RESCUE("rescue"),
        NilNode(KEYWORD_NIL("nil"))
      ),
      QUESTION_MARK("?"),
      IntegerLiteral(INTEGER("1")),
      COLON(":"),
      IntegerLiteral(INTEGER("2"))
    )

    assert_parses expected, "foo rescue nil ? 1 : 2"
  end

  test "rescue modifier with logical operator" do
    expected = RescueModifierNode(
      CallNode(nil, nil, IDENTIFIER("foo"), nil, nil, nil, "foo"),
      KEYWORD_RESCUE("rescue"),
      OrNode(NilNode(KEYWORD_NIL("nil")), PIPE_PIPE("||"), IntegerLiteral(INTEGER("1")))
    )

    assert_parses expected, "foo rescue nil || 1"
  end

  test "begin with rescue statement" do
    expected = BeginNode(
      KEYWORD_BEGIN("begin"),
      Statements([expression("a")]),
      RescueNode(
        KEYWORD_RESCUE("rescue"),
        [],
        nil,
        nil,
        Statements([expression("b")]),
        nil
      ),
      nil,
      nil,
      KEYWORD_END("end"),
    )

    assert_parses expected, "begin\na\nrescue\nb\nend"
    assert_parses expected, "begin;a;rescue;b;end"
    assert_parses expected, "begin\na;rescue\nb;end"
  end

  test "begin with rescue statement and exception" do
    expected = BeginNode(
      KEYWORD_BEGIN("begin"),
      Statements([expression("a")]),
      RescueNode(
        KEYWORD_RESCUE("rescue"),
        [ConstantRead(CONSTANT("Exception"))],
        nil,
        nil,
        Statements([expression("b")]),
        nil
      ),
      nil,
      nil,
      KEYWORD_END("end"),
    )

    assert_parses expected, "begin\na\nrescue Exception\nb\nend"
  end

  test "begin with rescue statement with variable" do
    expected = BeginNode(
      KEYWORD_BEGIN("begin"),
      Statements([expression("a")]),
      RescueNode(
        KEYWORD_RESCUE("rescue"),
        [ConstantRead(CONSTANT("Exception"))],
        EQUAL_GREATER("=>"),
        IDENTIFIER("ex"),
        Statements([expression("b")]),
        nil,
      ),
      nil,
      nil,
      KEYWORD_END("end"),
    )

    assert_parses expected, "begin\na\nrescue Exception => ex\nb\nend"
  end

  test "begin with rescue statement and exception list" do
    expected = BeginNode(
      KEYWORD_BEGIN("begin"),
      Statements([expression("a")]),
      RescueNode(
        KEYWORD_RESCUE("rescue"),
        [ConstantRead(CONSTANT("Exception")), ConstantRead(CONSTANT("CustomException"))],
        nil,
        nil,
        Statements([expression("b")]),
        nil
      ),
      nil,
      nil,
      KEYWORD_END("end"),
    )

    assert_parses expected, "begin\na\nrescue Exception, CustomException\nb\nend"
  end

  test "begin with rescue statement and exception list with variable" do
    expected = BeginNode(
      KEYWORD_BEGIN("begin"),
      Statements([expression("a")]),
      RescueNode(
        KEYWORD_RESCUE("rescue"),
        [ConstantRead(CONSTANT("Exception")), ConstantRead(CONSTANT("CustomException"))],
        EQUAL_GREATER("=>"),
        IDENTIFIER("ex"),
        Statements([expression("b")]),
        nil
      ),
      nil,
      nil,
      KEYWORD_END("end"),
    )

    assert_parses expected, "begin\na\nrescue Exception, CustomException => ex\nb\nend"
  end

  test "begin with multiple rescue statements" do
    expected = BeginNode(
      KEYWORD_BEGIN("begin"),
      Statements([expression("a")]),
      RescueNode(
        KEYWORD_RESCUE("rescue"),
        [],
        nil,
        nil,
        Statements([expression("b")]),
        RescueNode(
          KEYWORD_RESCUE("rescue"),
          [],
          nil,
          nil,
          Statements([expression("c")]),
          RescueNode(
            KEYWORD_RESCUE("rescue"),
            [],
            nil,
            nil,
            Statements([expression("d")]),
            nil
          )
        )
      ),
      nil,
      nil,
      KEYWORD_END("end"),
    )

    assert_parses expected, "begin\na\nrescue\nb\nrescue\nc\nrescue\nd\nend"
  end

  test "begin with multiple rescue statements with exception classes and variables" do
    expected = BeginNode(
      KEYWORD_BEGIN("begin"),
      Statements([expression("a")]),
      RescueNode(
        KEYWORD_RESCUE("rescue"),
        [ConstantRead(CONSTANT("Exception"))],
        EQUAL_GREATER("=>"),
        IDENTIFIER("ex"),
        Statements([expression("b")]),
        RescueNode(
          KEYWORD_RESCUE("rescue"),
          [ConstantRead(CONSTANT("AnotherException")), ConstantRead(CONSTANT("OneMoreException"))],
          EQUAL_GREATER("=>"),
          IDENTIFIER("ex"),
          Statements([expression("c")]),
          nil
        )
      ),
      nil,
      nil,
      KEYWORD_END("end"),
    )

    assert_parses expected, "begin\na\nrescue Exception => ex\nb\nrescue AnotherException, OneMoreException => ex\nc\nend"
  end

  test "ensure statements" do
    expected = BeginNode(
      KEYWORD_BEGIN("begin"),
      Statements([expression("a")]),
      nil,
      nil,
      EnsureNode(
        KEYWORD_ENSURE("ensure"),
        Statements([expression("b")]),
        KEYWORD_END("end"),
      ),
      nil
    )

    assert_parses expected, "begin\na\nensure\nb\nend"
    assert_parses expected, "begin; a; ensure; b; end"
    assert_parses expected, "begin a\n ensure b\n end"
    assert_parses expected, "begin a; ensure b; end"
  end

  test "parses empty hash" do
    assert_parses HashNode(BRACE_LEFT("{"), [], BRACE_RIGHT("}")), "{}"
  end

  test "parses hash with hashrocket keys" do
    expected = HashNode(
      BRACE_LEFT("{"),
      [AssocNode(
        CallNode(nil, nil, IDENTIFIER("a"), nil, nil, nil, "a"),
        EQUAL_GREATER("=>"),
        CallNode(nil, nil, IDENTIFIER("b"), nil, nil, nil, "b")
      ),
      AssocNode(
        CallNode(nil, nil, IDENTIFIER("c"), nil, nil, nil, "c"),
        EQUAL_GREATER("=>"),
        CallNode(nil, nil, IDENTIFIER("d"), nil, nil, nil, "d")
      )],
      BRACE_RIGHT("}")
    )

    assert_parses expected, "{ a => b, c => d }"
  end

  test "hash with label keys" do
    expected = HashNode(
      BRACE_LEFT("{"),
      [
        AssocNode(SymbolNode(nil, LABEL("a"), LABEL_END(":")), nil, expression("b")),
        AssocNode(SymbolNode(nil, LABEL("c"), LABEL_END(":")), nil, expression("d")),
        AssocSplatNode(expression("e"), Location(14, 16)),
        AssocNode(SymbolNode(nil, LABEL("f"), LABEL_END(":")), nil, expression("g")),
      ],
      BRACE_RIGHT("}")
    )

    assert_parses expected, "{ a: b, c: d, **e, f: g }"
  end

  test "parses hash with splat" do
    expected = HashNode(
      BRACE_LEFT("{"),
      [AssocNode(
         CallNode(nil, nil, IDENTIFIER("a"), nil, nil, nil, "a"),
         EQUAL_GREATER("=>"),
         CallNode(nil, nil, IDENTIFIER("b"), nil, nil, nil, "b"),
       ),
       AssocSplatNode(
         CallNode(nil, nil, IDENTIFIER("c"), nil, nil, nil, "c"),
         Location(10, 12)
       )],
      BRACE_RIGHT("}")
    )

    assert_parses expected, "{ a => b, **c }"
  end

  test "parses empty hash with statements after it" do
    assert_parses HashNode(BRACE_LEFT("{"), [], BRACE_RIGHT("}")), "{\n}\n"
  end

  test "begin with rescue and ensure statements" do
    expected = BeginNode(
      KEYWORD_BEGIN("begin"),
      Statements([expression("a")]),
      RescueNode(
        KEYWORD_RESCUE("rescue"),
        [ConstantRead(CONSTANT("Exception"))],
        EQUAL_GREATER("=>"),
        IDENTIFIER("ex"),
        Statements([expression("b")]),
        nil
      ),
      nil,
      EnsureNode(
        KEYWORD_ENSURE("ensure"),
        Statements([expression("b")]),
        KEYWORD_END("end"),
      ),
      nil,
    )

    assert_parses expected, "begin\na\nrescue Exception => ex\nb\nensure\nb\nend"
  end

  test "simple #[] call" do
    expected = CallNode(
      expression("foo"),
      nil,
      BRACKET_LEFT_RIGHT(""),
      nil,
      ArgumentsNode([expression("bar")]),
      nil,
      "[]"
    )

    assert_parses expected, "foo[bar]"
  end

  test "simple #[]= call" do
    expected = CallNode(
      expression("foo"),
      nil,
      BRACKET_LEFT_RIGHT(""),
      nil,
      ArgumentsNode([expression("bar"), expression("baz")]),
      nil,
      "[]="
    )

    assert_parses expected, "foo[bar] = baz"
  end

  test "multiple arguments #[] call" do
    expected = CallNode(
      expression("foo"),
      nil,
      BRACKET_LEFT_RIGHT(""),
      nil,
      ArgumentsNode([expression("bar"), expression("baz")]),
      nil,
      "[]"
    )

    assert_parses expected, "foo[bar, baz]"
  end

  test "multiple arguments #[]= call" do
    expected = CallNode(
      expression("foo"),
      nil,
      BRACKET_LEFT_RIGHT(""),
      nil,
      ArgumentsNode([expression("bar"), expression("baz"), expression("qux")]),
      nil,
      "[]="
    )

    assert_parses expected, "foo[bar, baz] = qux"
  end

  test "chained #[] calls " do
    expected = CallNode(
      CallNode(
        expression("foo"),
        nil,
        BRACKET_LEFT_RIGHT(""),
        nil,
        ArgumentsNode([expression("bar")]),
        nil,
        "[]"
      ),
      nil,
      BRACKET_LEFT_RIGHT(""),
      nil,
      ArgumentsNode([expression("baz")]),
      nil,
      "[]"
    )

    assert_parses expected, "foo[bar][baz]"
  end

  test "chained #[] and #[]= calls " do
    expected = CallNode(
      CallNode(
        expression("foo"),
        nil,
        BRACKET_LEFT_RIGHT(""),
        nil,
        ArgumentsNode([expression("bar")]),
        nil,
        "[]"
      ),
      nil,
      BRACKET_LEFT_RIGHT(""),
      nil,
      ArgumentsNode([expression("baz"), expression("qux")]),
      nil,
      "[]="
    )

    assert_parses expected, "foo[bar][baz] = qux"
  end

  test "nested #[] and #[]= calls " do
    expected = CallNode(
      expression("foo"),
      nil,
      BRACKET_LEFT_RIGHT(""),
      nil,
      ArgumentsNode([
        CallNode(
          expression("bar"),
          nil,
          BRACKET_LEFT_RIGHT(""),
          nil,
          ArgumentsNode([expression("baz"), expression("qux")]),
          nil,
          "[]="
        ),
      ]),
      nil,
      "[]"
    )

    assert_parses expected, "foo[bar[baz] = qux]"
  end

  test "encoding magic comment" do
    assert YARP.parse("#encoding: utf-8").errors.empty?
    assert YARP.parse("#encoding: UTF-8").errors.empty?
    assert YARP.parse("# -*- encoding: UTF-8 -*-").errors.empty?
    assert YARP.parse("# -*- encoding: utf-8 -*-").errors.empty?
    refute YARP.parse("#encoding: utf8").errors.empty?
  end

  test "multiline string addition" do
    expected = CallNode(
      StringNode(
        STRING_BEGIN("\""),
        STRING_CONTENT("foo"),
        STRING_END("\""),
        "foo"
      ),
      nil,
      PLUS("+"),
      nil,
      ArgumentsNode(
        [StringNode(
           STRING_BEGIN("\""),
           STRING_CONTENT("bar"),
           STRING_END("\""),
           "bar"
         )]
      ),
      nil,
      "+"
    )

    assert_parses expected, "\"foo\" +\n\n\"bar\""
  end

  test "each block curly braces" do
    expected = CallNode(
      CallNode(nil, nil, IDENTIFIER("x"), nil, nil, nil, "x"),
      DOT("."),
      IDENTIFIER("each"),
      nil,
      ArgumentsNode([BlockNode(BRACE_LEFT("{"), nil, nil, BRACE_RIGHT("}"))]),
      nil,
      "each"
    )

    assert_parses expected, "x.each { }"
  end

  test "method call with block with one argument" do
    expected = CallNode(
      nil,
      nil,
      IDENTIFIER("foo"),
      nil,
      ArgumentsNode(
        [BlockNode(
           BRACE_LEFT("{"),
           ParametersNode(
             [RequiredParameterNode(IDENTIFIER("x"))],
             [],
             nil,
             [],
             nil,
             nil
           ),
           nil,
           BRACE_RIGHT("}")
         )]
      ),
      nil,
      "foo"
    )

    assert_parses expected, "foo { |x| }"
  end

  test "method call with block and arguments" do
    expected = CallNode(
      nil,
      nil,
      IDENTIFIER("foo"),
      nil,
      ArgumentsNode(
        [BlockNode(
           BRACE_LEFT("{"),
           ParametersNode(
             [RequiredParameterNode(IDENTIFIER("x"))],
             [OptionalParameterNode(
                IDENTIFIER("y"),
                EQUAL("="),
                IntegerLiteral(INTEGER("2"))
              )],
             nil,
             [KeywordParameterNode(LABEL("z:"), nil)],
             nil,
             nil
           ),
           Statements([LocalVariableRead(IDENTIFIER("x"))]),
           BRACE_RIGHT("}")
         )]
      ),
      nil,
      "foo"
    )

    assert_parses expected, "foo { |x, y = 2, z:| x }"
  end

  test "block with normal args before the block" do
    expected = CallNode(
      CallNode(nil, nil, IDENTIFIER("x"), nil, nil, nil, "x"),
      DOT("."),
      IDENTIFIER("reduce"),
      PARENTHESIS_LEFT("("),
      ArgumentsNode(
        [BlockNode(
           BRACE_LEFT("{"),
           ParametersNode(
             [RequiredParameterNode(IDENTIFIER("x")),
              RequiredParameterNode(IDENTIFIER("memo"))],
             [],
             nil,
             [],
             nil,
             nil
           ),
           Statements(
             [OperatorAssignmentNode(
                LocalVariableRead(IDENTIFIER("memo")),
                PLUS_EQUAL("+="),
                LocalVariableRead(IDENTIFIER("x"))
              )]
           ),
           BRACE_RIGHT("}")
         )]
      ),
      PARENTHESIS_RIGHT(")"),
      "reduce"
    )

    assert_parses expected, "x.reduce(0) { |x, memo| memo += x }"
  end

  test "def + without parentheses" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      PLUS("+"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def +\nend"
  end

  test "def + with parentheses" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      PLUS("+"),
      PARENTHESIS_LEFT("("),
      ParametersNode([], [], nil, [], nil, nil),
      PARENTHESIS_RIGHT(")"),
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def +()\nend"
  end

  test "def + with required parameter" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      PLUS("+"),
      nil,
      ParametersNode([RequiredParameterNode(IDENTIFIER("b"))], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([IDENTIFIER("b")])
    )

    assert_parses expected, "def + b\nend"
  end

  test "def + with keyword rest parameter" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      PLUS("+"),
      nil,
      ParametersNode([], [], nil, [], KeywordRestParameterNode(STAR_STAR("**"), IDENTIFIER("b")), nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([IDENTIFIER("b")])
    )

    assert_parses expected, "def + **b\nend"
  end

  test "def -" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      MINUS("-"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def -\nend"
  end

  test "def ==" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      EQUAL_EQUAL("=="),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def ==\nend"
  end

  test "def |" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      PIPE("|"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def |\nend"
  end

  test "def ^" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      CARET("^"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def ^\nend"
  end

  test "def &" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      AMPERSAND("&"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def &\nend"
  end

  test "def <=>" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      LESS_EQUAL_GREATER("<=>"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def <=>\nend"
  end

  test "def ===" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      EQUAL_EQUAL_EQUAL("==="),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def ===\nend"
  end

  test "def =~" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      EQUAL_TILDE("=~"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def =~\nend"
  end

  test "def !~" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      BANG_TILDE("!~"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def !~\nend"
  end

  test "def >" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      GREATER(">"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def >\nend"
  end

  test "def >=" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      GREATER_EQUAL(">="),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def >=\nend"
  end

  test "def <" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      LESS("<"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def <\nend"
  end

  test "def <=" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      LESS_EQUAL("<="),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def <=\nend"
  end

  test "def !=" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      BANG_EQUAL("!="),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def !=\nend"
  end

  test "def <<" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      LESS_LESS("<<"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def <<\nend"
  end

  test "def >>" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      GREATER_GREATER(">>"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def >>\nend"
  end

  test "def *" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      STAR("*"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def *\nend"
  end

  test "def /" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      SLASH("/"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def /\nend"
  end

  test "def %" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      PERCENT("%"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def %\nend"
  end

  test "def **" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      STAR_STAR("**"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def **\nend"
  end

  test "def !" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      BANG("!"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def !\nend"
  end

  test "def ~" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      TILDE("~"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def ~\nend"
  end

  test "def +@" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      PLUS_AT("+@"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def +@\nend"
  end

  test "def -@" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      MINUS_AT("-@"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def -@\nend"
  end

  test "def []" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      BRACKET_LEFT_RIGHT("[]"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def []\nend"
  end

  test "def []=" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      BRACKET_LEFT_RIGHT_EQUAL("[]="),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def []=\nend"
  end

  test "def + with self receiver" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      SelfNode(KEYWORD_SELF("self")),
      DOT("."),
      PLUS("+"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def self.+\nend"
  end

  test "def `" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      nil,
      nil,
      BACKTICK("`"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def `\nend"
  end

  test "def self.`" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      SelfNode(KEYWORD_SELF("self")),
      DOT("."),
      BACKTICK("`"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def self.`\nend"
  end

  test "def % with self receiver" do
    expected = DefNode(
      KEYWORD_DEF("def"),
      SelfNode(KEYWORD_SELF("self")),
      DOT("."),
      PLUS("+"),
      nil,
      ParametersNode([], [], nil, [], nil, nil),
      nil,
      nil,
      Statements([]),
      KEYWORD_END("end"),
      Scope([])
    )

    assert_parses expected, "def self.+\nend"
  end

  private

  def assert_serializes(expected, source)
    YARP.load(source, YARP.dump(source)) => YARP::Program[statements: YARP::Statements[body: [*, node]]]
    assert_equal expected, node
  end

  def assert_parses(expected, source)
    assert_equal expected, expression(source)
    assert_serializes expected, source

    YARP.lex_ripper(source).zip(YARP.lex_compat(source)).each do |(ripper, yarp)|
      assert_equal ripper[0...-1], yarp[0...-1]
    end
  end

  def expression(source)
    result = YARP.parse(source)
    assert_empty result.errors, PP.pp(result.node, +"")

    result.node => YARP::Program[statements: YARP::Statements[body: [*, node]]]
    node
  end
end
