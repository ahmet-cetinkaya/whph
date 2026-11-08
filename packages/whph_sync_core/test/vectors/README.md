# Noise test vectors (S4 spike, T5)

Vendored subsets of two public Noise test-vector files, used by
`test/spike/noise_vectors_test.dart`. Only the `Noise_XX*_25519_ChaChaPoly_BLAKE2b`
entries (plain `XX` and `XX` with `pskN` modifiers) are kept; all other
entries are dropped. Entry contents are unchanged.

| File | Source (pinned) | Original file sha256 | Entries kept | License |
| --- | --- | --- | --- | --- |
| `cacophony_xx.json` | https://raw.githubusercontent.com/haskell-cryptography/cacophony/8ee9d41e34a1a596cfa3ab12aa4069ff87dc1247/vectors/cacophony.txt | `3bde7c09a6f349ee11c825c50fcc02649f8f02a47c857a459206b357f9386cae` | `Noise_XX_25519_ChaChaPoly_BLAKE2b`, `Noise_XXpsk3_25519_ChaChaPoly_BLAKE2b` | Public domain (Unlicense), `LICENSE` at the same commit |
| `snow_xx.json` | https://raw.githubusercontent.com/mcginty/snow/8ac60f51cfe3e010c84f0a454cc575ad9204fa12/tests/vectors/snow.txt | `69da433305fd045f6c9f01b656662a389d022688986fd39fbe7af009cd402fd3` | `Noise_XX_25519_ChaChaPoly_BLAKE2b`, `Noise_XXpsk0+psk1_…`, `Noise_XXpsk0+psk2_…`, `Noise_XXpsk0+psk3_…`, `Noise_XXpsk0+psk1+psk2+psk3_…` (all `_25519_ChaChaPoly_BLAKE2b`) | Apache-2.0 OR MIT (`Cargo.toml` `license`, `LICENSE-APACHE` / `LICENSE-MIT` at the same commit) |

Both licenses are GPL-3.0-compatible (public domain; MIT is GPL-compatible,
Apache-2.0 is GPL-3.0-compatible).

Vector format (cacophony/snow): `protocol_name`, `init_prologue`, `init_psks`,
`init_static`, `init_ephemeral`, `resp_*` counterparts, optional
`handshake_hash` (cacophony only) and `messages[{payload, ciphertext}]`.
Messages alternate initiator → responder starting with the initiator; the first
three are handshake messages, the rest are transport messages after `Split()`.
The snow file has no `XXpsk3` entry, so `XXpsk3` coverage comes from cacophony
(no cross-test tool was needed).

## Extraction

Each file was downloaded from the pinned URL, its sha256 checked against the
table, and filtered with:

```python
import json, re, sys
pat = re.compile(r'^Noise_XX(psk[0-3](\+psk[0-3])*)?_25519_ChaChaPoly_BLAKE2b$')
src, dst = sys.argv[1], sys.argv[2]
vs = [v for v in json.load(open(src))['vectors'] if pat.match(v['protocol_name'])]
json.dump({'vectors': vs}, open(dst, 'w'), indent=2)
open(dst, 'a').write('\n')
```

`python3 extract.py cacophony.txt cacophony_xx.json` and
`python3 extract.py snow.txt snow_xx.json`.

The keys, PSKs and payloads in these files are public test data, not secrets.
