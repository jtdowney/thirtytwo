# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-03-03

### Added

- RFC 4648 standard base32 encoding and decoding (`encode`/`decode`) with optional padding and case-insensitive decoding
- Extended Hex base32 encoding and decoding (`hex_encode`/`hex_decode`) preserving sort order (RFC 4648 §7)
- Crockford base32 encoding and decoding (`crockford_encode`/`crockford_decode`) with hyphen stripping, character aliases (O→0, I/L→1), and optional mod-37 check digit
- z-base-32 encoding and decoding (`z_base_32_encode`/`z_base_32_decode`) with human-oriented lowercase alphabet
- Geohash base32 encoding and decoding (`geohash_encode`/`geohash_decode`)
- Support for both Erlang and JavaScript targets

[1.0.0]: https://github.com/jtdowney/thirtytwo/releases/tag/v1.0.0
