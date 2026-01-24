#+feature dynamic-literals

package main

Token_Kind :: enum {
	Invalid,
	EOF,
	Number,
	Plus,
	Minus,
	Star,
	Slash,
	LParen,
	RParen,
	Identifier,
	NewLine,
	Function_Keyword,
	Equal,
	Comma,
}

Token :: struct {
	kind:   Token_Kind,
	lexeme: string,
	value:  Token_Val,
}


Token_Val :: union {
	int,
	string,
}

Lexer :: struct {
	input: string,
	pos:   int,
}

is_digit :: proc(c: byte) -> bool {
	return c >= '0' && c <= '9'
}

is_newline :: proc(c: byte) -> bool {
	return c == '\n' || c == '\r'
}

is_whitespace :: proc(c: byte) -> bool {
	return c == ' ' || c == '\t'
}

is_alphanumeric :: proc(c: byte) -> bool {
	return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')

}

Keyword_Map: map[string]Token_Kind = {
	"fn" = .Function_Keyword,
}

lex :: proc(input: string) -> []Token {
	lexer := Lexer {
		input = input,
		pos   = 0,
	}

	tokens: [dynamic]Token

	for {
		ignore := false
		if lexer.pos >= len(lexer.input) {
			append(&tokens, Token{kind = .EOF})
			break
		}

		c := lexer.input[lexer.pos]

		if is_newline(c) {
			append(&tokens, Token{kind = .NewLine, lexeme = "\n", value = nil})
			lexer.pos += 1
			continue
		}

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
		// Identifiers
		if is_alphanumeric(c) {
			start := lexer.pos

			for lexer.pos < len(lexer.input) &&
			    (is_alphanumeric(lexer.input[lexer.pos]) || is_digit(lexer.input[lexer.pos])) {
				lexer.pos += 1
			}
			text := lexer.input[start:lexer.pos]

			kind := Keyword_Map[text] or_else .Identifier
			append(&tokens, Token{kind = kind, lexeme = text, value = text})

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
			if lexer.input[lexer.pos + 1] == '/' {
				ignore = true
				for {
					lexer.pos += 1
					if lexer.pos > len(lexer.input) - 1 do panic("Invalid token")
					if lexer.input[lexer.pos] == '\n' {
						lexer.pos += 1 // Consume '\n'
						break
					}
				}
			}
			token.kind = .Slash
		case '(':
			token.kind = .LParen
		case ')':
			token.kind = .RParen
		case '=':
			token.kind = .Equal
		case ',':
			token.kind = .Comma
		case:
			token.kind = .Invalid
		}

		if !ignore {
			lexer.pos += 1
			append(&tokens, token)
		}
	}

	return tokens[:]
}
