# lila-tablebase on this machine

Phase 1t of `docs/PLAN-ZAGONETKE-IZ-PARTIJE.md`: the backend answers positions
with five men or fewer from our own Syzygy tables (the 3-4-5 set) through
[lila-tablebase](https://github.com/lichess-org/lila-tablebase), Lichess's own
tablebase server, which serves the same API as `tablebase.lichess.ovh`. Six and
seven men still go to Lichess. `services/tablebaseService.js` decides; the
backend finds the server at `LOCAL_TABLEBASE_URL` (`.env.example`).

Not part of the app: the clone lives beside the project, in
`D:\Projekti\lila-tablebase`, and is started from `D:\Projekti\pokreni.ps1`
(item 5), which runs it on `127.0.0.1:9000` over `D:\syzygy\3-4-5` — only the
3-4-5 set, although the 6-man set is on the disk too, so this machine and the
droplet judge a game alike.

## Building on Windows

Upstream builds on Linux only. Three optional parts do not build with MSVC:
jemalloc (the allocator), and the C probers for antichess DTW and Prophet DTM,
which need libclang — none of them is asked for by us. `windows-build.patch`
makes those three and the Unix socket listener `cfg(not(windows))`, with stubs
that answer "no DTM, no antichess" on Windows. Standard Syzygy WDL and DTZ —
everything the review reads — are untouched; the Linux build is upstream's.

```powershell
git clone https://github.com/lichess-org/lila-tablebase.git D:\Projekti\lila-tablebase
```

```powershell
git -C D:\Projekti\lila-tablebase am D:\Projekti\chess_master\tools\lila-tablebase\windows-build.patch
```

```powershell
cargo build --release --manifest-path D:\Projekti\lila-tablebase\Cargo.toml
```

Needs Rust (rustup, the MSVC toolchain) and the Visual Studio Build Tools.
Measured 25.9.2026 at upstream `5eaf827`: builds in about a minute and a half,
runs in about 17 MB without `--mmap`, and on the 71 positions of five men or
fewer from phase 0's walks it answers exactly as Lichess does in category and
in every move's category. The order among equally good moves and a few DTZ
values rounded one apart differ, because Lichess also sorts by DTM, which
Prophet gives it and this build does not have.

## On the droplet

`deploy/tablebase-setup.sh` does the same on Linux, where upstream builds
without the patch: it fetches the 3-4-5 set from `tablebase.sesse.net`, checks
every file against `3-4-5.sha256` (written from the owner's set, so both
machines hold the very same tables), builds upstream at the same commit, and
runs it as the systemd unit `lila-tablebase` on `127.0.0.1:9000`. Run on
25.9.2026: 290 of 290 files verified, an 11-minute build, about 52 MB running.
