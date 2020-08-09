# Zig CCSDS Primary Header
This repository contains a basic, but essentially complete, implementation
of the CCSDS Space Packet Protocol Primary Header in the Zig programming language.


The point of writing this library is to try Zig out on a binary data
specification 1) without serialization and deserialization, and 2) with the
format known beforehand, to see how it compares to C and Rust.  Overall it
performs very well, and this is my preferred encoding compared to similar
libraries I've written in those languages.


## Primary Header Layout
The CCSDS Primary Header is a simple binary packet header containing
three sections, each of which is two bytes, which is referred to as a 'word':


  * The 'control' section (this is my name, not in the standard) which contains an
  identifier for the source/destination pair, a flag for whether there is another
  header following the primary header, a flag indicating whether the packet
  contains a command or telemetry, and the protocol version (always 0).
  * The 'sequence' section contains the sequence flag indicating whether the
  packet is part of a larger related sequence of packets, and the sequence
  counter whose meaning depends on the sequence flag.
  * The 'length' section is simply the packet length, not including the header
  itself, minus 1. The minus 1 comes from the fact that a CCSDS packet cannot
  have an empty data section (there must be at least 1 byte afterwards), so the
  standard does not account for that one required byte in the length field.
  Whether this was a good idea or not (I don't think so) it ensures that
  all length field values are valid.



This diagram gives a basic description of the format, going from
most significant bit to least significant bit from left to right,
across three 16-bit fields for a total of six bytes:


```
+--------+--------+------------+-------------+
|Version | Packet |Secondary   |    APID     |
|        | Type   |Header Flag |             |
+--------+--------+------------+-------------+
| 3 bits |  1 bit |   1 bit    |    11 bit   |
+--------+---------------------+-------------+
|           16 bit word, bits 0..15          |
+--------------------------------------------+
 
+---------+----------------------------------+
|Sequence |         Sequence Count           |
|Flags    |                                  |
+---------+----------------------------------+
| 2 bits  |            14 bit                |
+---------+----------------------------------+
|           16 bit word, bits 16..31         |
+--------------------------------------------+

+--------------------------------------------+
|                Packet Length               |
|                                            |
+--------------------------------------------+
|                   16 bits                  |
+--------------------------------------------+
|           16 bit word, bits 32..47         |
+--------------------------------------------+
```

## Background
As a test of a new language, I sometimes write this library for encoding
and decoding CCSDS primary headers. This is a fairly simple packet header,
containing only 6 bytes, but forces you to think about how you will
handle endianness and bit field data in a language. These are important
for embedded systems programmers (and other systems programmes), so
I see this as a litmus test for how a language will handle these kinds of
concerns.


There are many ways to handle this kind of data encoding. Many libraries,
especially in managed languages, is to deserialize the packet from bytes
into a native structure, and then serialize it back when it is ready
to be sent on the network. A similar process would be necessary
for controlling hardware registers.


However, I always write this library in such a way that the binary
data is kept in the format defined in the standard. I prefer this
to avoid creating duplicates of the data in a system (the "true"
form within a byte buffer, and copy deserialized and manipulated).


### C
To accomplish this in C (and in Rust, if avoiding macro libraries)
we have to keep the data as byte pairs, construct a 16 bit unsigned integer
out of them (this keeps the layout fixed and works on both big and little
endian systems). We can then do the bit mask and shift operations to
extract the correct bits, and then the opposite mask/shift/OR operations
to place bits within these 16-bit words. This is error prone, but it
does work, its cross platform, and its preferrable to C bitfields.


When getting and setting fields, an integer with at least the field
width is used. For example, the APID (Application Identifier) is 11 bits,
but is read out as a uint16\_t in C as C does not have the ability to
describe integers that are not powers of two.

### Rust
Rust has a number of possible solutions- it does not currently have bitfields,
although perhaps it may in the future, but the C solution works just as well in
Rust, and there are other solutions, if you are willing to accept libraries
which provide macros that extend the Rust language.


There are a number of these libraries. However, some of them seem to do
serialization/deserialization, and all of them require your types to be defined
within the macro context. I would much prefer a language that allows me to do
this kind of thing without this kind of extension.  This is a complex topic,
and many people may not feel this way, but I personally avoid language
extension for this specific use-case.

### Zig
For this library, I found that there are many options, especially around
dealing with endianness. Zig does better with bitfields then C or Rust- they
have a defined layout and should only access bytes that are required (which is
important for hardware access). Zig also has the ability to work with integers
of bit sizes that are not powers of 2, like a u3 as an unsigned three bit
integer, which is nice as it describes the fields of a bit field without
worrying as much about invalid values when getting and setting fields.
Knowing this, I was determined to use bitfields for
this library and finally get bit level access to a binary format.


However, these bit fields have one limitation for this particular binary layout-
while Zig bit fields pack bits in a big-endian order, within each byte
they pack Least Significant Bit (LSB) to Most Significant Bit (MSB). This
is the packing in some formats, but the binary data I usually deal with
packs from MSB to LSB in the first byte, moving to the next byte when all
bits are used up, and this is the case in CCSDS. This can also be seen
as packing LSB to MSB, but starting at the least significant byte of
the byte aligned sequence, which is harder to state.


It turns out that the Zig bitfield packing can still be used in this situation,
but with a little bit of extra work. It looks like if you data packs
the way Zig bitfields natively pack it, then the format can be easily described
directly in bitfields. Otherwise, a system like the one used in this
library can be used (described below).

## Accessing Bit Packed Data
Getting and setting fields within a bit field structure is an occasional
task of embedded programming, so we want a strategy we can apply to these
situations. They do not come up as often as other tasks, but when they
do they are usually very important- perhaps part of the core requirements
of a system.


### Zig Native Bit Packing
As stated above, if your data is bit packed in the native format provided
by Zig, just encode the fields in a bit field and you are done. access
the fields as normal, and learn Zig's rules on non-byte-aligned data.


If you want, fields can be wrapped in types, so the u3 for the version
number can be renamed to Version, to help communicate intent and
avoid mixing fields with the same width, but this is a design choice
that is up to you.


An example of this for the sequence flags would be:
```zig
pub const CcsdsSequence = packed struct {
    seq_flag: SeqFlag = SeqFlag.Unsegmented,
    sequence: Sequence = 0,
};
```

Which in bits, from MSB to LSB of the most significant byte to least
significant byte, where where F is a bit cooresponding to the sequence flag,
and S is a bit cooresponding to the sequence count:
```
SSSS SFFF SSSS SSSS
```


### CCSDS Bit Packing
If your fields bit pack in the opposite order, you need a way to
create the packing:
```
FFFS SSSS SSSS SSSS
```

One attempt might be to swap the field order, like so:
```zig
pub const CcsdsSequence = packed struct {
    sequence: Sequence = 0,
    seq_flag: SeqFlag = SeqFlag.Unsegmented,
};
```

This creates the following bit packing:
```
SSSS SSSS FFFS SSSS
```
So close! In fact, we also have to swap bytes to get:
```
FFFS SSSS SSSS SSSS
```
which is what we want.


This means that we need to wrap field accesses in some way to
ensure that the byte-aligned integer that contains the field
is read, byte swapped, used, and then (for setters) byte swapped
again and placed in memory. In other words, we need to ensure
that swapping occurs before and after using a field to
get the designed bit packing.


I played around with various designs, such as wrapping types
to contain type-level information about endianness and size,
but I ended up no a fairly simple design that can automate
some of the details through comptime programming.

### Creating Fields
The design here is that each byte-aligned sequence, in this
case the 'control' word, 'sequence' word, and length word,
each get their own type, which is a bitfield. I choose
to rename some bit types like Apid instead of using u11,
but again, that is a design decision and not essential.


Once each bit field was defined, I created getters and setters
for each field. These are required to ensure that the fields
are accessed on correctly laid out fields. This is the one
place where language features like properties (where
accessing the fields can implcitly happen through a function),
or injecting generated functions in a structure (kind of
Ruby style monkey patching) would make the use of these
structure slightly simplier.


However, I've very, very glad that Zig does not include these features- what I
want out of ZIg is not programmer convienence, not is it every cool programming
feature of modern languages. I want something small and predictable,
where I control the flow of the program, the layout of data in memory,
and I do not get bogged down in complex language feature. There are
plenty of languages with fancy features for when we want them- I want to
see languages choose discipline and control for times when we need it.


Speaking of fancy language features, the getters are setters are
done using the set\_field\_swapped, and get\_field\_swapped function.
These use comptime information to generally access a field of
structure on a byte swapped version of the structure. They
are not perfect- I believe they can be written more generically
by using byte arrays instead of integer types for swapping, but
get do automate the getter/setter pairs.


#### Comptime
Overall I am finding that comptime is perhaps the most challenging
and interesting feature of Zig. I very much like its ability
to perform introspection (I wish so much for this in C), to
create polymorphic types, and its dependent type style capabilities.
Its possible that it could make things difficult down the line- I truely
don't know- such as for code analysis which needs to run a Turing complete
language in order to analyze a file. Perhaps there could be some
restrictions on the use of comptime, or perhaps comptime itself
can perform the required analysis, but I think its too early
to tell.


Either way, it turned out to be useful in this scenario,
even though some of the error messages when I got it wrong where
quite difficult to understand, and I ran into an
not-yet-implemented feature of inferring return types of
comptime functions, which lead me to take an extra type parameter
that would otherwise not be needed.

### Defining Structures
Once each byte-aligned set of fields was broken out into a packed struct,
the CcsdsPrimary structure is just each field in sequence:
```zig
pub const CcsdsPrimary = packed struct {
    control: CcsdsControl,
    sequence: CcsdsSequence,
    length: CcsdsLength,
};
```
There are functions in here as well, but for simplicity this is the structure.

To access, say, the APID of a variable with type CcsdsPrimary, you would
access its 'control' field and use the 'get\_apid' function:
```zig
const primary = /* Create Primary Header */;
std.debug.print("APID = {}", .{ primary.control.get_apid() });
```
This is not the most convienent, and the getters and setters could have
been moved into the CcsdsPrimary structure itself to avoid that field
access, but I felt like this design is the most generally applicable-
create these substructures with field accessors, combine them into
a full structure with all fields, and access your data through field
and accessor functions.


## Conclusion
Overall I think this is the best CCSDS Primary Header library I've ever written.


My C version has to constantly deal with potential errors due to NULL pointers
(which I check in every function, every time), and has to do a lot
of manual bit manipulation. My Rust version does not have the error
cases of the C version, but does the same bit manipulation as I did not
want to extend the language with macros. The Zig version is the only
one that does not have error conditions *and* does not require bit manipulation,
although at the cost of extra syntax in getters and setters and a pair
of perhaps tricky generic accessor functions to help write the accessor
functions.


Both the Rust and Zig version are great for unit testing- I find that
I benefit a great deal from being able to write simple tests alongside
my code and run them quickly. My C version does have tests, using
the Unity test framework from ThrowTheSwitch, but I have to deal with
building it myself, and my tests are in a separate file so I can 
compile them out of release builds.


I did not tackle other concerns for a library like this, like validating
headers, handling secondary headers or data sections (which requires
casting byte arrays to different types), or data integrity checking
such as checksums or CRCs. I would add these if I were using this library
for real work, but for now I'm quite pleased with how this worked in
Zig. I will continue to withhold judgement on the language until I've used
it in anger, but it continues to impress me, even having now worked
out something simple but non-trivial with it.
