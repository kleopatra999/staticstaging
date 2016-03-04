{
  // From the PEG.js examples.
  function build_list(first, rest, index) {
    return [first].concat(extractList(rest, index));
  }
}

Program
  = _ e:SeqExpr _
  { return e; }


// Expression syntax.

Expr "expression"
  = Var / Macro / Extern / Fun / CDef / If / Binary / Unary / Assign /
  CCall / Call / TermExpr

SeqExpr
  = Seq / HalfSeq / Expr

// Expressions that usually don't need parenthesization.
TermExpr
  = Quote / FloatLiteral / IntLiteral / CCall / Lookup / Splice / Persist /
  Snippet / Run / Paren

// Expressions that can be operands to binary/unary operators.
Operand
  = If / Call / TermExpr

Seq
  = lhs:Expr _ seq _ rhs:SeqExpr
  { return {tag: "seq", lhs: lhs, rhs: rhs}; }

// Allow (and ignore) a trailing semicolon.
HalfSeq
  = lhs:Expr _ seq
  { return lhs; }

IntLiteral "literal"
  = n:int
  { return {tag: "literal", type: "int", value: n}; }

FloatLiteral
  = n:float
  { return {tag: "literal", type: "float", value: n}; }

Lookup "variable reference"
  = i:ident
  { return {tag: "lookup", ident: i}; }

Var "definition"
  = var _ i:ident _ eq _ e:Expr
  { return {tag: "let", ident: i, expr: e}; }

Macro
  = macro _ i:ident _ eq _ e:Expr
  { return {tag: "macro", ident: i, expr: e}; }

Unary "unary operation"
  = op:unop _ e:Operand
  { return {tag: "unary", expr: e, op: op}; }

Binary
  = AddBinary / MulBinary
AddBinary
  = lhs:(MulBinary / Operand) _ op:addbinop _ rhs:(Binary / Operand)
  { return {tag: "binary", lhs: lhs, op: op, rhs: rhs}; }
MulBinary
  = lhs:Operand _ op:mulbinop _ rhs:(MulBinary / Operand)
  { return {tag: "binary", lhs: lhs, rhs: rhs, op: op}; }

Quote "quote"
  = s:snippet_marker? a:ident? quote_open _ e:SeqExpr _ quote_close
  { return {tag: "quote", expr: e, annotation: a || "", snippet: !!s}; }

Splice "splice escape"
  = escape_open _ e:SeqExpr _ escape_close n:int?
  { return {tag: "escape", expr: e, count: n || 1, kind: "splice"}; }

Persist "persist escape"
  = persist_marker escape_open _ e:SeqExpr _ escape_close n:int?
  { return {tag: "escape", expr: e, count: n || 1, kind: "persist"}; }

Snippet "snippet escape"
  = snippet_marker escape_open _ e:SeqExpr _ escape_close n:int?
  { return {tag: "escape", expr: e, count: n || 1, kind: "snippet"}; }

Run "run"
  = run _ e:TermExpr
  { return {tag: "run", expr: e}; }

Fun "lambda"
  = fun _ ps:Param* _ arrow _ e:Expr
  { return {tag: "fun", params: ps, body: e}; }
Param "parameter"
  = i:ident _ typed _ t:TermType _
  { return {tag: "param", name: i, type: t}; }

CDef "C-style function definition"
  = def _ i:ident _ paren_open _ ps:CParamList _ paren_close _ e:Expr
  { return {tag: "let", ident: i, expr: {tag: "fun", params: ps, body: e} }; }
CParamList
  = first:CParam rest:CParamMore*
  { return [first].concat(rest); }
CParamMore
  = comma _ p:CParam
  { return p; }
CParam
  = i:ident _ typed _ t:Type _
  { return {tag: "param", name: i, type: t}; }

Call "call"
  = i:TermExpr _ as:Arg+
  { return {tag: "call", fun: i, args: as}; }
Arg
  = e:TermExpr _
  { return e; }

CCall "C-style call"
  = i:Lookup paren_open _ as:CArgList? _ paren_close
  { return {tag: "call", fun: i, args: as || []}; }
CArgList
  = first:Expr rest:CArgMore*
  { return [first].concat(rest); }
CArgMore
  = _ comma _ e:Expr
  { return e; }

Extern "extern declaration"
  = extern _ i:ident _ typed _ t:Type e:ExternExpansion?
  { return {tag: "extern", name: i, type: t, expansion: e}; }
ExternExpansion
  = _ eq _ s:string
  { return s; }

Paren "parentheses"
  = paren_open _ e:SeqExpr _ paren_close
  { return e; }

Assign "assignment"
  = i:ident _ eq _ e:Expr
  { return {tag: "assign", ident: i, expr: e}; }

If "if/then/else"
  = if _ c:TermExpr _ t:TermExpr _ f:TermExpr
  { return {tag: "if", cond: c, truex: t, falsex: f}; }


// Type syntax.

Type "type"
  = FunType / InstanceType / TermType

TermType
  = CodeType / PrimitiveType / ParenType

PrimitiveType "primitive type"
  = i:ident
  { return {tag: "type_primitive", name: i}; }

InstanceType "parameterized type instance"
  = t:TermType _ i:ident
  { return {tag: "type_instance", name: i, arg: t}; }

ParenType
  = paren_open _ t:Type _ paren_close
  { return t; }

FunType "function type"
  = p:FunTypeParam* arrow _ r:TermType
  { return {tag: "type_fun", params: p, ret: r}; }

CodeType "code type"
  = a:ident? quote_open _ t:Type _ quote_close
  { return {tag: "type_code", inner: t, annotation: a || ""}; }

FunTypeParam
  = t:TermType _
  { return t; }


// Tokens.

int "integer"
  = DIGIT+
  { return parseInt(text()); }

float "float"
  = DIGIT+ [.] DIGIT+
  { return parseFloat(text()); }

ident "identifier"
  = (ALPHA / [_]) (ALPHA / DIGIT / [_.])* SUFFIX*
  { return text(); }

string "string"
  = ["] [^"]* ["]
  { return text().slice(1, -1); }

var
  = "var"

eq
  = "="

seq
  = ";"

addbinop
  = [+\-]
mulbinop
  = [*/]

unop "unary operator"
  = [+\-]

quote_open "quote start"
  = "<"

quote_close "quote end"
  = ">"

escape_open
  = "["

escape_close
  = "]"

persist_marker
  = "%"

run "run operator"
  = "!"

fun
  = "fun"

arrow "arrow"
  = "->"

typed "type marker"
  = ":"

comma "comma"
  = ","

paren_open
  = "("

paren_close
  = ")"

extern
  = "extern"

def
  = "def"

quote
  = ["]

snippet_marker
  = "$"

if
  = "if"

macro
  = "macro"


// Empty space.

comment "comment"
  = "#" (!NEWLINE .)*

ws "whitespace"
  = SPACE

_
  = (ws / comment)*


// Character classes.

SPACE = [ \t\r\n\v\f]
ALPHA = [A-Za-z]
DIGIT = [0-9]
SUFFIX = [\?\!]
NEWLINE = [\r\n]
