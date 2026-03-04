import qcheck
import thirtytwo
import unitest

pub fn main() -> Nil {
  unitest.main()
}

pub fn encode_rfc4648_test_vectors_test() {
  assert thirtytwo.encode(<<>>, padding: True) == ""
  assert thirtytwo.encode(<<"f":utf8>>, padding: True) == "MY======"
  assert thirtytwo.encode(<<"fo":utf8>>, padding: True) == "MZXQ===="
  assert thirtytwo.encode(<<"foo":utf8>>, padding: True) == "MZXW6==="
  assert thirtytwo.encode(<<"foob":utf8>>, padding: True) == "MZXW6YQ="
  assert thirtytwo.encode(<<"fooba":utf8>>, padding: True) == "MZXW6YTB"
  assert thirtytwo.encode(<<"foobar":utf8>>, padding: True)
    == "MZXW6YTBOI======"
}

pub fn encode_no_padding_test() {
  assert thirtytwo.encode(<<"f":utf8>>, padding: False) == "MY"
  assert thirtytwo.encode(<<"foobar":utf8>>, padding: False) == "MZXW6YTBOI"
}

pub fn decode_rfc4648_test_vectors_test() {
  assert thirtytwo.decode("") == Ok(<<>>)
  assert thirtytwo.decode("MY======") == Ok(<<"f":utf8>>)
  assert thirtytwo.decode("MZXQ====") == Ok(<<"fo":utf8>>)
  assert thirtytwo.decode("MZXW6===") == Ok(<<"foo":utf8>>)
  assert thirtytwo.decode("MZXW6YQ=") == Ok(<<"foob":utf8>>)
  assert thirtytwo.decode("MZXW6YTB") == Ok(<<"fooba":utf8>>)
  assert thirtytwo.decode("MZXW6YTBOI======") == Ok(<<"foobar":utf8>>)
}

pub fn decode_no_padding_test() {
  assert thirtytwo.decode("MY") == Ok(<<"f":utf8>>)
  assert thirtytwo.decode("MZXW6YTBOI") == Ok(<<"foobar":utf8>>)
}

pub fn decode_case_insensitive_test() {
  assert thirtytwo.decode("mzxw6ytb") == Ok(<<"fooba":utf8>>)
  assert thirtytwo.decode("MzXw6YtB") == Ok(<<"fooba":utf8>>)
}

pub fn decode_invalid_char_test() {
  assert thirtytwo.decode("M!======") == Error(Nil)
  assert thirtytwo.decode("01234567") == Error(Nil)
}

pub fn decode_invalid_length_test() {
  assert thirtytwo.decode("A") == Error(Nil)
  assert thirtytwo.decode("AAA") == Error(Nil)
  assert thirtytwo.decode("AAAAAA") == Error(Nil)
}

pub fn decode_non_canonical_bits_test() {
  assert thirtytwo.decode("MZ======") == Error(Nil)
}

pub fn decode_malformed_padding_test() {
  assert thirtytwo.decode("MY=") == Error(Nil)
  assert thirtytwo.decode("MY=======") == Error(Nil)
  assert thirtytwo.decode("====") == Error(Nil)
  assert thirtytwo.decode("MY==MZXQ") == Error(Nil)
}

pub fn encode_decode_roundtrip_test() {
  use input <- qcheck.given(qcheck.byte_aligned_bit_array())
  assert thirtytwo.decode(thirtytwo.encode(input, padding: True)) == Ok(input)
  assert thirtytwo.decode(thirtytwo.encode(input, padding: False)) == Ok(input)
}

pub fn hex_encode_rfc4648_test_vectors_test() {
  assert thirtytwo.hex_encode(<<>>, padding: True) == ""
  assert thirtytwo.hex_encode(<<"f":utf8>>, padding: True) == "CO======"
  assert thirtytwo.hex_encode(<<"fo":utf8>>, padding: True) == "CPNG===="
  assert thirtytwo.hex_encode(<<"foo":utf8>>, padding: True) == "CPNMU==="
  assert thirtytwo.hex_encode(<<"foob":utf8>>, padding: True) == "CPNMUOG="
  assert thirtytwo.hex_encode(<<"fooba":utf8>>, padding: True) == "CPNMUOJ1"
  assert thirtytwo.hex_encode(<<"foobar":utf8>>, padding: True)
    == "CPNMUOJ1E8======"
}

