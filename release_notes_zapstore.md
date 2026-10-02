## 1.0.0

First release.

- Post a bounty with an amount and a time limit. It travels to nearby phones over Bluetooth LE and is relayed onward by the phones in between.
- Claim, accept, mark done and mark paid, with every claim encrypted end to end between the two people involved.
- Witnessed completion: phones in radio range co-sign that a job was finished. Signatures are only created for completions heard over the radio, never for relayed ones.
- Works with no internet. Nostr relays are used as a fallback when internet is available, and the radio is always tried first.
- Runs in the background on both platforms, with notifications for new nearby bounties and for activity on your own.
- No server, no account, no analytics. The identity is generated on the device and never leaves it.
