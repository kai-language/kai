
# Structs

> The most basic data type

```
    Person :: struct { username: string, lastLoggedIn: u64 }
```

# Unions

> a union is a value that may have any of several representations or formats within the same position in memory

These are C unions with Kai syntax

```
    FP32 :: union { u: u32, f: f32 }
```

# Variants

Variants are essentially a tagged union. Their syntax deviates from that of unions and structs somewhat because of the behaviours they enable.
```
    Type :: variant {
        size, align: uint

        Named   :: struct { name: string, base: *Type }
        Integer :: struct { signed: bool }
        Float   :: struct {}
        String  :: struct {}
        Boolean :: struct {}
    }
```

`Type` declared above has multiple nested _Types_ all of which can implicitely convert to `Type` because they have the same in memory representation.

Each Nested type has an implicit field `tag` used to identify what variant of `Type` an instance is.

Internally the above variant is equivalent to:

```
    Type :: struct {

        Tag :: enum { Named, Integer, Float, String, Boolean }
        using union {
            Named   :: struct { tag: Tag = Tag.Named, name: string, base: *Type }
            Integer :: struct { tag: Tag = Tag.Integer, signed: bool }
            Float   :: struct { tag: Tag = Tag.Float }
            String  :: struct { tag: Tag = Tag.String }
            Boolean :: struct { tag: Tag = Tag.Boolean }
        }
    }

    type := Type.Integer{signed: true} // type.tag is automatically set to `.Integer` for us.
```

This means that a variant will consume the size of it's largest value plus the size of the tag.

Variants provide additional safety and syntax to make use of the tagged union concept.

In Kai a variant instance access can be done on an instance of the above through:

```
    signed := type.Integer.signed
```

This will crash at runtime if the `tag` of `type` is not currently set to `Integer`.
Crashing can be avoided by checking the result of the cast:

```
    signed, err := type.Integer.signed
    if !err // handle non integer type
```

Variants are switchable:

```
    switch type.tag {
    case Tag.Integer: // In this case the `type` variant members are available directly on the instance of `type`
        if type.signed
            printf("type is a signed integer of size %\n", type.size)
        else
            printf("type is an unsigned integer of size %\n", type.size)

    case Tag.Float:
        printf("type is a floating point number of size %\n", type.size)

    default:
        printf("type is not a number\n")
    }
```

An Instance of a variant is referencable on both an instance and on the type itself. (`Type.Integer` & `type.Integer`)

```
    typeof(Type.Integer) // struct { size, align: uint, signed: bool, padding: [12]u8 }


