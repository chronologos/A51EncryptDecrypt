.text
addi $r2, $r0, 1
addi $r1, $r0, 5
jal loop

exit:
or $r3, $r2, $r5
and $r4, $r3, $r2
mul $r5, $r4, $r3
halt

loop:
sub $r1, $r1, $r2
bne $r1, $r0, loop
jr $ra

.data
