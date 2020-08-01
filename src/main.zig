const builtin = @import("builtin");
const Endian = builtin.Endian;
const std = @import("std");
const testing = std.testing;

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

pub fn CcsdsPrimaryGeneric(comptime endian: Endian) type {
    return packed struct {
        control: packed union {
            fields: packed struct {
                apid: Apid,
                secondary_header_flag: SecHeaderPresent = SecHeaderPresent.NotPresent,
                packet_type: PacketType,
                version: u3 = 0,
            },

            raw: u16,
        },

        sequence: packed union {
            fields: packed struct {
                sequence: Sequence = 0,
                seq_flag: SeqFlag = SeqFlag.Unsegmented,
            },

            raw: u16,
        },

        length: u16,

        const Self = @This();

        pub fn new(apid: Apid, packet_type: PacketType) Self {
            var pri = Self{ .apid = apid, .packet_type = packet_type };

            if (endian == builtin.endian) {
                pri.f1 = f1;
            } else {
                pri.f1 = @byteSwap(u16, f1);
            }

            return pri;
        }

        pub fn set_f1(self: Self, f1: u16) void {
            if (endian == builtin.endian) {
                self.f1 = f1;
            } else {
                self.f1 = @byteSwap(u16, f1);
            }
        }

        pub fn get_f1(self: Self) u16 {
            if (endian == builtin.endian) {
                return self.f1;
            } else {
                return @byteSwap(u16, self.f1);
            }
        }
    };
}

const CcsdsPrimary = CcsdsPrimaryGeneric(Endian.Big);
const CcsdsPrimaryNative = CcsdsPrimaryGeneric(builtin.endian);

test "big endian primary header" {
    const val = 0x0012;
    const val_raw = 0x1200;
    const pri = CcsdsPrimary.new(val);

    testing.expect(val == pri.get_f1());

    const stderr = std.io.getStdErr().writer();
    testing.expect(val_raw == pri.f1);
}

test "little endian primary header" {
    const val = 0x12;
    const val_raw = 0x0012;
    const pri = CcsdsPrimaryNative.new(val);
    testing.expect(val == pri.get_f1());
    testing.expect(val_raw == pri.f1);
}
