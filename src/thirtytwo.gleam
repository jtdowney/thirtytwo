//// Base32 encoding and decoding for Gleam, targeting both Erlang and JavaScript.
////
//// Supports five base32 variants:
////
//// - **RFC 4648** (`encode` / `decode`) — the standard alphabet with optional
////   padding and case-insensitive decoding.
//// - **Extended Hex** (`hex_encode` / `hex_decode`) — preserves sort order of
////   the underlying binary data (RFC 4648 §7).
//// - **Crockford** (`crockford_encode` / `crockford_decode`) — omits I, L, O, U
////   to reduce ambiguity; supports hyphens, character aliases, and an optional
////   mod-37 check digit.
//// - **z-base-32** (`z_base_32_encode` / `z_base_32_decode`) — human-oriented
////   lowercase alphabet optimized for readability.
//// - **Geohash** (`geohash_encode` / `geohash_decode`) — the alphabet used by
////   the Geohash geocoding system.
////
//// ## Examples
////
//// ```gleam
//// thirtytwo.encode(<<"wibble":utf8>>, padding: True)
//// // -> "O5UWEYTMMU======"
////
//// thirtytwo.decode("O5UWEYTMMU======")
//// // -> Ok(<<"wibble":utf8>>)
////
//// thirtytwo.crockford_encode(<<"wibble":utf8>>, check: False)
//// // -> "EXMP4RKCCM"
//// ```

import gleam/bit_array
import gleam/bool
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/result
import gleam/string

const rfc4648_alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"

const hex_alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUV"

const crockford_alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

const crockford_check_alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ*~$=U"

const z_base_32_alphabet = "ybndrfg8ejkmcpqxot1uwisza345h769"

const geohash_alphabet = "0123456789bcdefghjkmnpqrstuvwxyz"

const pad_char = "="

fn bor(a: Int, b: Int) -> Int {
  int.bitwise_or(a, b)
}

fn band(a: Int, b: Int) -> Int {
  int.bitwise_and(a, b)
}

fn shl(a: Int, n: Int) -> Int {
  int.bitwise_shift_left(a, n)
}

fn shr(a: Int, n: Int) -> Int {
  int.bitwise_shift_right(a, n)
}

/// Encode a bit array using the standard RFC 4648 base32 alphabet.
/// The input must be byte-aligned; non-byte-aligned bit arrays produce
/// undefined results.
/// When `padding` is `True`, the output is padded with `=` to a multiple of 8.
pub fn encode(input: BitArray, padding padding: Bool) -> String {
  do_encode(input, rfc4648_alphabet, padding)
}

/// Decode a standard RFC 4648 base32 string. Padding is optional and
/// decoding is case-insensitive. Returns `Error(Nil)` on invalid input.
pub fn decode(input: String) -> Result(BitArray, Nil) {
  decode_with_padding(input, rfc4648_alphabet)
}

/// Encode a bit array using the base32hex alphabet (RFC 4648 section 7).
/// Preserves sort order of the underlying data. The input must be
/// byte-aligned; non-byte-aligned bit arrays produce undefined results.
/// When `padding` is `True`, the output is padded with `=` to a multiple of 8.
pub fn hex_encode(input: BitArray, padding padding: Bool) -> String {
  do_encode(input, hex_alphabet, padding)
}

/// Decode a base32hex string. Padding is optional and decoding is
/// case-insensitive. Returns `Error(Nil)` on invalid input.
pub fn hex_decode(input: String) -> Result(BitArray, Nil) {
  decode_with_padding(input, hex_alphabet)
}

/// Encode a bit array using Crockford's base32 alphabet. The output is
/// always unpadded and uppercase. The input must be byte-aligned;
/// non-byte-aligned bit arrays produce undefined results. When `check`
/// is `True`, a mod-37 check digit is appended.
pub fn crockford_encode(input: BitArray, check check: Bool) -> String {
  let encoded = do_encode(input, crockford_alphabet, False)
  case check && encoded != "" {
    True -> {
      let check_value = compute_check_value(input, 0)
      let check_char = string.slice(crockford_check_alphabet, check_value, 1)
      encoded <> check_char
    }
    False -> encoded
  }
}

/// Decode a Crockford base32 string. Hyphens are stripped, decoding is
/// case-insensitive, and the aliases O→0, I/L→1 are normalized. When
/// `check` is `True`, the trailing check digit is validated.
/// Returns `Error(Nil)` on invalid input or a failed check.
pub fn crockford_decode(
  input: String,
  check check: Bool,
) -> Result(BitArray, Nil) {
  let cleaned = string.replace(input, "-", "")
  let decode_map = build_crockford_decode_map()
  case check && cleaned != "" {
    True -> {
      use <- bool.guard(when: string.length(cleaned) < 2, return: Error(Nil))
      let body = string.drop_end(cleaned, 1)
      use check_char <- result.try(string.last(cleaned))
      let check_decode_map = build_decode_map(crockford_check_alphabet, True)
      use check_index <- result.try(dict.get(check_decode_map, check_char))
      use decoded <- result.try(do_decode(body, decode_map))
      let expected = compute_check_value(decoded, 0)
      use <- bool.guard(when: check_index != expected, return: Error(Nil))
      Ok(decoded)
    }
    False -> do_decode(cleaned, decode_map)
  }
}

