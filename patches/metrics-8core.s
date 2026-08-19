#
# metric-8core.s  (BIOS 5 port, SMU firmware 0.58.7.1)
# fix 8-core metrics (tweak layout to leave sufficient space, loops are already good mostly)
#
# ported from the BIOS 3 (0.58.6.0) patch: same target immediates / table layout,
# addresses relocated to the 0.58.7.1 metrics code, and the per-core loop store
# group re-encoded for the register allocation the 0.58.7.1 build uses there
# (a11/a12, a10/a8, a5/a8, a14/a13, a11/a13 instead of a12/a13, a11/a10, a8/a10,
#  a15/a14, a13/a14). Original instructions at every site verified byte-identical
# to the BIOS 3 originals against the dumped 0.58.7.1 firmware.
#

# per-core loop store offsets (6-wide -> 8-wide)
.section .p_29f75, "ax"
	s32i.n a11, a12, 0x10
.section .p_29f77, "ax"
	s16i a10, a8, 0x30
.section .p_29f7a, "ax"
	s16i a5, a8, 0x48


# current table tail + l3 offsets
.section .p_29eb6, "ax"
s16i a9, a2, 0x5c
.section .p_29eb9, "ax"
s16i a15, a2, 0x60
.section .p_29ebc, "ax"
s16i a14, a2, 0x58
.section .p_29ebf, "ax"
s16i a8, a2, 0x5e
.section .p_29edb, "ax"
s16i a12, a2, 0x62
.section .p_29f0d, "ax"
s32i a10, a15, 0x64
.section .p_29f10, "ax"
s32i a8, a15, 0x6c
.section .p_29f13, "ax"
s32i a14, a15, 0x74
.section .p_29f33, "ax"
s32i a8, a2, 0x7c
.section .p_29fe3, "ax"
s16i a14, a2, 0x80
.section .p_29fe6, "ax"
s16i a15, a2, 0x5a
.section .p_29fe9, "ax"
s16i a13, a2, 0x82
.section .p_29fad, "ax"
	s16i a14, a13, 0x40
.section .p_29fb0, "ax"
	s16i a11, a13, 0x44


# export dma length
.section .p_29ff6, "ax"
movi a12, 0x11c


# average table store offsets
.section .p_29bc6, "ax"
s16i a10, a4, 0xe0
.section .p_29be4, "ax"
s16i a10, a4, 0xe4
.section .p_29c02, "ax"
s16i a10, a4, 0xe6
.section .p_29c13, "ax"
s16i a11, a4, 0xe8
.section .p_29c30, "ax"
s16i a10, a4, 0xea
.section .p_29c65, "ax"
s32i a8, a2, 0xec
.section .p_29c82, "ax"
s32i a11, a2, 0xf4
.section .p_29c8e, "ax"
s32i a10, a2, 0xfc
.section .p_29ca8, "ax"
l32i a10, a4, 0x104
.section .p_29cc2, "ax"
s32i a10, a13, 0x204
.section .p_29d0a, "ax"
s16i a10, a2, 0x88
.section .p_29d25, "ax"
s32i a10, a6, 0x98
.section .p_29d48, "ax"
s16i a11, a2, 0xb8
.section .p_29d54, "ax"
s16i a10, a2, 0xd0
.section .p_29dad, "ax"
s16i a8, a3, 0xc8
.section .p_29db9, "ax"
s16i a10, a3, 0xcc
.section .p_29df1, "ax"
s16i a10, a4, 0xe2
.section .p_29e0f, "ax"
s16i a10, a4, 0x108
.section .p_29e21, "ax"
s16i a10, a4, 0x10a


# average table ema read offsets
.section .p_29bab, "ax"
l16ui a10, a4, 0xe0
.section .p_29bcc, "ax"
l16ui a10, a4, 0xe4
.section .p_29bea, "ax"
l16ui a10, a4, 0xe6
.section .p_29c05, "ax"
l16ui a10, a4, 0xe8
.section .p_29c25, "ax"
l16ui a10, a4, 0xea
.section .p_29c48, "ax"
l32i a10, a2, 0xec
.section .p_29c62, "ax"
l32i a10, a2, 0xf4
.section .p_29c7f, "ax"
l32i a10, a2, 0xfc
.section .p_29cea, "ax"
l16ui a10, a2, 0x88
.section .p_29d10, "ax"
l32i a10, a6, 0x98
.section .p_29d28, "ax"
l16ui a10, a2, 0xb8
.section .p_29d45, "ax"
l16ui a10, a2, 0xd0
.section .p_29d93, "ax"
l16ui a10, a3, 0xc8
.section .p_29daa, "ax"
l16ui a10, a3, 0xcc
.section .p_29dd6, "ax"
l16ui a10, a4, 0xe2
.section .p_29df7, "ax"
l16ui a10, a4, 0x108
.section .p_29e15, "ax"
l16ui a10, a4, 0x10a
