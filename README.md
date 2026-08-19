# BC-250 SMU Unlock — BIOS 5 Port + SMU Firmware Analysis

This repo ports [rw-r-r-0644's SMU unlock](https://github.com/rw-r-r-0644/bc250-smu-unlock)
to **BIOS 5 (SMU firmware 0.58.7.1)** and adds a static analysis of what actually
changed inside the SMU between BIOS 3 and BIOS 5.

Two independent things live here:

1. **The unlock** — exploit a queue-2 message handler bug to gain arbitrary SMN
   read/write and code execution on the SMU, then rewrite the CPU core-enable mask.
2. **The analysis** — a content-diff of the two SMU firmware images that separates
   "recompiled and moved" from "genuinely changed", plus notes on the tracing method
   we use to disassemble and diff the SMU images.

---

## Part 1 — The unlock (BIOS 5 port)

Exploit queue 2 msg `0x23` to unlock the SMU's secure-access functions, which then
allow fully arbitrary SMU read/write and code execution. This is the same class of
bug rw-r-r-0644 found on BIOS 3; only Cyan Skillfish is affected — every other AMD
platform (coreboot targets, the PS5) keeps a bound check that this firmware is
missing.

### Changes from the BIOS 3 version

**unlock.py**
- `DBG_DISABLE`:   `0x7B3C` → `0x7B44`  (+8)
- `NEW_ENTRY_ADDR`: `0x7B38` → `0x7B40`  (+8)
- `RING_BASE`, `TR_TABLE_PTR`: **unchanged**

All logic uses the offsets dynamically — no hardcoded magic numbers.

**metrics-8core patches** — ported, all 54 sites relocated to the 0.58.7.1 metrics code:
- 49 sites: identical instructions (same regs, same stock 6-core immediates) at new
  addresses (+0x348 for the average-table code; +0x340/+0x344/+0x345/+0x349 for the
  tail / L3 / per-core / DMA groups). Patch bytes unchanged.
- 5 per-core loop-store sites: the 0.58.7.1 build allocates different registers
  (`a11/a12`, `a10/a8`, `a5/a8`, `a14/a13`, `a11/a13`), so the patch bytes were
  re-encoded (`b94c`, `a25818`, `525824`, `e25d20`, `b25d22`).
- DMA export length: `movi a12, 0xF4 → 0x11C`, now at `0x29FF6`.

### Usage

```bash
sudo python3 unlock.py            # gain SMN read/write + code exec
sudo python3 patcher.py           # fix 8-core metrics layout (optional)
sudo python3 set_core_mask.py 0xFF   # write core mask via SMN
sudo reboot                       # apply
```

### Core mask reference

The core-enable register is **SMN `0x0115A870`**. It is an 8-bit mask, one bit per
core. The board reads it back through PCI cfg index `0xB8` / data `0xBC` on `00:00.0`.

| mask   | cores | notes                          |
|--------|-------|--------------------------------|
| `0x77` | 6     | factory (cores 3 and 7 fused off) |
| `0xFF` | 8     | full unlock                    |
| `0x7F` | 7     | drops core 7                   |
| `0xF7` | 7     | drops core 3                   |

Read it live:
```bash
sudo setpci -s 00:00.0 b8.l=0115a870 ; sudo setpci -s 00:00.0 bc.l
```

**Note on 7 cores.** The BIOS "Downcore control" CBS option only offers 1/2/3/4/6 —
it cannot select 7, and there is no 7-core value in its enum. The GRA (Generic
Register Access) BIOS option *cannot* write `0x0115A870` from the x86 side either —
tested, the host has read-but-not-write access to that aperture; only the SMU can
write it. So the sole path to an arbitrary mask (7 cores, or a specific core set) is
this unlock: gain SMU code exec, then write the mask via SMN from inside the SMU.

---

## Part 2 — SMU firmware: BIOS 3 vs BIOS 5

Both SMU blobs were extracted from the PSP directory (type 0x08 / "SMU off-chip
firmware"), header-trimmed (0x100 bytes), 0x40200 bytes each.

| | version | identical to |
|---|---|---|
| BIOS 1 / BIOS 3 | **0.58.6.0** | each other (byte-for-byte) |
| BIOS 5          | **0.58.7.1** | — |

ASRock left the SMU untouched from v1 through v3 and only revised it in v5.

### The 53% byte-diff is mostly relocation, not change

A naive `cmp` reports 53% of bytes different — which is misleading. A content-diff
(index every 12-byte window of one image, find it in the other, extend the match)
shows most of that is **the same code moved to a new address by recompilation**:

```
75.3%  copied verbatim from the other image
  17.0%   at the same offset
  58.3%   relocated (identical bytes, shifted address)
24.7%  no correspondence  (genuine change OR relocation fix-up)
```

The relocation follows a **staircase**: the two images are byte-identical up to
`0x07084`, then v5 inserts code in blocks (8, then 24, 196, 208, 132, 120 bytes…),
and everything after each insertion shifts by the running total. That is the exact
signature of "recompiled with a few new functions stitched in", not a rewrite.

Of the 24.7% with no match, most is small: ~9 KB is 1–8 byte gaps where a relocated
block's internal address literal (an `l32r` target) moved, breaking the match without
changing behaviour. **Genuinely new code is ~5 KB in 7 blocks.**

### What actually changed

- **Block `0x1b52b` (largest, ~1.5 KB, 836 divergent lines — confirmed real).**
  A parameter-table initializer: a long run of `s32i`/`s8i` writing constants
  (`0x2c2`=706, `0x4e2`=1250, `0x474`=1140, `0x514`=1300 …) into two structs in SMU
  **internal SRAM** (`0x7c30`, `0x7d5c`), *not* into hardware registers. v5 seeds
  these power-management tables differently from v3.

- **The per-domain clock-gating function is IDENTICAL between v3 and v5.**
  This corrects an earlier mistaken claim. The function (v3 `@0x31434`, v5 `@0x31774`)
  walks a 35-entry table of SMU-local registers (`0x010xx200`, control field at
  `+0x30`), and for each domain writes `0x7ff` or `0` behind a `memw` barrier,
  gated by a bit in a config mask. When the full function is dumped in both builds
  (up to its `retw.n`), it is byte-for-byte the same logic: **37 bit tests, 35
  stores, same order** in both. The "v5 added domains 0x64/0x7c" reading was a
  measurement artifact (a dump window 32 bytes longer on the v5 side).

- The remaining new blocks are small FP-math helpers (`mul.s`, `divn.sf`) and a new
  4-byte-stride data table — telemetry / power-calc, not dispatch, not core-mask.

**Bottom line:** v5 is a power-management point revision. It re-seeds some internal
PM parameter tables and adds telemetry math. It does **not** touch the message
dispatcher or the core-enable path, which is consistent with the unlock porting over
with only +8 byte offset shifts.

### The 35 clock-gating domains

The 35 registers are `0x01000000 + page*0x1000 + 0x200`, control at `+0x30`, pages:
```
00 03 04 05 06 07 08 0c 0e 0f 10 12 1c 22 23 24 25 28 29 2d 2e 2f
31 32 33 46 50 64 6c 7c 80 96 97 aa ab
```
They live in the SMU's **local aperture** — the x86 side reads `0xffffffff` for all of
them (the core-mask register `0x0115A870` is reachable; these are not). Naming each
page to a physical IP block (GFX / VCN / UMC / DF / the various deep-sleep clocks)
needs AMD's internal instance-ID map, which isn't in the firmware, the board CAD
(that's VRM rails), or the amdgpu driver (which has the vocabulary —
`AMD_CG_SUPPORT_{GFX,VCN,JPEG,HDP,ATHUB,MMHUB,BIF,DF,SDMA,MC}` — but not this
numbering). The closest chip-specific name list is the BIOS **SMU Features** page
(qids `0x7040`–`0x7063`: `CCLK_CONTROLLER … DS_GFXCLK DS_SOCCLK DS_LCLK …
DS_SMNCLK DS_MP0CLK …`), which confirms the *family* but not the per-address mapping.

**Hardware verification (governor stopped, read via PCI cfg space):**
```
Core mask:         0x0115a870 = 0x000000ff  (8 cores visible)

Gating registers (control field at +0x30, sample):
  0x0100e230 = 0xffffffff  (ungated)
  0x0102e230 = 0xffffffff  (ungated)
  0x0100c230 = 0xffffffff  (ungated)
  0x01064230 = 0xffffffff  (ungated)
  0x0107c230 = 0xffffffff  (ungated)
  0x01023230 = 0xffffffff  (ungated)
  0x01000230 = 0xffffffff  (ungated)
```

**Confirmed:** all 35 gating registers read as `0xffffffff` via PCI cfg space (index
0xB8, data 0xBC), while the core-mask register reads correctly. This proves the gating
registers live in the SMU's **local aperture**, unreachable from x86. They can only be
read/written from inside the SMU (post-unlock) or via SMU mailbox commands.

**What the v5 changes likely are (strong evidence, not confirmed):**

Cross-referencing the mask bits with kernel `smu10.h` (same SMU family, Raven):
```
bit 0x13 (19) = DCEFCLK_DPM
bit 0x14 (20) = GFX_DPM
bit 0x15 (21) = DS_GFXCLK      (last one in v3)
bit 0x16 (22) = DS_SOCCLK      (new in v5)
bit 0x17 (23) = DS_LCLK        (new in v5)
```

The match is sequential and aligns with names visible in the BIOS "SMU Debug" menu
(DS_GFXCLK, DS_SOCCLK, DS_LCLK). **Interpretation:** v5 extended deep-sleep clock
gating from GFXCLK-only to also cover SOCCLK (SoC/fabric clock) and LCLK (link clock).
More aggressive power savings in idle.

---

## Files

```
unlock.py            queue-2 0x23 exploit → SMN r/w + code exec (BIOS 5 offsets)
patcher.py           apply the 8-core metrics fixups to the running SMU
set_core_mask.py     write 0x0115A870 via SMN after unlock
patches.hex          BIOS 5 port of the metrics patch (54 sites)
analysis/smu_v3_v5_diff/
  DumpRanges.java    Ghidra headless disassembly-range dumper
  movemap.py         content-diff / relocation move-map
  v3_full.asm        gating function, BIOS 3 (0.58.6.0)
  v5_full.asm        gating function, BIOS 5 (0.58.7.1)
  blk3.txt blk5.txt  block 0x1b52b, normalized, both builds
```

## Credits

- **rw-r-r-0644** — original queue-2 SMU unlock (BIOS 3) and the runtime code-exec bug.
- BIOS 5 port, v3/v5 firmware diff, and clock-gating analysis: this repo.
