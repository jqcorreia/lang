" Quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Keywords
syntax keyword zeroKeyword fn struct enum external for if else break continue match return import in true false
syntax keyword zeroType i32 u8 str 

" Strings
syntax region zeroString start='"' end='"' skip='\\"'

" Numbers
syntax match zeroNumber "\v<\d+>"

" Comments
syntax match zeroComment "//.*$"

" Operators and Delimiters
syntax match zeroOperator "\v\:\="
syntax match zeroOperator "\v\-\>"
syntax match zeroOperator "\v[\+\-\*\=\!\>\<]"
syntax match zeroDelimiter "\v[\{\}\(\)\[\]\:\,]"

" Function calls (identifier followed by a paren)
syntax match zeroFunction "\v\w+\ze\("

" Map to standard highlight groups
highlight link zeroKeyword Statement
highlight link zeroType Type
highlight link zeroString String
highlight link zeroNumber Number
highlight link zeroComment Comment
highlight link zeroOperator Operator
highlight link zeroFunction Function

let b:current_syntax = "zero"
