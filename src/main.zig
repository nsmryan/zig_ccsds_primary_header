const builtin = @import("builtin");
const Endian = builtin.Endian;
const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;

pub const Version = u3;
pub const Apid = u11;

pub const SecHeaderPresent = enum(u1) {
    NotPresent = 0,
    Present = 1,
};

pub const PacketType = enum(u1) {
    Data = 0,
    Command = 1,
};

pub const Sequence = u14;

pub const SeqFlag = enum(u2) {
    Continuation = 0,
    FirstSegment = 1,
    LastSegment = 2,
    Unsegmented = 3,
};

pub const CCSDS_LENGTH_OFFSET: u16 = 7;

pub const CcsdsControl = packed struct {
    apid: Apid,
    secondary_header_flag: SecHeaderPresent = SecHeaderPresent.NotPresent,
    packet_type: PacketType,
    version: Version = 0,

    const Self = @This();

    pub fn new(apid: Apid, packet_type: PacketType) CcsdsControl {
        return CcsdsControl{ .apid = apid, .packet_type = packet_type };
    }

    pub fn default() CcsdsControl {
        return CcsdsControl{ .apid = 0, .packet_type = PacketType.Data };
    }

    // NOTE byteSwap apparently works with vectors, so perhaps can cast any object to bytes and still swap
    pub fn set_apid(self: *Self, apid: Apid) void {
        set_field_swapped(u16, CcsdsControl, self, "apid", apid);
    }

    pub fn get_apid(self: Self) Apid {
        return get_field_swapped(u16, Apid, self, "apid");
    }

    pub fn set_packet_type(self: *Self, packet_type: PacketType) void {
        set_field_swapped(u16, CcsdsControl, self, "packet_type", packet_type);
    }

    pub fn get_packet_type(self: Self) PacketType {
        return get_field_swapped(u16, PacketType, self, "packet_type");
    }

    pub fn set_version(self: *Self, version: Version) void {
        set_field_swapped(u16, CcsdsControl, self, "version", version);
    }

    pub fn get_version(self: Self) Version {
        return get_field_swapped(u16, Version, self, "version");
    }

    pub fn set_secondary_header_flag(self: *Self, secondary_header_flag: SecHeaderPresent) void {
        set_field_swapped(u16, CcsdsControl, self, "secondary_header_flag", secondary_header_flag);
    }

    pub fn get_secondary_header_flag(self: Self) SecHeaderPresent {
        return get_field_swapped(u16, SecHeaderPresent, self, "secondary_header_flag");
    }
};

pub const CcsdsSequence = packed struct {
    sequence: Sequence = 0,
    seq_flag: SeqFlag = SeqFlag.Unsegmented,

    const Self = @This();

    pub fn new(sequence: Sequence, seq_flag: SeqFlag) CcsdsSequence {
        return CcsdsSequence{ .sequence = sequence, .seq_flag = seq_flag };
    }

    pub fn default() CcsdsSequence {
        return CcsdsSequence{};
    }

    pub fn set_sequence(self: *Self, sequence: Sequence) void {
        set_field_swapped(u16, CcsdsSequence, self, "sequence", sequence);
    }

    pub fn get_version(self: Self) Sequence {
        return get_field_swapped(u16, Sequence, self, "sequence");
    }

    pub fn set_seq_flag(self: *Self, seq_flag: SeqFlag) void {
        set_field_swapped(u16, CcsdsSequence, self, "seq_flag", seq_flag);
    }

    pub fn get_seq_flag(self: Self) SeqFlag {
        return get_field_swapped(u16, SeqFlag, self, "seq_flag");
    }
};

pub const CcsdsLength = packed struct {
    length: u16 = 0,

    const Self = @This();

    pub fn new(length: u16) CcsdsLength {
        return CcsdsLength{ .length = length };
    }

    pub fn default() CcsdsLength {
        return CcsdsLength{};
    }

    pub fn set_length(self: *Self, length: u16) void {
        set_field_swapped(u16, CcsdsLength, self, "length", length);
    }

    pub fn get_length(self: Self) u16 {
        return get_field_swapped(u16, CcsdsLength, self, "length");
    }

    pub fn get_full_packet_length(self: Self) u16 {
        return self.get_length + CCSDS_LENGTH_OFFSET;
    }
};

pub const CcsdsPrimary = packed struct {
    control: CcsdsControl,
    sequence: CcsdsSequence,
    length: CcsdsLength,

    const Self = @This();

    pub fn new(apid: Apid, packet_type: PacketType) Self {
        var pri = Self{
            .control = CcsdsControl.new(0, PacketType.Data),
            .sequence = CcsdsSequence.default(),
            .length = CcsdsLength.default(),
        };

        pri.control.set_apid(apid);

        pri.control.set_packet_type(packet_type);

        return pri;
    }

    pub fn default() Self {
        return CcsdsPrimary.new(0, PacketType.Data);
    }
};

// NOTE these generic functions could infer return types, but this is not implemented in Zig yet
pub fn set_field_swapped(comptime T: type, comptime ValueType: type, value: *ValueType, comptime field_name: []const u8, field_value: anytype) void {
    var swapped = @bitCast(ValueType, @byteSwap(T, @bitCast(T, value.*)));
    @field(swapped, field_name) = field_value;
    value.* = @bitCast(ValueType, @byteSwap(T, @bitCast(T, swapped)));
}

pub fn get_field_swapped(comptime T: type, comptime FieldType: type, value: anytype, comptime field_name: []const u8) FieldType {
    const swapped = @bitCast(@TypeOf(value), @byteSwap(T, @bitCast(T, value)));
    return @field(swapped, field_name);
}

test "apid get/set" {
    const apid: Apid = 0x123;
    const apid2: Apid = 0x321;
    var pri = CcsdsPrimary.new(apid, PacketType.Data);

    assert(pri.control.get_apid() == apid);

    pri.control.set_apid(apid2);
    assert(pri.control.get_apid() == apid2);
}

test "primary header sizes" {
    assert(@sizeOf(CcsdsPrimary) == 6);
    assert(@sizeOf(CcsdsControl) == 2);
    assert(@sizeOf(CcsdsSequence) == 2);
    assert(@sizeOf(CcsdsLength) == 2);
}

test "primary header layout" {
    var pri = CcsdsPrimary.default();

    // set fields to reasonable values that fill up much of the bits

    // set first word (control word) values
    pri.control.set_apid(0x65A);
    pri.control.set_secondary_header_flag(SecHeaderPresent.Present);
    pri.control.set_packet_type(PacketType.Command);

    // set second word (sequence word) values
    pri.sequence.set_seq_flag(SeqFlag.Unsegmented);
    pri.sequence.set_sequence(0x05A5);

    // set third word (length word) values
    pri.length.set_length(0x1234);

    const bytes = std.mem.asBytes(&pri);

    // test first word
    assert(bytes[0] == 0x1E);
    assert(bytes[1] == 0x5A);

    // test second word
    assert(bytes[2] == 0xC5);
    assert(bytes[3] == 0xA5);

    // test third word
    assert(bytes[4] == 0x12);
    assert(bytes[5] == 0x34);
}
