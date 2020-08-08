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
        var swapped = @bitCast(CcsdsControl, @byteSwap(u16, @bitCast(u16, self.control)));
        swapped.apid = apid;
        self.control = @bitCast(CcsdsControl, @byteSwap(u16, @bitCast(u16, swapped)));
    }

    pub fn get_apid(self: Self) Apid {
        const swapped = @bitCast(CcsdsControl, @byteSwap(u16, @bitCast(u16, self.control)));
        return swapped.apid;
    }
};

pub fn set_field_swapped(comptime T: type, value: anytype, field_name: []const u8, field_val: anytype) anytype {
    var swapped = @bitCast(@TypeOf(value), @byteSwap(T, @bitCast(T, @field(value, field_name))));
    @field(swapped, field_name) = field_value;
    return @bitCast(@TypeOf(value), @byteSwap(T, @bitCast(T, swapped)));
}

pub fn get_field_swapped(comptime T: type, value: anytype, field_name: []const u8) anytype {
    const swapped = @bitCast(CcsdsControl, @byteSwap(u16, @bitCast(u16, self.control)));
    return swapped.apid;
}

test "primary header" {
    const apid = 0x0012;
    const apid_raw = 0x1200;
    const pri = CcsdsPrimary.new(apid, PacketType.Data);

    assert(pri.get_apid() == apid);
}
