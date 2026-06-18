#+feature dynamic-literals

package main

import "core:math"
import "core:strings"

Token_Kind :: enum {
	NewLine,
	LParen,
	RParen,
	LBrace,
	RBrace,
	LBracket,
	RBracket,
	Identifier,
	QuotedString,
	Equal,
	DoubleEqual,
	NotEqual,
	Number,
	Plus,
	Minus,
	Slash,
	Star,
	Pipe,
	DoublePipe,
	Bang,
	Percent,
	Greater,
	DoubleGreater,
	Lesser,
	DoubleLesser,
	GreaterOrEqual,
	LesserOrEqual,
	Comma,
	Colon,
	ColonColon,
	Period,
	Caret,
	Ellipsis,
	DotDot,
	DotDotEq,
	Ampersand,
	DoubleAmpersand,
	ColonEqual,
	RightArrow,
	FatRightArrow,
	True_Keyword,
	False_Keyword,
	Func_Keyword,
	Return_Keyword,
	If_Keyword,
	Else_Keyword,
	For_Keyword,
	Break_Keyword,
	Continue_Keyword,
	Struct_Keyword,
	Enum_Keyword,
	Import_Keyword,
	External_Keyword,
	In_Keyword,
	Nil_Keyword,
	Match_Keyword,
	EOF,
}

Token_Val :: union {
	int,
	string,
	f64,
}


Span :: struct {
	start:    int,
	end:      int,
	filename: string,
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
	line_starts: [dynamic]int,
	filename:    string,
}

is_numeric :: proc(c: byte) -> bool {
	return c >= '0' && c <= '9'
}

is_hex_digit :: proc(c: byte) -> bool {
	return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
}

hex_digit_value :: proc(c: byte) -> int {
	switch {
	case c >= '0' && c <= '9':
		return int(c - '0')
	case c >= 'a' && c <= 'f':
		return int(c - 'a') + 10
	case c >= 'A' && c <= 'F':
		return int(c - 'A') + 10
	}
	return 0
}

is_alphanumeric :: proc(c: byte) -> bool {
	return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'
}

is_whitespace :: proc(c: byte) -> bool {
	return c == ' ' || c <= '\t'
}
is_newline :: proc(c: byte) -> bool {
	return c == '\n' || c <= '\r'
}

Keyword_Map: map[string]Token_Kind = {
	"fn"       = .Func_Keyword,
	"return"   = .Return_Keyword,
	"if"       = .If_Keyword,
	"else"     = .Else_Keyword,
	"for"      = .For_Keyword,
	"break"    = .Break_Keyword,
	"continue" = .Continue_Keyword,
	"struct"   = .Struct_Keyword,
	"enum"     = .Enum_Keyword,
	"import"   = .Import_Keyword,
	"external" = .External_Keyword,
	"in"       = .In_Keyword,
	"true"     = .True_Keyword,
	"false"    = .False_Keyword,
	"null"     = .Nil_Keyword,
	"match"    = .Match_Keyword,
}

lex_current :: proc(lexer: ^Lexer) -> u8 {
	if lexer.pos >= len(lexer.input) do return 0
	return lexer.input[lexer.pos]
}

lex_peek :: proc(lexer: ^Lexer, n: int = 1) -> u8 {
	i := lexer.pos + n
	if i >= len(lexer.input) do return 0
	return lexer.input[i]
}

lex_number :: proc(lexer: ^Lexer, tokens: ^[dynamic]Token) {
	start := lexer.pos
	value: f64 = 0
	is_integer: bool = true
	is_float: bool = false
	decimal_points: int = 0

	// Hexadecimal literal: 0x... or 0X...
	if lexer.input[lexer.pos] == '0' &&
	   lexer.pos + 1 < len(lexer.input) &&
	   (lexer.input[lexer.pos + 1] == 'x' || lexer.input[lexer.pos + 1] == 'X') {
		lexer.pos += 2 // Skip the 0x prefix
		hex_value: int = 0
		digit_start := lexer.pos
		for lexer.pos < len(lexer.input) &&
		    (is_hex_digit(lexer.input[lexer.pos]) || lexer.input[lexer.pos] == '_') {
			if lexer.input[lexer.pos] != '_' {
				hex_value = hex_value * 16 + hex_digit_value(lexer.input[lexer.pos])
			}
			lexer.pos += 1
		}
		end := lexer.pos
		if end == digit_start {
			fatal_span(
				Span{start = start, end = end, filename = lexer.filename},
				"Hexadecimal literal must have at least one digit",
			)
		}
		append(
			tokens,
			Token {
				kind = .Number,
				lexeme = lexer.input[start:end],
				value = hex_value,
				span = Span{start = start, end = end, filename = lexer.filename},
			},
		)
		return
	}

	for lexer.pos < len(lexer.input) &&
	    (is_numeric(lexer.input[lexer.pos]) ||
			    lexer.input[lexer.pos] == '_' ||
			    lexer.input[lexer.pos] == '.') {
		if lexer.input[lexer.pos] == '.' {
			if is_float do break
			// Don't consume '..' or '..=' as part of a float
			if lexer.pos + 1 < len(lexer.input) && lexer.input[lexer.pos + 1] == '.' do break
			is_float = true
			is_integer = false
		} else if lexer.input[lexer.pos] != '_' {
			if is_float {
				decimal_points += 1
			}
			value = value * 10 + f64(lexer.input[lexer.pos] - '0')
		}
		lexer.pos += 1
	}
	value = value / math.pow(10, f64(decimal_points))

	end := lexer.pos
	append(
		tokens,
		Token {
			kind = .Number,
			lexeme = lexer.input[start:end],
			value = is_integer ? int(value) : f64(value),
			span = Span{start = start, end = end, filename = lexer.filename},
		},
	)
}

