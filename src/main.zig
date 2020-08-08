const builtin = @import("builtin");
const Endian = builtin.Endian;
const std = @import("std");
const testing = std.testing;

pub const EndianInt = struct {
    endian: Endian,
};

pub fn native_endian(typ: type, val: typ) typ {}

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

pub fn OppositeEndian(comptime endian: Endian) Endian {
    switch (endian) {
        Endian.Big => {
            return Endian.Little;
        },

        Endian.Little => {
            return Endian.Big;
        },
    }
}

pub fn CcsdsPrimaryGeneric(comptime endian: Endian) type {
    return packed struct {
        apid: Apid,
        secondary_header_flag: SecHeaderPresent = SecHeaderPresent.NotPresent,
        packet_type: PacketType,
        version: u3 = 0,

        sequence: Sequence = 0,
        seq_flag: SeqFlag = SeqFlag.Unsegmented,

        length: u16 = 0,

        const Self = @This();

        pub fn new(apid: Apid, packet_type: PacketType) Self {
            var pri = Self{ .apid = apid, .packet_type = packet_type };

            if (endian != builtin.endian) {
                pri.byte_swap();
            }

            return pri;
        }

        pub fn byte_swap(self: *Self) void {
            var raw = @ptrCast(*CcsdsPrimaryRaw, self);
            raw.control = @byteSwap(u16, raw.control);
            raw.sequence = @byteSwap(u16, raw.sequence);
            raw.length = @byteSwap(u16, raw.length);
        }

        pub fn swap_endianness(self: Self) CcsdsPrimaryGeneric(OppositeEndian(endian)) {
            comptime const opposite_endian = OppositeEndian(endian);

            var swapped = @bitCast(CcsdsPrimaryGeneric(opposite_endian), self);
            swapped.byte_swap();

            return swapped;
        }

        pub fn set_apid(self: *Self, apid: Apid) void {
            if (endian == builtin.endian) {
                self.apid = apid;
            } else {
                const swapped = self.swap_endianness();
                swapped.apid = apid;
                *self = swapped.swap_endianness();
            }
        }

        pub fn get_apid(self: Self) Apid {
            if (endian == builtin.endian) {
                return self.apid;
            } else {
                const swapped = self.swap_endianness();
                return swapped.apid;
            }
        }
    };
}

const CcsdsPrimary = CcsdsPrimaryGeneric(Endian.Big);
const CcsdsPrimaryNative = CcsdsPrimaryGeneric(builtin.endian);

test "big endian primary header" {
    const apid = 0x0012;
    const apid_raw = 0x1200;
    const pri = CcsdsPrimary.new(apid, PacketType.Data);

    testing.expect(apid == pri.get_apid());

    const stderr = std.io.getStdErr().writer();
    testing.expect(apid_raw == pri.apid);
}

test "little endian primary header" {
    const apid = 0x12;
    const apid_raw = 0x0012;
    const pri = CcsdsPrimaryNative.new(apid, PacketType.Data);
    testing.expect(apid == pri.get_apid());
    testing.expect(apid_raw == pri.apid);
}
