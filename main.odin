package main

import "core:fmt"

Token_Kind :: enum {
	Invalid,
	EOF,
	Number,
	Plus, // +
	Minus, // -
	Star, // *
	Slash, // /
	LParen, // (
	RParen, // )
}

Token :: struct {
	kind:   Token_Kind,
	lexeme: string,
	value:  int, // only valid if kind == Number
}

Lexer :: struct {
	input: string,
	pos:   int,
}

is_digit :: proc(c: byte) -> bool {
	return c >= '0' && c <= '9'
}

is_whitespace :: proc(c: byte) -> bool {
	return c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

lex :: proc(input: string) -> []Token {
	lexer := Lexer {
		input = input,
		pos   = 0,
	}

	tokens: [dynamic]Token

	for {
		if lexer.pos >= len(lexer.input) {
			append(&tokens, Token{kind = .EOF})
			break
		}

		c := lexer.input[lexer.pos]

		// Skip whitespace
		if is_whitespace(c) {
			lexer.pos += 1
			continue
		}

		// Numbers
		if is_digit(c) {
			start := lexer.pos
			value := 0

			for lexer.pos < len(lexer.input) && is_digit(lexer.input[lexer.pos]) {
				value = value * 10 + int(lexer.input[lexer.pos] - '0')
				lexer.pos += 1
			}

			append(
				&tokens,
				Token{kind = .Number, lexeme = lexer.input[start:lexer.pos], value = value},
			)
			continue
		}

		// Single-character tokens
		token := Token {
			lexeme = lexer.input[lexer.pos:lexer.pos + 1],
		}

		switch c {
		case '+':
			token.kind = .Plus
		case '-':
			token.kind = .Minus
		case '*':
			token.kind = .Star
		case '/':
			token.kind = .Slash
		case '(':
			token.kind = .LParen
		case ')':
			token.kind = .RParen
		case:
			token.kind = .Invalid
		}

		lexer.pos += 1
		append(&tokens, token)
	}

	return tokens[:]
}

Parser :: struct {
	tokens: []Token,
	pos:    int,
}

current :: proc(p: ^Parser) -> Token {
	return p.tokens[p.pos]
}

advance :: proc(p: ^Parser) -> Token {
	t := p.tokens[p.pos]
	p.pos += 1
	return t
}

match :: proc(p: ^Parser, kind: Token_Kind) -> bool {
	if current(p).kind == kind {
		p.pos += 1
		return true
	}
	return false
}

parse_expression :: proc(p: ^Parser) -> ^Expr {
	t := advance(p)

	fmt.println(t)
	if t.kind == .Number {
		c := current(p)
		#partial switch c.kind {
		case .Plus:
			advance(p)
			return make_expr_binary(
				left = make_expr_int_lit(i64(t.value)),
				right = parse_expression(p),
				op = .Plus,
			)
		case .EOF:
			return make_expr_int_lit(value = i64(t.value))
		}
	}
	return {}
}

Expr :: struct {
	kind: Expr_Kind,
	data: Expr_Data,
}

Expr_Kind :: enum {
	Int_Lit,
	Binary,
}

Expr_Data :: union {
	Expr_Int_Lit,
	Expr_Binary,
}

Expr_Int_Lit :: struct {
	value: i64,
}

Expr_Binary :: struct {
	op:          Token_Kind,
	left, right: ^Expr,
}

make_expr_int_lit :: proc(value: i64) -> ^Expr {
	expr := new(Expr)
	expr.kind = .Int_Lit
	expr.data = Expr_Int_Lit {
		value = value,
	}
	return expr
}

make_expr_binary :: proc(left, right: ^Expr, op: Token_Kind) -> ^Expr {
	expr := new(Expr)
	expr.kind = .Binary
	expr.data = Expr_Binary {
		op    = op,
		left  = left,
		right = right,
	}
	return expr
}

main :: proc() {
	expr := "12 + 34"
	tokens := lex(expr)

	parser := Parser {
		tokens = tokens,
	}
	// fmt.println(Binary{left = &Number{value = 100}, right = &Number{value = 200}})
	pexpr := parse_expression(&parser)
	fmt.println(pexpr)
	// print_expr(&pexpr)
}
