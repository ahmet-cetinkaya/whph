# Golden encodings (T10)

Byte-exact reference encodings asserted by `test/model/golden_test.dart`. They pin the
canonical formats that are hashed (BLAKE2b-256), signed (Ed25519) or authenticated as
AEAD associated data, so any change here is a protocol change: bump the domain string
(`.../v1` → `.../v2`) and the protocol version instead of editing a file in place.

Regenerate only for an intentional format change:
`WHPH_UPDATE_GOLDEN=1 fvm dart test test/model/golden_test.dart`.

| File | Content |
| --- | --- |
| `change_without_cause.bin` | canonical change: `Task/task-1/title = "Buy milk"`, seq 42 |
| `change_with_cause.bin` | canonical change: cascaded `TaskTag/task-tag-1/~` tombstone, cause `(Task, task-1)`, seq 43 |
| `change_hashes.txt` | hex BLAKE2b-256 of the two changes |
| `manifest_signing_input.bin` | manifest signing input over both hashes, range `(41, 43]` |
| `envelope_ad_with_cause.bin` | envelope AEAD associated data of the change with a cause, epoch `(1, member-a)`, protocol 2 |

Fixture values: group `00112233445566778899aabbccddeeff`, origin
`0102030405060708090a0b0c0d0e0f10`, node `member-a`, HLC `pack(1790000000000, 7)` (+1 for
the second change). See `test/model/model_fixtures.dart`.

## Format (v1)

Integers are big-endian and fixed width. `str` = `u32 length ‖ UTF-8` (strict; a leading
BOM is kept; unpaired surrogates are rejected). `16B` fields are raw 128-bit ids. No
interned/local integer ever appears (wire rule, plan D1): tables and columns are names,
the node is the member id string, the origin is the 128-bit id.

Canonical change:

```text
str "whph-sync/change/v1" ‖ 16B group_id ‖ str tbl ‖ str pk ‖ str col
‖ value ‖ i64 hlc ‖ str node ‖ 16B origin ‖ i64 origin_seq ‖ cause
value = u8 tag ‖ u32 len ‖ payload   tag 0 null (len 0), 1 int (8-byte signed),
                                     2 string (UTF-8), 3 bytes; other tags are
                                     preserved verbatim (FR-042)
cause = u8 0                         absent
      | u8 1 ‖ str cause_tbl ‖ str cause_pk
```

Manifest signing input:

```text
str "whph-sync/manifest/v1" ‖ 16B group_id ‖ 16B origin ‖ i64 from_seq ‖ i64 to_seq
‖ u32 n ‖ n × 32B hash
```

Envelope associated data:

```text
str "whph-sync/envelope-ad/v1" ‖ 16B group_id ‖ i64 epoch_counter ‖ str epoch_creator
‖ str tbl ‖ str pk ‖ str col ‖ i64 hlc ‖ 16B origin ‖ i64 origin_seq ‖ cause
‖ u32 protocol_version
```

`protocol_version` is the version the envelope was sealed under. Since the T11 security
fixes it is also carried in the envelope wire form (`u32` after the epoch creator), and
`EnvelopeCipher.open` binds that carried value, so envelopes relayed or held across a
protocol upgrade still open. The AD bytes above are unchanged.
