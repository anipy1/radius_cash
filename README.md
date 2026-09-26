# radius.cash

Radius is for small physical jobs at festivals, film sets and conferences.
Places where people actually need help with something right now.

Say you are setting up a booth and you need two people for ten minutes. You
post it with an amount on it. Phones nearby see it over Bluetooth, someone
claims it, you pay them.

No server and no accounts. Venue wifi is usually saturated and the halls have
no signal, so it does not rely on either.

The phones that were in the room can co-sign that it got done, so a finished
job is witnessed rather than just claimed.

Built at the Lock in & Build hackathon, Tallinn, 26 to 27 September 2026.

## How it works

Every phone makes itself an identity on first launch, a seed in the Keychain
or Keystore that derives a signing key, an X25519 key for Noise sessions and
a Nostr key. People know each other by a short label derived from it.

A bounty is one signed record. It is flooded over Bluetooth LE, relayed by
phones in between, and republished on a slow cadence so the board converges.
Anyone can forward it. Only the key that signed the first record for that id
can revise it.

Claims are private. They travel inside a Noise XX session between the
claimant and the poster.

When there is internet, Nostr relays carry the same frames as a fallback, so
two phones that met on the mesh can still reach each other from across town.
The radio is always tried first.

## Witnessed completion

When a claimant marks a job done, phones physically in radio range co-sign
that they heard it.

A witness signature is only ever produced for something heard over the radio,
never for something that arrived through a relay. Relay traffic can come from
anywhere on earth. Radio traffic cannot.

So a finished job carries signatures from devices that were actually there,
which is a record no server can produce at any price.

## Prior work

The BLE transport, Noise session layer and Nostr bridge come from my own
earlier mesh experiments, which were in turn inspired by
[bitchat](https://github.com/permissionlesstech/bitchat). Everything built on
top of that during the hackathon is new.

Architecture follows [claude-flutter-kit](https://github.com/anipy1/claude-flutter-kit).

## Running

```
fvm flutter pub get
fvm flutter run
```

Two physical phones are required. A BLE mesh with one node is just a phone.
