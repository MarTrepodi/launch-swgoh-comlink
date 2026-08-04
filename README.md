# SWGOH Comlink Data Capture

A self-contained capture pipeline for [Star Wars: Galaxy of Heroes](https://www.ea.com/games/starwars/galaxy-of-heroes) game data, built entirely on GitHub Actions. On a schedule, it launches a [swgoh-comlink](https://github.com/swgoh-utils/swgoh-comlink) container on a hosted runner, fetches the game data collections you select, and commits each response into [`data/`](data/) as a dated JSON snapshot. It records what the game publishes and does not interpret it.

No servers, no secrets, no external infrastructure — a repository created from this template starts capturing on its own.

## How it works

Each capture run:

1. Starts a Comlink container on the runner and polls it until it accepts requests. Comlink brokers read access to the game's data, authenticating to EA with an anonymous guest account — no player credentials are involved.
2. Asks `/metadata` for the current game data version. Every data request must name the version it wants; only the newest is served.
3. POSTs to `/data` once per requested items selector, validating each response (a well-formed body carrying no game data is a failure, not a capture) and retrying with exponential backoff.
4. Commits the responses back to the repository.

Two maintenance workflows keep the pipeline healthy without attention: old snapshots are pruned on a retention schedule, and repeated workflow failures raise a single GitHub issue that closes itself on recovery.

## Workflows

| Workflow | Trigger | What it does |
| --- | --- | --- |
| [Scheduled fetch of multiple /data items](.github/workflows/scheduled_fetch_data_items.yml) | Daily 09:17 UTC, or manual | Fetches every items selector listed in [`scripts/items_default.txt`](scripts/items_default.txt) and commits one `data_response_*.json` per selector. Manual runs can point at a different items file. |
| [Units collection capture](.github/workflows/launch_comlink_and_get_game_data.yml) | Manual | One-off fetch of the `units` collection (item `137438953472`), committed as `units_response_*.json`. Useful as a smoke test. |
| [Guild snapshot](.github/workflows/launch_comlink_and_get_guild.yml) | Manual | Captures one guild's profile and recent activity from `/guild` as `guild_response_*.json`. Requires a guild ID (see setup). |
| [Cleanup old data files](.github/workflows/cleanup_old_data.yml) | Daily 11:47 UTC, or manual | Deletes files in `data/` whose filename date is older than 30 days (a manual run can override the window) and commits the deletions. |
| [Monitor workflow failures](.github/workflows/monitor_workflow_failures.yml) | Completion of any workflow above | After two consecutive failures of the same workflow, opens one issue labelled `workflow-failure`. Continued failures edit that issue rather than raising new ones, and the next success closes it. |

## Data files

Every snapshot embeds its capture date in the filename, and that date is what the cleanup workflow trusts — filesystem timestamps are meaningless after a checkout.

```
data/data_response_<YYYY-MM-DD>_<items>_<id>.json    scheduled /data captures
data/units_response_<YYYY-MM-DD>_<items>_<id>.json   manual units captures
data/guild_response_<YYYY-MM-DD>_<id>.json           guild snapshots
```

`<items>` is the items selector the response answers for, and `<id>` is a random 8-character run identifier so reruns on the same day never collide.

## Scripts

- [`scripts/fetch_data_items.sh`](scripts/fetch_data_items.sh) — the shared fetch loop. Reads an items file (one selector per line, `#` comments allowed), POSTs each to `/data`, classifies every response (`ok`, `upstream_no_response`, `http_error`, `empty_collections`, `invalid_json`), retries failures with exponential backoff, and only ever keeps validated responses. Tunable via `MAX_ATTEMPTS`, `RETRY_BASE_DELAY`, `COMLINK_URL`, `OUT_DIR`, and `FILE_PREFIX`.
- [`scripts/cleanup_old_data.sh`](scripts/cleanup_old_data.sh) — the retention pass. Deletes `data/*.json` whose embedded `_YYYY-MM-DD_` date is older than `MAX_AGE_DAYS` (default 30). Files without a parseable date are listed and never touched.

Both run locally, so behaviour changes can be tested without a workflow run.

## Using this template

1. **Create your repository** — click **Use this template → Create a new repository**.
2. **Enable the workflows** — open the **Actions** tab of the new repository and enable workflows if prompted. No other settings are required: every workflow declares the permissions it needs and runs on the built-in `GITHUB_TOKEN`.
3. **Choose your collections** — edit [`scripts/items_default.txt`](scripts/items_default.txt), one items selector per line. A selector is a `GameDataItems` bitmask; query a running Comlink's `/enums` endpoint for the full `GameDataItems` enumeration, including the `Segment*` values that select whole groups of collections at once. The default captures the `units` collection.
4. **(Optional) Set up the guild snapshot** — replace `<PLACE GUILD ID HERE>` in [`launch_comlink_and_get_guild.yml`](.github/workflows/launch_comlink_and_get_guild.yml) with your guild's ID. Skip this if you don't need guild data; the workflow is manual-only and inert until you run it.
5. **(Optional) Tune the defaults** — the cron expressions in the scheduled workflows, the 30-day retention default in [`cleanup_old_data.yml`](.github/workflows/cleanup_old_data.yml), and the container's `APP_NAME` (part of how Comlink derives its guest account) are all plain values in the workflow files.
6. **Smoke-test it** — run the **units collection capture** workflow from the Actions tab. A green run that commits a `units_response_*.json` file means the pipeline works end to end; the daily schedule takes it from there.

> **Note:** GitHub suspends scheduled workflows in repositories with no activity for 60 days. The daily capture commits count as activity, so a working pipeline keeps itself alive — but if every schedule fails or is disabled long enough, you will need to re-enable the workflows from the Actions tab.

## When something breaks

A red run means something in this repository needs fixing; the failure monitor turns repeats into a single `workflow-failure` issue so an outage is one notification, not a daily one. The fetch script's failure causes are precise: only `upstream_no_response` points at the game's servers rather than this pipeline, and its wording should be trusted no further than "the upstream call returned nothing usable" — the reasons are recorded in [`docs/adr/0001`](docs/adr/0001-data-refusal-2026-07-incident.md), the incident record of a month-long refusal that produced most of this repository's hardening.

[`CONTEXT.md`](CONTEXT.md) defines the project's vocabulary — worth reading before changing capture behaviour, and kept current when the language shifts.

## License

[MIT](LICENSE)