lex :: proc(input: string, filename: string) -> []Token {
	tokens: [dynamic]Token
	lexer := Lexer {
		input    = input,
		pos      = 0,
		filename = filename,
	}

	// Always a line start at offset 0
	append(&lexer.line_starts, 0)

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
			append(&lexer.line_starts, lexer.pos)
			// Skip any repeated newlines
			for lexer.pos < len(lexer.input) && is_newline(lexer.input[lexer.pos]) {
				lexer.pos += 1
				append(&lexer.line_starts, lexer.pos)
			}
		case is_numeric(c):
			lex_number(&lexer, &tokens)
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
					Token {
						kind = kind,
						lexeme = lexeme,
						span = Span{start = start, end = end, filename = filename},
					},
				)
			} else {
				append(
					&tokens,
					Token {
						kind = .Identifier,
						lexeme = lexeme,
						value = lexeme,
						span = Span{start = start, end = end, filename = filename},
					},
				)
			}
		case c == '"':
			start := lexer.pos
			lexer.pos += 1 // Skip first quote
			sb := strings.builder_make()
			for lexer.pos < len(lexer.input) && lexer.input[lexer.pos] != '"' {
				// Really simple escape code parsing, right now just deal with \n
				cur_c := lexer.input[lexer.pos]
				if cur_c == '\\' {
					switch lex_peek(&lexer) {
					case 'n':
						strings.write_rune(&sb, '\n')
						lexer.pos += 1
					case:
						strings.write_byte(&sb, cur_c)
					}
				} else {
					strings.write_byte(&sb, cur_c)
				}
				lexer.pos += 1
			}
			lexer.pos += 1 // Skip last quote
			end := lexer.pos
			lexeme := lexer.input[start:end]
			value := strings.to_string(sb)
			append(
				&tokens,
				Token {
					kind = .QuotedString,
					lexeme = lexeme,
					span = Span{start = start, end = end, filename = filename},
					value = value,
				},
			)

		case c == '/':
			if lexer.input[lexer.pos + 1] == '/' {
				// This will keep NOT consume the final newline as it needs to be emitted
				// in the next iteration of this loop.
				// NOTE(quadrado): This is a code smell that should be fixed.
				for lexer.pos < len(lexer.input) && lex_current(&lexer) != '\n' {
					lexer.pos += 1
				}
			} else {
				append(&tokens, Token{kind = .Slash, lexeme = "/", span = one_char_span(lexer)})
				lexer.pos += 1
			}
		case c == '+':
			append(&tokens, Token{kind = .Plus, lexeme = "+", span = one_char_span(lexer)})
			lexer.pos += 1
		case c == '-':
			if lex_peek(&lexer) == '>' {
				append(
					&tokens,
					Token{kind = .RightArrow, lexeme = "->", span = two_char_span(lexer)},
				)
				lexer.pos += 2
			} else {
				append(&tokens, Token{kind = .Minus, lexeme = "-", span = one_char_span(lexer)})
				lexer.pos += 1
			}
		case c == '*':
			append(&tokens, Token{kind = .Star, lexeme = "*", span = one_char_span(lexer)})
			lexer.pos += 1
		case c == '!':
			if lex_peek(&lexer) == '=' {
				append(
					&tokens,
					Token{kind = .NotEqual, lexeme = "!=", span = two_char_span(lexer)},
				)
				lexer.pos += 2
			} else {
				append(&tokens, Token{kind = .Bang, lexeme = "!", span = one_char_span(lexer)})
				lexer.pos += 1
			}
		case c == '%':
			append(&tokens, Token{kind = .Percent, lexeme = "%", span = one_char_span(lexer)})
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
		case c == '[':
			append(&tokens, Token{kind = .LBracket, lexeme = "[", span = one_char_span(lexer)})
			lexer.pos += 1
		case c == ']':
			append(&tokens, Token{kind = .RBracket, lexeme = "]", span = one_char_span(lexer)})
			lexer.pos += 1
		case c == '=':
			if lex_peek(&lexer) == '=' {
				append(
					&tokens,
					Token{kind = .DoubleEqual, lexeme = "==", span = two_char_span(lexer)},
				)
				lexer.pos += 2
			} else if lex_peek(&lexer) == '>' {
				append(
					&tokens,
					Token{kind = .FatRightArrow, lexeme = "=>", span = two_char_span(lexer)},
				)
				lexer.pos += 2

			} else {
				append(&tokens, Token{kind = .Equal, lexeme = "=", span = one_char_span(lexer)})
				lexer.pos += 1
			}
		case c == '|':
			if lex_peek(&lexer) == '|' {
				append(
					&tokens,
					Token{kind = .DoublePipe, lexeme = "||", span = two_char_span(lexer)},
				)
				lexer.pos += 2
			} else {
				append(&tokens, Token{kind = .Pipe, lexeme = "|", span = one_char_span(lexer)})
				lexer.pos += 1
			}
		case c == ',':
			append(&tokens, Token{kind = .Comma, lexeme = ",", span = one_char_span(lexer)})
			lexer.pos += 1
		case c == '.':
			if lex_peek(&lexer, 1) == '.' && lex_peek(&lexer, 2) == '.' {
				append(
					&tokens,
					Token{kind = .Ellipsis, lexeme = "...", span = n_char_span(lexer, 3)},
				)
				lexer.pos += 3
			} else if lex_peek(&lexer, 1) == '.' && lex_peek(&lexer, 2) == '=' {
				append(
					&tokens,
					Token{kind = .DotDotEq, lexeme = "..=", span = n_char_span(lexer, 3)},
				)
				lexer.pos += 3
			} else if lex_peek(&lexer, 1) == '.' {
				append(&tokens, Token{kind = .DotDot, lexeme = "..", span = two_char_span(lexer)})
				lexer.pos += 2
			} else {
				append(&tokens, Token{kind = .Period, lexeme = ".", span = one_char_span(lexer)})
				lexer.pos += 1
			}
		case c == ':':
			if lex_peek(&lexer) == '=' {
				append(
					&tokens,
					Token{kind = .ColonEqual, lexeme = ":=", span = two_char_span(lexer)},
				)
				lexer.pos += 2
			} else if lex_peek(&lexer, 1) == ':' {
				append(
					&tokens,
					Token{kind = .ColonColon, lexeme = "::", span = two_char_span(lexer)},
				)
				lexer.pos += 2
			} else {
				append(&tokens, Token{kind = .Colon, lexeme = ":", span = one_char_span(lexer)})
				lexer.pos += 1
			}
		case c == '^':
			append(&tokens, Token{kind = .Caret, lexeme = "^", span = one_char_span(lexer)})
			lexer.pos += 1
		case c == '>':
			if lex_peek(&lexer) == '=' {
				append(
					&tokens,
					Token{kind = .GreaterOrEqual, lexeme = ">=", span = two_char_span(lexer)},
				)
				lexer.pos += 2
			} else if lex_peek(&lexer) == '>' {
				append(
					&tokens,
					Token{kind = .DoubleGreater, lexeme = ">>", span = two_char_span(lexer)},
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
					Token{kind = .LesserOrEqual, lexeme = "<=", span = two_char_span(lexer)},
				)
				lexer.pos += 2
			} else if lex_peek(&lexer) == '<' {
				append(
					&tokens,
					Token{kind = .DoubleLesser, lexeme = "<<", span = two_char_span(lexer)},
				)
				lexer.pos += 2
			} else {
				append(&tokens, Token{kind = .Lesser, lexeme = "<", span = one_char_span(lexer)})
				lexer.pos += 1
			}
		case c == '&':
			if lex_peek(&lexer) == '&' {
				append(
					&tokens,
					Token{kind = .DoubleAmpersand, lexeme = "&&", span = two_char_span(lexer)},
				)
				lexer.pos += 2
			} else {
				append(
					&tokens,
					Token{kind = .Ampersand, lexeme = "&", span = one_char_span(lexer)},
				)
				lexer.pos += 1
			}
		case:
			fatal_span(
				Span{start = lexer.pos, filename = filename},
				"Unrecognized character %c",
				c,
			)
		}
	}
	compiler.line_starts[filename] = lexer.line_starts
	compiler.sources[filename] = input
	return tokens[:]
}
