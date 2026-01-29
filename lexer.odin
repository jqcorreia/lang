#+feature dynamic-literals

package main

import "core:fmt"

Token_Kind :: enum {
	NewLine,
	LParen,
	RParen,
	LBrace,
	RBrace,
	Identifier,
	Equal,
	DoubleEqual,
	Number,
	Plus,
	Minus,
	Slash,
	Star,
	Greater,
	Lesser,
	GreaterOrEqual,
	LesserOrEqual,
	Comma,
	Func_Keyword,
	Return_Keyword,
	If_Keyword,
	Else_Keyword,
	RightArrow,
	EOF,
}

Token_Val :: union {
	int,
	string,
}


Span :: struct {
	start: int,
	end:   int,
}

Token :: struct {
	kind:   Token_Kind,
	lexeme: string,
	value:  Token_Val,
	span:   Span,
}

Lexer :: struct {
	input:       string,
	pos:         int,
	line_starts: []int,
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

Keyword_Map: map[string]Token_Kind = {
	"fn"     = .Func_Keyword,
	"return" = .Return_Keyword,
	"if"     = .If_Keyword,
	"else"   = .Else_Keyword,
}

lex_current :: proc(lexer: ^Lexer) -> u8 {
	return lexer.input[lexer.pos]
}

lex_peek :: proc(lexer: ^Lexer, n: int = 1) -> u8 {
	return lexer.input[lexer.pos + n]
}

lex :: proc(input: string) -> []Token {
	tokens: [dynamic]Token
	lexer := Lexer {
		input = input,
		pos   = 0,
	}

	// Always a line start at offset 0
	append(&state.line_starts, 0)

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
			append(&tokens, Token{kind = .NewLine, lexeme = "\n", span = one_char_span(lexer)})
			lexer.pos += 1
			append(&state.line_starts, lexer.pos)
			// Skip any repeated newlines
			for lexer.pos < len(lexer.input) && is_newline(lexer.input[lexer.pos]) {
				lexer.pos += 1
				append(&state.line_starts, lexer.pos)
			}
		case is_numeric(c):
			start := lexer.pos
			value := 0
			for lexer.pos < len(lexer.input) && is_numeric(lexer.input[lexer.pos]) {
				value = value * 10 + int(lexer.input[lexer.pos] - '0')
				lexer.pos += 1
			}
			end := lexer.pos
			append(
				&tokens,
				Token {
					kind = .Number,
					lexeme = lexer.input[start:end],
					value = value,
					span = Span{start = start, end = end},
				},
			)
		case is_alphanumeric(c):
			start := lexer.pos
			for lexer.pos < len(lexer.input) &&
			    (is_alphanumeric(lexer.input[lexer.pos]) || is_numeric(lexer.input[lexer.pos])) {
				lexer.pos += 1
			}
			end := lexer.pos
			lexeme := lexer.input[start:end]

			// Check if the lexeme is a keyword
			if kind, exists := Keyword_Map[lexeme]; exists {
				append(
					&tokens,
					Token{kind = kind, lexeme = lexeme, span = Span{start = start, end = end}},
				)
			} else {
				append(
					&tokens,
					Token {
						kind = .Identifier,
						lexeme = lexeme,
						value = lexeme,
						span = Span{start = start, end = end},
					},
				)
			}
		case c == '+':
			append(&tokens, Token{kind = .Plus, lexeme = "+", span = one_char_span(lexer)})
			lexer.pos += 1
		case c == '-':
			fmt.printf("%c\n", lex_peek(&lexer))
			if lex_peek(&lexer) == '>' {
				append(
					&tokens,
					Token {
						kind = .RightArrow,
						lexeme = "->",
						span = Span{start = lexer.pos, end = lexer.pos + 1},
					},
				)
				lexer.pos += 2
			} else {
				append(&tokens, Token{kind = .Minus, lexeme = "-", span = one_char_span(lexer)})
				lexer.pos += 1
			}
		case c == '/':
			if lexer.input[lexer.pos + 1] == '/' {
				for lexer.pos < len(lexer.input) && lex_current(&lexer) != '\n' {
					lexer.pos += 1
					fmt.printf("%c\n", lexer.input[lexer.pos])
				}
			} else {
				append(&tokens, Token{kind = .Slash, lexeme = "/", span = one_char_span(lexer)})
				lexer.pos += 1
			}
		case c == '*':
			append(&tokens, Token{kind = .Star, lexeme = "*", span = one_char_span(lexer)})
			lexer.pos += 1
		case c == '(':
			append(&tokens, Token{kind = .LParen, lexeme = "(", span = one_char_span(lexer)})
			lexer.pos += 1
		case c == ')':
			append(&tokens, Token{kind = .RParen, lexeme = ")", span = one_char_span(lexer)})
			lexer.pos += 1
		case c == '{':
			append(&tokens, Token{kind = .LBrace, lexeme = "{", span = one_char_span(lexer)})
			lexer.pos += 1
		case c == '}':
			append(&tokens, Token{kind = .RBrace, lexeme = "}", span = one_char_span(lexer)})
			lexer.pos += 1
		case c == '=':
			if lex_peek(&lexer) == '=' {
				append(
					&tokens,
					Token{kind = .DoubleEqual, lexeme = ">", span = one_char_span(lexer)},
				)
				lexer.pos += 2
			} else {
				append(&tokens, Token{kind = .Equal, lexeme = ">", span = one_char_span(lexer)})
				lexer.pos += 1
			}
		case c == ',':
			append(&tokens, Token{kind = .Comma, lexeme = ",", span = one_char_span(lexer)})
			lexer.pos += 1
		case c == '>':
			if lex_peek(&lexer) == '=' {
				append(
					&tokens,
					Token{kind = .GreaterOrEqual, lexeme = ">", span = one_char_span(lexer)},
				)
				lexer.pos += 2
			} else {
				append(&tokens, Token{kind = .Greater, lexeme = ">", span = one_char_span(lexer)})
				lexer.pos += 1
			}
		case c == '<':
			if lex_peek(&lexer) == '=' {
				append(
					&tokens,
					Token{kind = .LesserOrEqual, lexeme = ">", span = one_char_span(lexer)},
				)
				lexer.pos += 2
			} else {
				append(&tokens, Token{kind = .Lesser, lexeme = ">", span = one_char_span(lexer)})
				lexer.pos += 1
			}
		case:
			unimplemented(fmt.tprintf("Token not recongnized: %c", c))
		}
	}
	return tokens[:]
}
