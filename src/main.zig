const builtin = @import("builtin");
const Endian = builtin.Endian;
const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;

pub fn EndianWrapped(comptime typ: type, comptime endian: Endian) type {
    return packed struct {
        val: typ,

        const Self = @This();

        pub fn new(val: typ) Self {
            return Self{ .val = val };
        }

        pub fn swap(self: Self) EndianWrapped(type, opposite_endian(endian)) {
            const swapped_val = generic_swap(typ, self.val);

            const swapped = EndianWrapped(type, opposite_endian(endian)).new(swapped);
            return swapped;
        }
    };
}

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

pub const CcsdsPrimaryRaw = packed struct {
    control: u16,
    sequence: u16,
    length: u16,
};

pub fn opposite_endian(endian: Endian) Endian {
    switch (endian) {
        Endian.Big => {
            return Endian.Little;
        },

        Endian.Little => {
            return Endian.Big;
        },
    }
}

pub fn generic_swap(comptime T: type, val: T) T {
    comptime const num_bits = @bitSizeOf(T);

    if (num_bits == 0) {
        @panic("0 bit size may indicate comptime type. This function does not make sense at comptime");
    }

    if (num_bits % 8 != 0) {
        @panic("Swapping a type that is not bit-aligned does not make sense!");
    }

    comptime const num_bytes = num_bits / 8;

    // NOTE consider using inline
    var bytes = @bitCast([num_bytes]u8, val);
    const mid_byte_index = num_bytes / 2;
    var index = 0;
    while (index < mid_byte_index) {
        const tmp = bytes[index];
        bytes[index] = bytes[num_bytes - index];
        bytes[num_bytes - index] = tmp;
    }
}

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
    control: EndianWrapped(CcsdsControl, Endian.Big),
    sequence: EndianWrapped(CcsdsSequence, Endian.Big),
    length: EndianWrapped(CcsdsLength, Endian.Big),

    const Self = @This();

    pub fn new(apid: Apid, packet_type: PacketType) Self {
        var pri = Self{
            .control = EndianWrapped(CcsdsControl, Endian.Big).new(CcsdsControl.new(apid, packet_type)),
            .sequence = EndianWrapped(CcsdsSequence, Endian.Big).new(CcsdsSequence.new()),
            .length = EndianWrapped(CcsdsLength, Endian.Big).new(CcsdsLength.new()),
        };

        return pri;
    }

    pub fn set_apid(self: *Self, apid: Apid) void {
        var swapped = self.control.swap();
        swapped.val.apid = apid;
        self.control = swapped.swap();
    }

    pub fn get_apid(self: Self) Apid {
        const swapped = self.control.swap();
        return swapped.val.apid;
    }
};

test "primary header" {
    const apid = 0x0012;
    const apid_raw = 0x1200;
    const pri = CcsdsPrimary.new(apid, PacketType.Data);

    assert(pri.get_apid() == 0x0012);
}