/// Encode a bit array using the z-base-32 alphabet. The output is always
/// lowercase and unpadded. The input must be byte-aligned; non-byte-aligned
/// bit arrays produce undefined results.
pub fn z_base_32_encode(input: BitArray) -> String {
  do_encode(input, z_base_32_alphabet, False)
}

/// Decode a z-base-32 string. Decoding is case-sensitive.
/// Returns `Error(Nil)` on invalid input.
pub fn z_base_32_decode(input: String) -> Result(BitArray, Nil) {
  let decode_map = build_decode_map(z_base_32_alphabet, False)
  do_decode(input, decode_map)
}

/// Encode a bit array using the Geohash base32 alphabet. The output is
/// always lowercase and unpadded. The input must be byte-aligned;
/// non-byte-aligned bit arrays produce undefined results.
pub fn geohash_encode(input: BitArray) -> String {
  do_encode(input, geohash_alphabet, False)
}

/// Decode a Geohash base32 string. Decoding is case-sensitive.
/// Returns `Error(Nil)` on invalid input.
pub fn geohash_decode(input: String) -> Result(BitArray, Nil) {
  let decode_map = build_decode_map(geohash_alphabet, False)
  do_decode(input, decode_map)
}

fn decode_with_padding(input: String, alphabet: String) -> Result(BitArray, Nil) {
  let decode_map = build_decode_map(alphabet, True)
  validate_padding(input)
  |> result.try(do_decode(_, decode_map))
}

fn build_crockford_decode_map() -> Dict(String, Int) {
  build_decode_map(crockford_alphabet, True)
  |> dict.insert("O", 0)
  |> dict.insert("o", 0)
  |> dict.insert("I", 1)
  |> dict.insert("i", 1)
  |> dict.insert("L", 1)
  |> dict.insert("l", 1)
}

fn compute_check_value(input: BitArray, acc: Int) -> Int {
  case input {
    <<byte, rest:bytes>> -> compute_check_value(rest, { acc * 256 + byte } % 37)
    _ -> acc
  }
}