pub fn hex_encode_cross_impl_test() {
  assert thirtytwo.hex_encode(
      <<"Hello!":utf8, 0xDE, 0xAD, 0xBE, 0xEF>>,
      padding: False,
    )
    == "91IMOR3F47FARFNF"
}

pub fn hex_decode_cross_impl_test() {
  assert thirtytwo.hex_decode("91IMOR3F47FARFNF")
    == Ok(<<"Hello!":utf8, 0xDE, 0xAD, 0xBE, 0xEF>>)
}

pub fn hex_decode_case_insensitive_test() {
  assert thirtytwo.hex_decode("cpnmu===") == Ok(<<"foo":utf8>>)
}

pub fn hex_decode_invalid_char_test() {
  assert thirtytwo.hex_decode("WX======") == Error(Nil)
}

pub fn hex_roundtrip_test() {
  use input <- qcheck.given(qcheck.byte_aligned_bit_array())
  assert thirtytwo.hex_decode(thirtytwo.hex_encode(input, padding: True))
    == Ok(input)
  assert thirtytwo.hex_decode(thirtytwo.hex_encode(input, padding: False))
    == Ok(input)
}

pub fn crockford_encode_test() {
  assert thirtytwo.crockford_encode(<<>>, check: False) == ""
  assert thirtytwo.crockford_encode(<<0>>, check: False) == "00"
  assert thirtytwo.crockford_encode(<<255>>, check: False) == "ZW"
  assert thirtytwo.crockford_encode(<<"f":utf8>>, check: False) == "CR"
}

pub fn crockford_encode_cross_impl_test() {
  assert thirtytwo.crockford_encode(
      <<0xF8, 0x3E, 0x0F, 0x83, 0xE0>>,
      check: False,
    )
    == "Z0Z0Z0Z0"
  assert thirtytwo.crockford_encode(
      <<"Hello!":utf8, 0xDE, 0xAD, 0xBE, 0xEF>>,
      check: False,
    )
    == "91JPRV3F47FAVFQF"
}

pub fn crockford_decode_cross_impl_test() {
  assert thirtytwo.crockford_decode("Z0Z0Z0Z0", check: False)
    == Ok(<<0xF8, 0x3E, 0x0F, 0x83, 0xE0>>)
  assert thirtytwo.crockford_decode("91JPRV3F47FAVFQF", check: False)
    == Ok(<<"Hello!":utf8, 0xDE, 0xAD, 0xBE, 0xEF>>)
}

pub fn crockford_decode_case_insensitive_test() {
  assert thirtytwo.crockford_decode("zw", check: False) == Ok(<<255>>)
  assert thirtytwo.crockford_decode("cr", check: False) == Ok(<<"f":utf8>>)
}

pub fn crockford_normalize_aliases_test() {
  assert thirtytwo.crockford_decode("O0", check: False) == Ok(<<0>>)
  assert thirtytwo.crockford_decode("o0", check: False) == Ok(<<0>>)
  assert thirtytwo.crockford_decode("I0", check: False)
    == thirtytwo.crockford_decode("10", check: False)
  assert thirtytwo.crockford_decode("L0", check: False)
    == thirtytwo.crockford_decode("10", check: False)
  assert thirtytwo.crockford_decode("l0", check: False)
    == thirtytwo.crockford_decode("10", check: False)
}

pub fn crockford_hyphens_ignored_test() {
  assert thirtytwo.crockford_decode("C-R", check: False)
    == thirtytwo.crockford_decode("CR", check: False)
  assert thirtytwo.crockford_decode("CSQP-YRJC-5GGR", check: False)
    == thirtytwo.crockford_decode("CSQPYRJC5GGR", check: False)
}

pub fn crockford_decode_invalid_char_test() {
  assert thirtytwo.crockford_decode("U0", check: False) == Error(Nil)
}

pub fn crockford_check_encode_test() {
  assert thirtytwo.crockford_encode(<<>>, check: True) == ""
  assert thirtytwo.crockford_encode(<<0>>, check: True) == "000"
  assert thirtytwo.crockford_encode(<<255>>, check: True) == "ZW~"
}

