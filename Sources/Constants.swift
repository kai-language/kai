

// brackets and braces
let openSquare:         UTF8.CodeUnit = "[".utf8.first!
let openBrace:          UTF8.CodeUnit = "{".utf8.first!
let openParentheses:     UTF8.CodeUnit = "(".utf8.first!
let closeSquare:        UTF8.CodeUnit = "]".utf8.first!
let closeBrace:         UTF8.CodeUnit = "}".utf8.first!
let closeParentheses:   UTF8.CodeUnit = ")".utf8.first!

// punctuation
let dot:          UTF8.CodeUnit = ".".utf8.first!
let hash:         UTF8.CodeUnit = "#".utf8.first!
let comma:        UTF8.CodeUnit = ",".utf8.first!
let colon:        UTF8.CodeUnit = ":".utf8.first!
let semiColon:    UTF8.CodeUnit = ";".utf8.first!

let equals:       UTF8.CodeUnit = "=".utf8.first!

let quote:        UTF8.CodeUnit = "\"".utf8.first!
let singleQuote:  UTF8.CodeUnit = "\"".utf8.first!

let slash:      UTF8.CodeUnit = "/".utf8.first!
let backslash:  UTF8.CodeUnit = "\\".utf8.first!

// whitespace characters
let space:      UTF8.CodeUnit = " ".utf8.first!
let tab:        UTF8.CodeUnit = "\t".utf8.first!
let cr:         UTF8.CodeUnit = "\r".utf8.first!
let newline:    UTF8.CodeUnit = "\n".utf8.first!
let backspace:  UTF8.CodeUnit = UTF8.CodeUnit(0x08)
let formfeed:   UTF8.CodeUnit = UTF8.CodeUnit(0x0C)

// Literal characters
let n: UTF8.CodeUnit = "n"
let t: UTF8.CodeUnit = "t"
let r: UTF8.CodeUnit = "r"
let u: UTF8.CodeUnit = "u"
let f: UTF8.CodeUnit = "f"
let a: UTF8.CodeUnit = "a"
let l: UTF8.CodeUnit = "l"
let s: UTF8.CodeUnit = "s"
let e: UTF8.CodeUnit = "e"

let b: UTF8.CodeUnit = "b"

// Number characters
let E: UTF8.CodeUnit = "E"
let zero: UTF8.CodeUnit = "0"
let plus: UTF8.CodeUnit = "+"
let minus: UTF8.CodeUnit = "-"
let numbers: ClosedRange<UTF8.CodeUnit> = "0"..."9"
let alphaNumericLower: ClosedRange<UTF8.CodeUnit> = "a"..."f"
let alphaNumericUpper: ClosedRange<UTF8.CodeUnit> = "A"..."F"

// Valid integer number Range
let valid64BitInteger: ClosedRange<Int64> = Int64.min...Int64.max
let validUnsigned64BitInteger: ClosedRange<UInt64> = UInt64.min...UInt64(Int64.max)

// End of here Literals
let rue: [UTF8.CodeUnit] = Array("rue".utf8)
let alse: [UTF8.CodeUnit] = Array("alse".utf8)
let ull: [UTF8.CodeUnit] = Array("ull".utf8)
