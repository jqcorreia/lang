package main

import "core:fmt"

Token_Kind :: enum {
	NewLine,
	LParen,
	RParen,
	Identifier,
	Equal,
	Number,
	Plus,
	Minus,
	Slash,
	Star,
	EOF,
	Comma,
}

Token_Val :: union {
	int,
	string,
}

Token :: struct {
	kind:   Token_Kind,
	lexeme: string,
	value:  Token_Val,
}

Lexer :: struct {
	input: string,
	pos:   int,
}

is_numeric :: proc(c: byte) -> bool {
	return c >= '0' && c <= '9'
}

is_alphanumeric :: proc(c: byte) -> bool {
	return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}

is_whitespace :: proc(c: byte) -> bool {
	return c == ' ' || c <= '\t'
}
is_newline :: proc(c: byte) -> bool {
	return c == '\n' || c <= '\r'
}

lex :: proc(input: string) -> []Token {
	tokens: [dynamic]Token
	lexer := Lexer {
		input = input,
		pos   = 0,
	}

	for {
		if lexer.pos >= len(lexer.input) {
			append(&tokens, Token{kind = .EOF})
			break
		}

		c := lexer.input[lexer.pos]

		// Have an explicit, no tricks, global switch
		// Some repetition is good repetition...
		switch {
		case is_whitespace(c):
			lexer.pos += 1
		case is_newline(c):
			append(&tokens, Token{kind = .NewLine, lexeme = "\n"})
			lexer.pos += 1
		case is_numeric(c):
			start := lexer.pos
			value := 0
			for lexer.pos < len(lexer.input) && is_numeric(lexer.input[lexer.pos]) {
				value = value * 10 + int(lexer.input[lexer.pos] - '0')
				lexer.pos += 1
			}
			end := lexer.pos
			append(&tokens, Token{kind = .Number, lexeme = lexer.input[start:end], value = value})
		case is_alphanumeric(c):
			start := lexer.pos
			for lexer.pos < len(lexer.input) &&
			    (is_alphanumeric(lexer.input[lexer.pos]) || is_numeric(lexer.input[lexer.pos])) {
				lexer.pos += 1
			}
			end := lexer.pos
			lexeme := lexer.input[start:end]
			append(&tokens, Token{kind = .Identifier, lexeme = lexeme, value = lexeme})
		case c == '+':
			append(&tokens, Token{kind = .Plus, lexeme = "+"})
			lexer.pos += 1
		case c == '-':
			append(&tokens, Token{kind = .Minus, lexeme = "-"})
			lexer.pos += 1
		case c == '/':
			if lexer.input[lexer.pos] == '/' {
				for lexer.pos < len(lexer.input) && lexer.input[lexer.pos] != '\n' {
					lexer.pos += 1
				}
				lexer.pos += 1 // Consume final newline
			} else {
				append(&tokens, Token{kind = .Slash, lexeme = "/"})
				lexer.pos += 1
			}
		case c == '*':
			append(&tokens, Token{kind = .Star, lexeme = "*"})
			lexer.pos += 1
		case c == '(':
			append(&tokens, Token{kind = .LParen, lexeme = "("})
			lexer.pos += 1
		case c == ')':
			append(&tokens, Token{kind = .RParen, lexeme = ")"})
			lexer.pos += 1
		case c == '=':
			append(&tokens, Token{kind = .Equal, lexeme = "="})
			lexer.pos += 1
		case c == ',':
			append(&tokens, Token{kind = .Comma, lexeme = ","})
			lexer.pos += 1
		case:
			lexer.pos += 1
		}
	}
	return tokens[:]
}
