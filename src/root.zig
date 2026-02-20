const std = @import("std");



pub const UUID = struct {
    bits : std.bit_set.IntegerBitSet(128) , // 128 bits


    const Self = @This();


    const hex_chars = "0123456789abcdef";
    const version7 : u4 = 7 ; //    0b0111 
    const variant : u2 = 0b10 ;  //the variant specided in https://www.rfc-editor.org/rfc/rfc9562.html
                                  

    // follows uuid v7 implementation as defined in https://www.rfc-editor.org/rfc/rfc9562.html
    pub fn initV7() Self {
        
        const unix_ts_ms : u48 = @truncate(@as(u64 ,@intCast(std.time.milliTimestamp()))) ; // 64 -48 = 16 

        const rand = std.crypto.random;
        const rand_a : u12 = rand.int(u12);
        const rand_b : u62 = rand.int(u62);

        const ts_mask : u128 =  @as(u128,unix_ts_ms) << 80; // 128 - 48 - 0 
        const version_mask: u128 = @as(u128,version7) << 76; // 128 - 4 - 48 
        const variant_mask: u128 = @as(u128,variant) << 62; // 128 - 2 - 64
        const rand_a_mask: u128 = @as(u128,rand_a) << 64;   // 128 - 12 - 52
        const rand_b_mask : u128 = @as(u128,rand_b);        // 128 - 62 - 66

        var bitSet = std.bit_set.IntegerBitSet(128).initEmpty();
        bitSet.mask |= ts_mask | version_mask | variant_mask | rand_a_mask | rand_b_mask;


        const uuid = Self{
            .bits =  bitSet,
        };

        return uuid;

    }
    
    pub fn fromBitString(str : []const u8) !UUID  {

      if (str.len != 128) {
          return error.InvalidBitStringLength;
      }

      var bitSet = std.bit_set.IntegerBitSet(128).initEmpty();
      for (str,0..) |c,i| {
          switch (c) {
            '1' => bitSet.set(127-i),
            '0' => continue,
            else => return error.InvalidBitString

          }
          
      }
      return .{ .bits = bitSet };
    }

    pub fn fromString(str : []const u8) !Self {
       if (str.len != 36 ) {
           return error.InvalidUuuidString;
       }

    }

    pub fn toString(self:Self,buf:[]u8) ![]u8 {

       var chars :[32]u8 = undefined;

       for (0..32) | i | {
         var nibble : u4 = 0;
         const offset = i * 4; // 4 bits = 1 nibble = 1 hex char;
         inline for (0..4) | j | {

             // bit 0   = least significant bit
             // bit 127 = most significant bit
             const bit_index = 127 - (offset + j);
             if (self.bits.isSet(bit_index)) {
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

       const formatted = try std.fmt.bufPrint(buf,"{s}-{s}-{s}-{s}-{s}",.{g1,g2,g3,g4,g5});
       return formatted;
    }

};


test "formatBitsToHex" {
   const bitArray  = "11111000000111010100111110101110011111011110110000010001110100001010011101100101000000001010000011001001000111100110101111110110";

   const uuid = try UUID.fromBitString(bitArray);
   var buf : [36]u8 = undefined;
   const string =  try uuid.toString(&buf);
   std.debug.print("formatted string {s}\n", .{string});
   try std.testing.expectEqual(true,std.mem.eql(u8, string,"f81d4fae-7dec-11d0-a765-00a0c91e6bf6"));



}

test "generation" {
    const uuid = UUID.initV7();

   var buf : [36]u8 = undefined;
   const string =  try uuid.toString(&buf);
   std.debug.print("generated uuid string {s}\n", .{string});
}
