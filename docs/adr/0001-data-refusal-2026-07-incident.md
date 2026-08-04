# The /data refusal of 2026-07 (incident record)

From 2026-07-21 to roughly 2026-08-01, every `/data` request made from a
GitHub-hosted runner failed. On 2026-08-03 the units-collection workflow
succeeded on a plain hosted runner using the `:latest` Comlink image, and the
scheduled capture continues to run its own Comlink container on hosted runners.
This record preserves what the diagnosis established.

## What we established

Every property of the request was verified correct against a working instance:
the items value (`UnitDefinitions` = 137438953472, still present in `/enums`),
the game data version, the device platform, and the request method —
`requestSegment`, though deprecated, returns the same 3687 units where it is
allowed to. The Comlink version was not implicated (4.2.0 through 4.4.1 behaved
alike), nor was containerisation (the official Linux binary run directly on a
runner failed identically), nor the guest account (the same derived account
succeeded on our hardware), nor memory, request size, or warm-up time.

A packet capture on a runner showed why the diagnosis was so slow: `/data`
contacts `swgoh-api.akamaized.net`, a different host from the
`swprod.capitalgames.com` that startup and `/metadata` use. After startup,
`/metadata` reaches EA not at all, which is why it succeeded everywhere and
appeared to prove the network was healthy.

From a runner that Akamai edge was reachable — TCP connected, TLS completed,
traceroute arrived — and the request was nonetheless refused inside the
encrypted session. The refusal was at the application layer and tied to where
the request came from, not to what it contained.

## Resolution

The latest Comlink release fixed it. Whatever the Akamai edge was rejecting was
on the Comlink client side, and hosted runners work again as of 2026-08-03. No
change on our side was needed beyond taking the updated image.

An earlier version of this record concluded that the only path was moving the
capture to a self-hosted Comlink on our own network, reached over Tailscale.
That was never implemented, and the successful hosted run makes it unnecessary.

## The durable lesson

Comlink reports an upstream refusal as "did not receive a response code back
from the server" and appends a guess that the items value may be invalid. Both
were misleading here: the connection succeeded and the items value was correct.
Any future diagnosis should treat that message as "the upstream call did not
return usable data" and nothing more specific.
