const std = @import("std");



pub const UUID = struct {
    bits : u128 ,


    const Self = @This();


    const hex_chars = "0123456789abcdef";
    const variant : u2 = 0b10 ;  //the variant specided in https://www.rfc-editor.org/rfc/rfc9562.html
                                  

    // follows uuid v7 implementation as defined in https://www.rfc-editor.org/rfc/rfc9562.html
    //
    //  0                   1                   2                   3
    //  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
    // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    // |                           unix_ts_ms                          |
    // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    // |          unix_ts_ms           |  ver  |  rand_a (12 bit seq)  |
    // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    // |var|                        rand_b                             |
    // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    // |                            rand_b                             |
    // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    //
    /// UUID version 7 features a time-ordered value field derived from the widely
    /// implemented and well known Unix Epoch timestamp source,
    /// the number of milliseconds seconds since midnight 1 Jan 1970 UTC, leap seconds excluded.
    /// As well as improved entropy characteristics over versions 1 or 6.
    ///
    /// see https://datatracker.ietf.org/doc/html/rfc9562#name-uuid-version-7
    ///
    /// Implementations SHOULD utilize UUID version 7 over UUID version 1 and 6 if possible.
    pub fn initV7() Self {
        
        const unix_ts_ms : u48 = @truncate(@as(u64 ,@intCast(std.time.milliTimestamp()))) ; // 64 -48 = 16 

        const version7 : u4 = 7 ; //    0b0111 
        const rand = std.crypto.random;
        const rand_a : u12 = rand.int(u12);
        const rand_b : u62 = rand.int(u62);

        const ts_mask : u128 =  @as(u128,unix_ts_ms) << 80; // 128 - 48 - 0 
        const version_mask: u128 = @as(u128,version7) << 76; // 128 - 4 - 48 
        const variant_mask: u128 = @as(u128,variant) << 62; // 128 - 2 - 64
        const rand_a_mask: u128 = @as(u128,rand_a) << 64;   // 128 - 12 - 52
        const rand_b_mask : u128 = @as(u128,rand_b);        // 128 - 62 - 66

        const bits : u128 = ts_mask | version_mask | variant_mask | rand_a_mask | rand_b_mask;


        const uuid = Self{
            .bits =  bits,
        };

        return uuid;

    }
    

    pub fn initV4() Self {
        return Self{
            .bits = 0,
        };
    }


    pub fn fromString(str : []const u8) !Self {
       if (str.len != 36 ) {
           return error.InvalidUuuidString;
       }

       var string : [32] u8 =   undefined;
       var i:usize = 0 ;

       for (str)|char|{
           if (char == '-'){
               continue;
           }
           string[i] = char;
           i += 1;
       }

       const int :u128 = try std.fmt.parseInt(u128, &string , 16);
       return Self{
           .bits = int
       };
       

    }

    pub fn eql(self:Self , other:Self) bool {
        return self.bits == other.bits;
    }

    pub fn greaterThan(self:Self , other:Self) bool {
        return self.bits > other.bits;
    }


    pub fn toString(self:Self) ![36]u8 {

       var buf : [36]u8 = undefined;

       var chars :[32]u8 = undefined;

       for (0..32) | i | {
         var nibble : u4 = 0;
         const offset = i * 4; // 4 bits = 1 nibble = 1 hex char;
         inline for (0..4) | j | {

             // bit 0   = least significant bit
             // bit 127 = most significant bit
             const bit_index: u7 = @intCast(127 - (offset + j));

             if (((self.bits >> bit_index) & 1) != 0 ) {
                 const mask : u4 = 1 << (3-j) ;
                 nibble = nibble | mask;
             }
         }

         chars[i] = hex_chars[nibble];
       }

       const g1 = chars[0..8];
       const g2 = chars[8..12];
       const g3 = chars[12..16];
       const g4 = chars[16..20];
       const g5 = chars[20..];

       _ = try std.fmt.bufPrint(&buf,"{s}-{s}-{s}-{s}-{s}",.{g1,g2,g3,g4,g5});
       return buf;
    }

};





test "from integer" {
   const bitArray: u128  = 0b11111000000111010100111110101110011111011110110000010001110100001010011101100101000000001010000011001001000111100110101111110110 ;

   const uuid = UUID{.bits = bitArray};
   // var buf : [36]u8 = undefined;
   const string =  try uuid.toString();
   try std.testing.expectEqual(true,std.mem.eql(u8, &string,"f81d4fae-7dec-11d0-a765-00a0c91e6bf6"));



}

test "uuid v7 generation" {
    const iterations = 256;
    var generated : [iterations]UUID = undefined;

    for (0..iterations)|i|{

        const uuid = UUID.initV7();

        // each new generated uuid should be unique
        for (generated[0..i]) |prev| {
            try std.testing.expect(!uuid.eql(prev));
        }

        generated[i] = uuid;

    }

}

test "to and from string" {
   const uuid = UUID.initV7();

   const string =  try uuid.toString();
   const uuid2 = try UUID.fromString(&string);

   try std.testing.expect(uuid.bits == uuid2.bits);

}


// Benchmark tests
test "Benchmark v7 creation" {
    const iterations = 1_000_000;

    var timer = try std.time.Timer.start();

    var sum: u128 = 0; // prevent optimization

    for (0..iterations) |_| {
        const uuid = UUID.initV7();
        sum +%= uuid.bits; // use the value
    }

    const elapsed = timer.read();

    const ns_per_op = elapsed / iterations;

    std.debug.print(
        \\UUIDv7 Benchmark (Zig)
        \\Iterations: {}
        \\Total time: {} ms
        \\ns/op: {}
        \\ignore: {}
        \\
    ,
        .{
            iterations,
            elapsed / 1_000_000,
            ns_per_op,
            sum,
        },
    );
}

// Benchmark tests
test "Benchmark to string" {
    const iterations = 1_000_000;

    const uuid = UUID.initV7();
    var timer = try std.time.Timer.start();


    for (0..iterations) |_| { 
        _ = try uuid.toString();
        
    }

    const elapsed = timer.read();

    const ns_per_op = elapsed / iterations;

    std.debug.print(
        \\Benchmark to string (Zig)
        \\Iterations: {}
        \\Total time: {} ms
        \\ns/op: {}
        \\
    ,
        .{
            iterations,
            elapsed / 1_000_000,
            ns_per_op,
        },
    );
}