pub fn crockford_check_decode_test() {
  assert thirtytwo.crockford_decode("000", check: True) == Ok(<<0>>)
  assert thirtytwo.crockford_decode("ZW~", check: True) == Ok(<<255>>)
}

pub fn crockford_check_wrong_digit_test() {
  assert thirtytwo.crockford_decode("001", check: True) == Error(Nil)
}

pub fn crockford_check_digit_only_test() {
  assert thirtytwo.crockford_decode("0", check: True) == Error(Nil)
}

pub fn crockford_roundtrip_test() {
  use input <- qcheck.given(qcheck.byte_aligned_bit_array())
  assert thirtytwo.crockford_decode(
      thirtytwo.crockford_encode(input, check: False),
      check: False,
    )
    == Ok(input)
}

pub fn crockford_check_roundtrip_test() {
  use input <- qcheck.given(qcheck.non_empty_byte_aligned_bit_array())
  assert thirtytwo.crockford_decode(
      thirtytwo.crockford_encode(input, check: True),
      check: True,
    )
    == Ok(input)
}

pub fn geohash_encode_test() {
  assert thirtytwo.geohash_encode(<<>>) == ""
  assert thirtytwo.geohash_encode(<<"fooba":utf8>>) == "dtrqysm1"
}

pub fn geohash_encode_cross_impl_test() {
  assert thirtytwo.geohash_encode(<<"Hello!":utf8, 0xDE, 0xAD, 0xBE, 0xEF>>)
    == "91kqsv3g47gbvgrg"
}

pub fn geohash_decode_cross_impl_test() {
  assert thirtytwo.geohash_decode("91kqsv3g47gbvgrg")
    == Ok(<<"Hello!":utf8, 0xDE, 0xAD, 0xBE, 0xEF>>)
}

pub fn geohash_decode_invalid_char_test() {
  assert thirtytwo.geohash_decode("a") == Error(Nil)
  assert thirtytwo.geohash_decode("i") == Error(Nil)
  assert thirtytwo.geohash_decode("l") == Error(Nil)
  assert thirtytwo.geohash_decode("o") == Error(Nil)
}

pub fn geohash_roundtrip_test() {
  use input <- qcheck.given(qcheck.byte_aligned_bit_array())
  assert thirtytwo.geohash_decode(thirtytwo.geohash_encode(input)) == Ok(input)
}

pub fn z_base_32_encode_test() {
  assert thirtytwo.z_base_32_encode(<<>>) == ""
  assert thirtytwo.z_base_32_encode(<<"fooba":utf8>>) == "c3zs6aub"
}

pub fn z_base_32_encode_cross_impl_test() {
  assert thirtytwo.z_base_32_encode(<<0xF0, 0xBF, 0xC7>>) == "6n9hq"
  assert thirtytwo.z_base_32_encode(<<0xD4, 0x7A, 0x04>>) == "4t7ye"
  assert thirtytwo.z_base_32_encode(<<0xFF>>) == "9h"
  assert thirtytwo.z_base_32_encode(<<"Hello!":utf8, 0xDE, 0xAD, 0xBE, 0xEF>>)
    == "jb1sa5dxr8xk5xzx"
}

pub fn z_base_32_decode_cross_impl_test() {
  assert thirtytwo.z_base_32_decode("6n9hq") == Ok(<<0xF0, 0xBF, 0xC7>>)
  assert thirtytwo.z_base_32_decode("4t7ye") == Ok(<<0xD4, 0x7A, 0x04>>)
  assert thirtytwo.z_base_32_decode("9h") == Ok(<<0xFF>>)
  assert thirtytwo.z_base_32_decode("jb1sa5dxr8xk5xzx")
    == Ok(<<"Hello!":utf8, 0xDE, 0xAD, 0xBE, 0xEF>>)
}

pub fn z_base_32_decode_invalid_char_test() {
  assert thirtytwo.z_base_32_decode("l") == Error(Nil)
  assert thirtytwo.z_base_32_decode("v") == Error(Nil)
  assert thirtytwo.z_base_32_decode("0") == Error(Nil)
  assert thirtytwo.z_base_32_decode("2") == Error(Nil)
}

pub fn z_base_32_roundtrip_test() {
  use input <- qcheck.given(qcheck.byte_aligned_bit_array())
  assert thirtytwo.z_base_32_decode(thirtytwo.z_base_32_encode(input))
    == Ok(input)
}
