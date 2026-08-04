# SWGOH Comlink Data Capture

This repository runs a Comlink instance on a schedule and archives snapshots of
Star Wars: Galaxy of Heroes game data into `data/`. It is a capture pipeline: it
records what the game publishes, and does not interpret it.

## Language

### Game data

**Comlink**:
A self-hosted service that brokers read access to the game's data. It is not the
source of the data — it authenticates to EA on our behalf using anonymous guest
accounts derived from its public IP and app name.
_Avoid_: the API, the server, swgoh-comlink

**Game data version**:
The identifier naming the currently published snapshot of game data. Every data
request must state the version it wants, and only the newest one is served.
_Avoid_: version string, gamedata version, MD_VERSION

**Collection**:
A named group of game data records — `units`, `ability`, `equipment` and so on. A
data response always carries every collection key; the ones that were not asked
for come back empty or null.
_Avoid_: table, dataset, segment (a segment is a union of collections)

**Units collection**:
The `units` collection: the definitions of every playable and non-playable
character and ship. The single collection this repository currently captures.
_Avoid_: units data, unit list, characters

**Items selector**:
The value on a data request naming which collections to populate. Expressible
either as a bitmask or as a GameDataItems name; both select the same collections.
_Avoid_: items bitmask, request segment, items parameter

**GameDataItems**:
The enumeration mapping each selectable collection to its bit. `UnitDefinitions`
selects the units collection. Names beginning `Segment` denote predefined unions
of collections rather than single ones.
_Avoid_: item enums, data items

### Capture health

**Fetch**:
One attempt to obtain a set of collections at a given game data version and write
them to `data/`. A fetch either produces usable game data or it does not; a
well-formed response carrying no records is not a fetch.
_Avoid_: download, request, pull

**Upstream no-response**:
A fetch outcome meaning Comlink did not get usable data back from the game
servers, as happened throughout the 2026-07 `/data` refusal incident (see
`docs/adr/0001-data-refusal-2026-07-incident.md`). Comlink words this as having
received no response code, but the underlying call may well have connected and
been refused, so the term asserts only that the upstream exchange yielded
nothing usable.
_Avoid_: outage, timeout, upstream error