fn do_encode(input: BitArray, alphabet: String, padding: Bool) -> String {
  let alphabet_map =
    string.to_graphemes(alphabet)
    |> list.index_map(fn(char, index) { #(index, char) })
    |> dict.from_list
  do_encode_bytes(input, alphabet_map, [])
  |> list.reverse
  |> string.concat
  |> apply_padding(padding)
}

fn do_encode_bytes(
  input: BitArray,
  alphabet: Dict(Int, String),
  acc: List(String),
) -> List(String) {
  case input {
    <<b0, b1, b2, b3, b4, rest:bytes>> -> {
      encode_group(b0, b1, b2, b3, b4)
      |> list.map(lookup_char(alphabet, _))
      |> list.fold(acc, list.prepend)
      |> do_encode_bytes(rest, alphabet, _)
    }
    <<b0, b1, b2, b3>> -> encode_remainder(b0, b1, b2, b3, 7, alphabet, acc)
    <<b0, b1, b2>> -> encode_remainder(b0, b1, b2, 0, 5, alphabet, acc)
    <<b0, b1>> -> encode_remainder(b0, b1, 0, 0, 4, alphabet, acc)
    <<b0>> -> encode_remainder(b0, 0, 0, 0, 2, alphabet, acc)
    _ -> acc
  }
}

fn encode_group(b0: Int, b1: Int, b2: Int, b3: Int, b4: Int) -> List(Int) {
  let c0 = shr(b0, 3)
  let c1 = bor(shl(band(b0, 0x07), 2), shr(b1, 6))
  let c2 = band(shr(b1, 1), 0x1F)
  let c3 = bor(shl(band(b1, 0x01), 4), shr(b2, 4))
  let c4 = bor(shl(band(b2, 0x0F), 1), shr(b3, 7))
  let c5 = band(shr(b3, 2), 0x1F)
  let c6 = bor(shl(band(b3, 0x03), 3), shr(b4, 5))
  let c7 = band(b4, 0x1F)
  [c0, c1, c2, c3, c4, c5, c6, c7]
}

fn encode_remainder(
  b0: Int,
  b1: Int,
  b2: Int,
  b3: Int,
  count: Int,
  alphabet: Dict(Int, String),
  acc: List(String),
) -> List(String) {
  encode_group(b0, b1, b2, b3, 0)
  |> list.take(count)
  |> list.map(lookup_char(alphabet, _))
  |> list.fold(acc, list.prepend)
}

fn lookup_char(alphabet: Dict(Int, String), index: Int) -> String {
  dict.get(alphabet, index) |> result.unwrap("")
}

fn apply_padding(encoded: String, padding: Bool) -> String {
  use <- bool.guard(when: !padding, return: encoded)
  let remainder = string.length(encoded) % 8
  use <- bool.guard(when: remainder == 0, return: encoded)
  encoded <> string.repeat(pad_char, 8 - remainder)
}

fn build_decode_map(
  alphabet: String,
  case_insensitive: Bool,
) -> Dict(String, Int) {
  let chars = string.to_graphemes(alphabet)
  let pairs = list.index_map(chars, fn(char, index) { #(char, index) })
  let lower_pairs = case case_insensitive {
    True ->
      list.index_map(chars, fn(char, index) { #(string.lowercase(char), index) })
    False -> []
  }
  list.append(pairs, lower_pairs)
  |> dict.from_list
}

fn do_decode(
  input: String,
  decode_map: Dict(String, Int),
) -> Result(BitArray, Nil) {
  let chars = string.to_graphemes(input)
  use values <- result.try(
    list.try_map(chars, fn(c) { dict.get(decode_map, c) }),
  )
  let remainder = list.length(values) % 8
  use <- bool.guard(
    when: list.contains([1, 3, 6], remainder),
    return: Error(Nil),
  )
  decode_values(values, [])
}

fn validate_padding(input: String) -> Result(String, Nil) {
  let len = string.length(input)
  let pad_count = count_trailing_pad(input, len)
  use <- bool.guard(when: pad_count == 0, return: Ok(input))
  let has_interior_pad =
    string.contains(string.drop_end(input, pad_count), pad_char)
  use <- bool.guard(when: has_interior_pad, return: Error(Nil))
  use <- bool.guard(when: len % 8 != 0, return: Error(Nil))
  case pad_count {
    1 | 3 | 4 | 6 -> Ok(string.drop_end(input, pad_count))
    _ -> Error(Nil)
  }
}

fn count_trailing_pad(input: String, remaining: Int) -> Int {
  case remaining > 0 && string.ends_with(input, pad_char) {
    True -> count_trailing_pad(string.drop_end(input, 1), remaining - 1) + 1
    False -> 0
  }
}

fn decode_values(
  values: List(Int),
  acc: List(BitArray),
) -> Result(BitArray, Nil) {
  case values {
    [v0, v1, v2, v3, v4, v5, v6, v7, ..rest] -> {
      let #(byte0, byte1, byte2, byte3, byte4) =
        decode_group(v0, v1, v2, v3, v4, v5, v6, v7)
      decode_values(rest, [<<byte0, byte1, byte2, byte3, byte4>>, ..acc])
    }
    [] -> Ok(acc |> list.reverse |> bit_array.concat)
    remaining -> decode_remainder(remaining, acc)
  }
}

fn decode_group(
  v0: Int,
  v1: Int,
  v2: Int,
  v3: Int,
  v4: Int,
  v5: Int,
  v6: Int,
  v7: Int,
) -> #(Int, Int, Int, Int, Int) {
  let byte0 = bor(shl(v0, 3), shr(v1, 2))
  let byte1 = bor(shl(band(v1, 0x03), 6), bor(shl(v2, 1), shr(v3, 4)))
  let byte2 = bor(shl(band(v3, 0x0F), 4), shr(v4, 1))
  let byte3 = bor(shl(band(v4, 0x01), 7), bor(shl(v5, 2), shr(v6, 3)))
  let byte4 = bor(shl(band(v6, 0x07), 5), v7)
  #(byte0, byte1, byte2, byte3, byte4)
}

fn decode_remainder(
  values: List(Int),
  acc: List(BitArray),
) -> Result(BitArray, Nil) {
  let #(last_value, mask, byte_count) = case values {
    [_, v1] -> #(v1, 0x03, 1)
    [_, _, _, v3] -> #(v3, 0x0F, 2)
    [_, _, _, _, v4] -> #(v4, 0x01, 3)
    [_, _, _, _, _, _, v6] -> #(v6, 0x07, 4)
    _ -> #(0, 0, 0)
  }
  use <- bool.guard(when: byte_count == 0, return: Error(Nil))
  use <- bool.guard(when: band(last_value, mask) != 0, return: Error(Nil))
  let padded = list.append(values, list.repeat(0, 8 - list.length(values)))
  case padded {
    [v0, v1, v2, v3, v4, v5, v6, v7] -> {
      let #(b0, b1, b2, b3, _) = decode_group(v0, v1, v2, v3, v4, v5, v6, v7)
      let bytes = <<b0, b1, b2, b3>>
      Ok(
        [bit_array.slice(bytes, 0, byte_count) |> result.unwrap(<<>>), ..acc]
        |> list.reverse
        |> bit_array.concat,
      )
    }
    _ -> Error(Nil)
  }
}
