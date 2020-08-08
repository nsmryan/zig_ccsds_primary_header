const builtin = @import("builtin");
const Endian = builtin.Endian;
const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;

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

pub const CcsdsControl = packed struct {
    apid: Apid,
    secondary_header_flag: SecHeaderPresent = SecHeaderPresent.NotPresent,
    packet_type: PacketType,
    version: u3 = 0,

    pub fn new(apid: Apid, packet_type: PacketType) CcsdsControl {
        return CcsdsControl{ .apid = apid, .packet_type = packet_type };
    }
};

pub const CcsdsSequence = packed struct {
    sequence: Sequence = 0,
    seq_flag: SeqFlag = SeqFlag.Unsegmented,

    pub fn new() CcsdsSequence {
        return CcsdsSequence{};
    }
};

pub const CcsdsLength = packed struct {
    length: u16 = 0,

    pub fn new() CcsdsLength {
        return CcsdsLength{};
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
            .sequence = CcsdsSequence.new(),
            .length = CcsdsLength.new(),
        };

        pri.set_apid(apid);

        // TODO set packet_type

        return pri;
    }

    // NOTE consider a function that takes the type, casts, swaps, and casts back.
    // NOTE byteSwap apparently works with vectors, so perhaps can cast any object to bytes and still swap
    pub fn set_apid(self: *Self, apid: Apid) void {
        self.control = set_field_swapped(u16, CcsdsControl, self.control, "apid", apid);
    }

    pub fn get_apid(self: Self) Apid {
        return get_field_swapped(u16, Apid, self.control, "apid");
    }
};

pub fn set_field_swapped(comptime T: type, comptime V: type, value: V, comptime field_name: []const u8, field_value: anytype) V {
    var swapped = @bitCast(V, @byteSwap(T, @bitCast(T, value)));
    @field(swapped, field_name) = field_value;
    return @bitCast(V, @byteSwap(T, @bitCast(T, swapped)));
}

pub fn get_field_swapped(comptime T: type, comptime FieldType: type, value: anytype, comptime field_name: []const u8) FieldType {
    const swapped = @bitCast(@TypeOf(value), @byteSwap(T, @bitCast(T, value)));
    return @field(swapped, field_name);
}

test "primary header" {
    const apid: Apid = 0x0012;
    const apid2: Apid = 0x200;
    var pri = CcsdsPrimary.new(apid, PacketType.Data);

    assert(@sizeOf(CcsdsPrimary) == 6);

    assert(pri.get_apid() == apid);

    pri.set_apid(apid2);
    assert(pri.get_apid() == apid2);
}
