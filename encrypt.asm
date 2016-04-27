.text
a51start
nop
loadkeystream $r1, 0
loadkeystream $r2, 1
loadkeystream $r3, 2
loadkeystream $r4, 3
lw $r5, 0($r0)
lw $r6 ,1($r0)
lw $r7 ,2($r0)
lw $r8 3($r0)
xor $r9, $r5, $r1
xor $r10, $r6, $r2
xor $r11, $r7, $r3
xor $r12, $r8, $r4
sw $r9, 5($r0)
sw $r10, 5($r0)
sw $r11, 5($r0)
sw $r12, 5($r0)
halt

.data
msg1: .word 0x0000AAAA
msg2: .word 0x0000BEEF
msg3: .word 0x0000FEED
msg4: .word 0x0000EEEE
