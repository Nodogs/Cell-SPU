ila 0 0             // store 0 in reg0
ila 1 4             // shift=4;
ilh 10 -1           // used to create mask FFFFFFFF
ilh 30 4			// use to shift by 12byte
ilh 31 8			// use to shift by 8 byte
ilh 32 12 			// use to shift by 8 bytes
shlqby 10 10 32 	// generate FFFFFFFF ins first word
ila 11 4 			// i = 4// START OUTER LOOP
ai 11 11 -1         // i--
ila 12 4 			// j = 4 START INNER LOOP
ila 42 0            // load_index=0
ila 43 16           // rotate=16
ila 20 0            // clearing reg 20
ai 12 12 -1 		// j--;
ila 15 0            // clearing reg 15
lqd 5 4(42)         // load row(2)= 4+0,+41,4+2,4+3
and 15 5 10         // extract the first word of the quadword
rotqby 15 15 43	    // rotate the word to align in the slot
xor 20 15 20 		// reg 15 will have elemnt for column 0 matrix2
shlqby 5 5 1 		// shift row by 4
ai 43 43 -4         // rotate-=4
stqd 5 4(42)        // store the shifted reg back to memory
ai 42 42 1          // load_index+=1
brnz 12 -10         // if reg11==0 break else goto ai 12 12 -1
stqd 20 10(11)      // store 20 in 13 to 10
brnz 11 -17         // if reg11==0 break else goto ai 11 11 -1
ila 51 4 			// i = 4// START OUTER LOOP
ai 51 51 -1         // i--
ila 80 0            // reset the quad word
lqd 21 0(51) 		// load maxtrix 1 rows
ila 12 4 			// j = 4 START INNER LOOP
ila 43 16           // rotate=16s
ai 12 12 -1 		// j--;
lqd 22 10(12) 		// load transposed matrix2 rows
mpya 23 22 21 23    // multiply slot wise both rows and store qword in 23
ila 81 0            // reset the cell
ila 45 4            // k=0
ai 45 45 -1         // k--
and 70 23 10        // using mask to extract the left most word
shlqby 23 23 30     // shift left by 4 bytes
a 81 81 70          // computing sum of the product cell wise
brnz 45 -4          // jump to ai 45 45 -1
and 81 81 10        // clearing any other bits
rotqby 81 81 43     // rotate reg81 to place word in correct slot of quad
ai 43 43 -4         // rotate-=4
or 80 80 81         // build the quadword using or with rotated word
brnz 12 -14         // jump to ai 12 12 -1
stqd 80 20(51)      // store the quad word row for the matrix3
brnz 51 -21         //Jump to ai 51 51 -1
stop