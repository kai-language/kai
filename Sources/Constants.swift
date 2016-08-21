
// json special characters
let arrayOpen: UTF8.CodeUnit = "[".utf8.first!
let objectOpen: UTF8.CodeUnit = "{".utf8.first!
let arrayClose: UTF8.CodeUnit = "]".utf8.first!
let objectClose: UTF8.CodeUnit = "}".utf8.first!
let comma: UTF8.CodeUnit = ",".utf8.first!
let colon: UTF8.CodeUnit = ":".utf8.first!
let quote: UTF8.CodeUnit = "\"".utf8.first!
let slash: UTF8.CodeUnit = "/".utf8.first!
let backslash: UTF8.CodeUnit = "\\".utf8.first!

// whitespace characters
let space: UTF8.CodeUnit = " ".utf8.first!
let tab: UTF8.CodeUnit = "\t".utf8.first!
let cr: UTF8.CodeUnit = "\r".utf8.first!
let newline: UTF8.CodeUnit = "\n".utf8.first!
let backspace: UTF8.CodeUnit = UTF8.CodeUnit(0x08)
let formfeed: UTF8.CodeUnit = UTF8.CodeUnit(0x0C)

// Literal characters
let n: UTF8.CodeUnit = "n".utf8.first!
let t: UTF8.CodeUnit = "t".utf8.first!
let r: UTF8.CodeUnit = "r".utf8.first!
let u: UTF8.CodeUnit = "u".utf8.first!
let f: UTF8.CodeUnit = "f".utf8.first!
let a: UTF8.CodeUnit = "a".utf8.first!
let l: UTF8.CodeUnit = "l".utf8.first!
let s: UTF8.CodeUnit = "s".utf8.first!
let e: UTF8.CodeUnit = "e".utf8.first!

let b: UTF8.CodeUnit = "b".utf8.first!

// Number characters
let E: UTF8.CodeUnit = "E".utf8.first!
let zero: UTF8.CodeUnit = "0".utf8.first!
let plus: UTF8.CodeUnit = "+".utf8.first!
let minus: UTF8.CodeUnit = "-".utf8.first!
let decimal: UTF8.CodeUnit = ".".utf8.first!
let numbers: ClosedRange<UTF8.CodeUnit> = "0".utf8.first!..."9".utf8.first!
let alphaNumericLower: ClosedRange<UTF8.CodeUnit> = "a".utf8.first!..."f".utf8.first!
let alphaNumericUpper: ClosedRange<UTF8.CodeUnit> = "A".utf8.first!..."F".utf8.first!

// Valid integer number Range
let valid64BitInteger: ClosedRange<Int64> = Int64.min...Int64.max
let validUnsigned64BitInteger: ClosedRange<UInt64> = UInt64.min...UInt64(Int64.max)

// End of here Literals
let rue: [UTF8.CodeUnit] = ["r".utf8.first!, "u".utf8.first!, "e".utf8.first!]
let alse: [UTF8.CodeUnit] = ["a".utf8.first!, "l".utf8.first!, "s".utf8.first!, "e".utf8.first!]
let ull: [UTF8.CodeUnit] = ["u".utf8.first!, "l".utf8.first!, "l".utf8.first!]
