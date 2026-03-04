# thirtytwo

[![Package Version](https://img.shields.io/hexpm/v/thirtytwo)](https://hex.pm/packages/thirtytwo)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/thirtytwo/)

Base32 encoding and decoding for Gleam, supporting all major variants. Works on
both Erlang and JavaScript targets.

## Supported Variants

| Variant | Encode | Decode | Notes |
|---------|--------|--------|-------|
| RFC 4648 | `encode` | `decode` | Standard alphabet, optional padding, case-insensitive decode |
| base32hex | `hex_encode` | `hex_decode` | Preserves sort order, optional padding, case-insensitive decode |
| Crockford | `crockford_encode` | `crockford_decode` | Optional check digit, alias normalization (O→0, I/L→1), hyphens ignored |
| z-base-32 | `z_base_32_encode` | `z_base_32_decode` | Human-oriented, no padding, case-sensitive |
| Geohash | `geohash_encode` | `geohash_decode` | No padding, case-sensitive |

## Usage

```sh
gleam add thirtytwo
```

```gleam
import thirtytwo

// RFC 4648
thirtytwo.encode(<<"wibble":utf8>>, padding: True)
// -> "O5UWEYTMMU======"

thirtytwo.decode("O5UWEYTMMU======")
// -> Ok(<<"wibble":utf8>>)

// Crockford with check digit
thirtytwo.crockford_encode(<<255>>, check: True)
// -> "ZW~"

thirtytwo.crockford_decode("ZW~", check: True)
// -> Ok(<<255>>)

// Geohash
thirtytwo.geohash_encode(<<"wibble":utf8>>)
// -> "fxnq4smddn"
```

Further documentation can be found at <https://hexdocs.pm/thirtytwo>.
