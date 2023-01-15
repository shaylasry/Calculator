section .data

section	.rodata			    ; we define (global) read-only variables in .rodata section
    format_d: db "%d", 10, 0	; format int
    format_s: db "%s", 10, 0	; format string
    format_c: dd "%c", 10, 0	; format char
    format_x: dd "%x", 10, 0	; format hexa
    calc: db "calc: ", 7, 0	; calc msg
    s_underflow: db "Error: Insufficient Number of Arguments on Stack", 0, 0 ; underflow msg
    s_overflow: db "Error: Operand Stack Overflow", 0, 0 ; overflow msg
    debug_input: db "Inserted number: ", 0, 0
    debug_pop: db "Printed number: ", 0, 0
    debug_dup: db "Duplicated number: ", 0, 0
    debug_digits_num: db "Number of digits calculated and pushed: ", 0, 0
    debug_stack_push: db "Number pushed into the stack: ", 0, 0

section .bss			    ; we define (global) uninitialized variables in .bss section
    buf: resb 80		    ; input buffer (no longer than 80 characters)
    op_stack: resb 1020		; operands stack (max 255 cells)
    hex_val: resb 4         ; value of char in hexa
    buf_index: resb 4       ; index for the user input buffer
    link: resb 4            ; pointer to the linked list
    stack_index: resb 4     ; index for the operands stack
    debug: resb 4           ; debug mode (off=0, on=1)
    stack_size: resb 4      ; operands stack size
    num1: resb 4            ; first addition operand
    num2: resb 4            ; second addition operand
    res: resb 4             ; addition result
    carry: resb 4           ; addition carry (if needed)
    ans: resb 328
    temp: resb 4
    temp1: resb 4
    temp2: resb 4
    to_stderr: resb 4
    op_count: resb 4

section .text
  align 16
  global main
  extern printf
  extern fprintf 
  extern fflush
  extern malloc 
  extern free 
  extern getchar 
  extern fgets 
  extern stdin
  extern stderr

  %macro char_to_hex 0
    cmp edx, 57			        ; if number
    jle %%Num_Hex
    sub edx, 55			        ; if char
	jmp %%End_cth
    %%Num_Hex:
	sub edx, 48
    %%End_cth:
  %endmacro 

  %macro dec_to_hex 0
    mov ecx, 0
    mov [num1], ecx
    mov [num2], ecx
	mov eax, ebx
	mov ebx, 16
	cdq
	div ebx
	cmp edx, 9
	jle %%Num_Hex1
	add edx, 55                 ; if letter
	jmp %%End_Convert_1
	%%Num_Hex1:
	add edx, 48                 ; if number
	%%End_Convert_1:
    mov [num2], edx
    cdq
    div ebx
    cmp edx, 9
	jle %%Num_Hex2
	add edx, 55                 ; if letter
	jmp %%End_Convert_2
	%%Num_Hex2:
	add edx, 48                 ; if number
	%%End_Convert_2:
    mov [num1], edx
  %endmacro

  %macro call_malloc 0
    pushad
    push 5			            ; size of each link
    call malloc                 ; return pointer in eax
    add esp, 4
    mov [link], eax
    popad
  %endmacro

  %macro free_list 1
    mov edi, %1
    %%free_single_link:
    cmp dword[edi+1], 0 
    je %%end_free 
    push edi
    mov edi, [edi+1]
    call free 
    add esp, 4
    jmp %%free_single_link
    %%end_free:
    push edi
    call free
    add esp, 4
  %endmacro

main:
    push ebp
    mov ebp, esp
    pushad

    mov dword[stack_index], 0
    mov dword[stack_size], 20
    mov dword[debug], 0
    mov esi, dword[ebp+12]      ; main's arguments
    mov ebx, dword[esi+4]       ; first argument in ebx
    cmp ebx, 0
    je Call_myCalc              ; if there are no arguments call myCalc
    mov edi, dword[ebx]
    mov ebx, edi
    cmp bx, "-d"                ; if debug mode is on
    je Debug_On
    jmp Change_OpStack          ; stack length was given
; check if there are two arguments
    Second_Arg:
    mov ebx, dword[esi+8]       ; second argument in ebx
    cmp ebx, 0
    je Call_myCalc
    jmp Debug_On
Change_OpStack:
    mov eax, 0
    movzx edx, bh
    cmp edx, 0
    je Second_Byte
    char_to_hex
    mov eax, edx
    mov ecx, 16
    mul ecx
    Second_Byte:
    movzx edx, bl
    char_to_hex
    add eax, edx
    mov edx, 4
    mul edx
    mov [stack_size], eax
    jmp Second_Arg
Debug_On:
    mov edx, 1
    mov [debug], edx
Call_myCalc:
    call myCalc
End_Main:
    popad			            ; Restore caller state (registers)
    mov esp, ebp
    pop ebp 	        	    ; Restore caller state
    ret  			            ; Back to caller

;***********************************************************************
myCalc:
Main_Loop:
    push calc
    call printf
    add esp, 4
    push 0 
    call fflush
    add esp, 4

    mov eax, dword[stdin]	    ; get input from user (via stdin)	
    mov ebx, 80
    push eax			        ; push fgets arguments 
    push ebx
    push buf
    call fgets
    add esp, 12

    cmp byte[buf], 'q'
    je End_Main_Loop
    cmp byte[buf], 'p'
    je PopAndPrint
    cmp byte[buf], 'd'
    je Dup
    cmp byte[buf], 'n'
    je NumOfHexDigits
    cmp byte[buf], '&'
    je And_code
    cmp byte[buf], '|'
    je Or_code
    cmp byte[buf], '+'
    je Add_Ops
; else it is a number (valid input)
    mov eax, [stack_index]
    cmp eax, [stack_size]
    jge Stack_Overflow

    call createLinkedList       ; list pointer in eax
    mov ecx, [link]
    mov edx, op_stack
    mov eax, [stack_index]
    add edx, eax 
    mov [edx], ecx
    mov ecx, [stack_index]      ; inc index
    add ecx, 4
    mov [stack_index], ecx

    mov eax, [debug]
    cmp eax, 1
    jne Main_Loop
    pushad
    push debug_input
    mov edi, dword[stderr]
    push edi
    call fprintf
    add esp, 8
    popad
    jmp Only_Print

    jmp Main_Loop
End_Main_Loop:
    pushad
    mov eax, [op_count]
    push eax
    push format_x
    call printf
    add esp, 8
    popad
    pushad                      ; new line
    mov eax, 10
    push eax
    push format_c
    call printf
    add esp, 8
    popad
Free_LinkedList:
    mov eax, [stack_index]      ; check if there's an operand to pop
    cmp eax, 0
    je End_myCalc
    sub eax, 4                  ; dec stack index
    mov [stack_index], eax
    mov ecx, op_stack
    add ecx, eax
    mov eax, [ecx]              ; eax = link to first operand
    free_list dword[ecx]
    jmp Free_LinkedList
End_myCalc:
    ret

;******************************POP**********************************
PopAndPrint:  
    inc dword[op_count]
    mov eax, 0
    mov [to_stderr], eax
    mov eax, [stack_index]      ; check if there's an operand to pop
    cmp eax, 0
    jle Stack_Underflow
    sub eax, 4                  ; dec stack index
    mov [stack_index], eax
    mov ecx, op_stack
    add ecx, eax
    mov eax, [ecx]              ; eax = link to first operand
    mov [temp], ecx
    mov edi, 0                  ; edi = num of digits
    jmp Push_Digits
   
Only_Print:
    mov eax, 1
    mov [to_stderr], eax
    mov eax, [stack_index]      ; check if there's an operand to pop
    sub eax, 4                  ; dec stack index
    mov ecx, op_stack
    add ecx, eax
    mov eax, [ecx] 
    mov edi, 0                  ; edi = num of digits
Push_Digits:
    mov [link], eax
    movzx ebx, byte[eax]        ; first num to convert
    dec_to_hex
    mov eax, [link]
    mov ebx, [num2]
    push ebx  
    inc edi
    mov ebx, [num1]
    push ebx
    inc edi
    mov edx, dword[eax+1]       ; edx = pointer to next link
    mov eax, edx
    cmp eax, 0
    jne Push_Digits

    mov ecx, edi
    mov edx, 0
Pop_Digits:
    cmp ecx, 0
    je Print_Loop
    mov esi, ans
    add esi, edx
    pop ebx
    mov [esi], ebx
    inc edx
    dec ecx
    jmp Pop_Digits
Print_Loop:
    cmp edx, 0
    je End_Print
    mov eax, ans
    add eax, ecx
    movzx esi, byte[eax]
    dec edx
    inc ecx
    cmp ecx, 1
    je RemoveZero
    mov edi, [to_stderr]
    cmp edi, 1
    je Print_To_Stderr
    pushad
    push esi
    push format_c
    call printf
    add esp, 8
    popad
    jmp Print_Loop
Print_To_Stderr:
    pushad
    push esi
    push format_c
    mov edi, dword[stderr]
    push edi
    call fprintf
    add esp, 12
    popad
    jmp Print_Loop

RemoveZero:
    cmp esi, 48
    je Print_Loop
    pushad
    mov edi, [to_stderr]
    cmp edi, 1
    je Print_To_Stderr2 
    push esi
    push format_c
    call printf
    add esp, 8
    popad
    jmp Print_Loop
Print_To_Stderr2:
    pushad
    push esi
    push format_c
    mov edi, dword[stderr]
    push edi
    call fprintf
    add esp, 12
    popad
    jmp Print_Loop   
NoZeros:
    mov edi, [to_stderr]
    cmp edi, 1
    je Print_To_Stderr3
    pushad
    push esi
    push format_c
    call printf
    add esp, 8
    popad
    jmp Print_Loop
Print_To_Stderr3:
    pushad
    push esi
    push format_c
    mov edi, dword[stderr]
    push edi
    call fprintf
    add esp, 12
    popad
    jmp Print_Loop    
End_Print:
    pushad                      ; new line
    mov eax, 10
    push eax
    push format_c
    call printf
    add esp, 8
    popad
    mov eax, [temp]
    free_list dword[eax]
    jmp Main_Loop

;******************************DUP**********************************
Dup:
    inc dword[op_count]
    mov eax, [stack_index]      ; check if there's an operand to pop
    cmp eax, 0
    jle Stack_Underflow
    sub eax, 4                  ; dec stack index
    mov ecx, op_stack
    add ecx, eax
    mov eax, [ecx]              ; eax = link to first operand

    mov edi, 0                  ; edi = num of digits
Push_Digits_Dup:
    movzx ebx, byte[eax]        ; first num to duplicate
    push ebx  
    inc edi
End_Push_Dup:
    mov edx, dword[eax+1]       ; edx = pointer to next link
    mov eax, edx
    cmp eax, 0
    jne Push_Digits_Dup
    mov ecx, edi
    mov edx, 0
Pop_Digits_ToAns:
    cmp ecx, 0
    je Dup_Num
    mov esi, ans
    add esi, edx
    pop ebx
    mov [esi], ebx
    inc edx
    dec ecx
    jmp Pop_Digits_ToAns
Dup_Num:
    cmp edx, 0
    je End_Dup
    mov eax, ans
    add eax, ecx
    movzx ebx, byte[eax]
    cmp ecx, 0
    je Dup_First_Link
    mov eax, [link]             ; prev link in temp
    mov [temp], eax
    call_malloc
    mov eax, [link]
    mov byte[eax], bl
    mov ebx, [temp]
    mov dword[eax+1], ebx
    jmp End_Dup_First
Dup_First_Link:
    call_malloc
    mov eax, [link]
    mov byte[eax], bl
    mov dword[eax+1], 0
End_Dup_First:
    dec edx
    inc ecx
    jmp Dup_Num
End_Dup:
    mov ecx, [link]
    mov edx, op_stack
    mov eax, [stack_index]
    add edx, eax 
    mov [edx], ecx
    mov ecx, [stack_index]      ; inc index
    add ecx, 4
    mov [stack_index], ecx
    mov eax, [debug]            ; debug print
    cmp eax, 1
    jne Main_Loop
    pushad
    push debug_dup
    mov edi, dword[stderr]
    push edi
    call fprintf
    add esp, 8
    popad
    jmp Only_Print

;******************************N**********************************
NumOfHexDigits:
    inc dword[op_count]
    mov eax, [stack_index]      ; check if there's an operand to pop
    cmp eax, 0
    jle Stack_Underflow
    sub eax, 4                  ; dec stack index
    mov [stack_index], eax
    mov ecx, op_stack
    add ecx, eax
    mov [temp], ecx
    mov eax, [ecx]              ; eax = link to first operand
    mov edi, 0                  ; edi = num of digits
Count_Digits:
    mov [link], eax
    mov ebx, dword[eax+1]
    cmp ebx, 0
    je CountFirstLinkDigits
    inc edi
    inc edi
    mov eax, ebx
    jmp Count_Digits
CountFirstLinkDigits:
    movzx ecx, byte[eax]
    cmp ecx, 16
    jge Add2Digits
    inc edi
    jmp End_Count
Add2Digits:
    inc edi
    inc edi
End_Count:
    mov [num1], edi
    mov eax, [temp]
    free_list dword[eax]
    mov edi, [num1]
    call_malloc
    mov eax, [link]
    mov ebx, edi
    mov byte[eax], bl
    mov dword[eax+1], 0
    mov ecx, [link]
    mov edx, op_stack
    mov eax, [stack_index]
    add edx, eax 
    mov [edx], ecx
    mov ecx, [stack_index]      ; inc index
    add ecx, 4
    mov [stack_index], ecx
    mov eax, [debug]            ; debug print
    cmp eax, 1
    jne Main_Loop

    pushad
    push debug_digits_num
    mov edi, dword[stderr]
    push edi
    call fprintf
    add esp, 8
    popad
    jmp Only_Print

;******************************ADD**********************************
Add_Ops:
    inc dword[op_count]
    mov eax, 0
    mov [carry], eax
    mov edi, 0                  ; edi = index in ans

    mov eax, [stack_index]
    cmp eax, 4
    jle Stack_Underflow
    sub eax, 4                  ; pop from operands stack
    mov [stack_index], eax
    mov ecx, op_stack
    add ecx, eax                ; first operand address
    mov [temp1], ecx
    mov eax, [ecx]              ; eax = first operand
    mov [num1], eax

    mov eax, [stack_index]
    sub eax, 4                  ; pop from operands stack
    mov [stack_index], eax
    mov ecx, op_stack
    add ecx, eax                ; second operand address
    mov [temp2], ecx
    mov eax, [ecx]              ; eax = second operand
    mov [num2], eax

    mov ecx, [num1]
    movzx edx, byte[eax]
    movzx ebx, byte[ecx]
    add edx, ebx                ; edx = num1+num2 (lsb)
    cmp edx, 256  
    jge Reminder
    mov esi, ans
    add esi, edi
    mov byte[esi], dl
    inc edi
    jmp Addition_Loop

Reminder:
    sub edx, 256                ; get the reminder
    mov esi, ans
    add esi, edi
    mov byte[esi], dl
    inc edi
    mov ecx, 1
    mov [carry], ecx

Addition_Loop:
    mov eax, [num1]
    mov ebx, dword[eax+1]   
    mov [num1], ebx
    mov eax, [num2]
    mov edx, dword[eax+1]   
    mov [num2], edx
    cmp ebx, 0                  ; check if we're at the last link in num1
    je Add_Num2
    cmp edx, 0                  ; check if we're at the last link in num2
    je Add_Num1
Add_Two_Nums:
    mov eax, [num1]
    movzx ebx, byte[eax]
    mov eax, [num2]
    movzx edx, byte[eax]
    add ebx, edx
    mov eax, [carry]
    add ebx, eax
    cmp ebx, 256
    jge Reminder3
    mov edx, 0
    mov [carry], edx
    jmp CreateLink3
Reminder3:
    sub ebx, 256
    mov esi, 1
    mov [carry], esi
CreateLink3:
    mov esi, ans
    add esi, edi
    mov byte[esi], bl
    inc edi
    jmp Addition_Loop

End_Add_Loop:
    mov ebx, [carry]
    cmp ebx, 0
    jne Add_Carry
CreateFirstLink:
    mov [temp], edi
    mov eax, [temp1]
    free_list dword[eax]
    mov eax, [temp2]
    free_list dword[eax]
    mov edi, [temp]
    sub edi, 1
    mov esi, ans
    add esi, edi
    movzx ecx, byte[esi]
    mov edx, [link]
    call_malloc
    mov eax, [link]
    mov byte[eax], cl
    mov dword[eax+1], 0
CreateLink:
    cmp edi, 0
    je End_LinkedList
    sub edi, 1
    mov esi, ans
    add esi, edi
    movzx ecx, byte[esi]
    mov edx, [link]
    call_malloc
    mov eax, [link]
    mov byte[eax], cl
    mov dword[eax+1], edx
    jmp CreateLink
    
End_LinkedList:
    mov edx, op_stack
    mov eax, [stack_index]
    add edx, eax 
    mov ecx, [link]
    mov [edx], ecx
    mov ecx, [stack_index]      ; inc stack index
    add ecx, 4
    mov [stack_index], ecx
    mov eax, [debug]            ; debug print
    cmp eax, 1
    jne Main_Loop
    pushad
    push debug_stack_push
    mov edi, dword[stderr]
    push edi
    call fprintf
    add esp, 8
    popad
    jmp Only_Print
Add_Carry:
    mov ebx, [carry]
    mov esi, ans
    add esi, edi
    mov byte[esi], bl
    inc edi
    mov ebx, 0
    mov [carry], ebx
    jmp End_Add_Loop
Add_Num1:                       ; only adding num 1
    mov eax, [num1]
    cmp edx, 0
    je End_Add_Loop
    movzx ebx, byte[eax]
    mov edx, [carry]
    add ebx, edx                ; ebx = num1 + carry
    cmp ebx, 256
    jge Reminder1
    mov edx, 0
    mov [carry], edx
    jmp CreateLink1
Reminder1:
    sub ebx, 256
    mov esi, 1
    mov [carry], esi
CreateLink1:
    mov esi, ans
    add esi, edi
    mov byte[esi], bl
    inc edi
    mov eax, [num1]
    mov edx, dword[eax+1]   
    mov [num1], edx
    jmp Add_Num1
Add_Num2:
    mov eax, [num2]
    cmp edx, 0
    je End_Add_Loop
    movzx ebx, byte[eax]
    mov edx, [carry]
    add ebx, edx                ; ebx = num2 + carry
    cmp ebx, 256
    jge Reminder2
    mov edx, 0
    mov [carry], edx
    jmp CreateLink2
Reminder2:
    sub ebx, 256
    mov esi, 1
    mov [carry], esi
CreateLink2:
    mov esi, ans
    add esi, edi
    mov byte[esi], bl
    inc edi
    mov eax, [num2]
    mov edx, dword[eax+1]   
    mov [num2], edx
    jmp Add_Num2

Stack_Underflow:
    pushad
    push s_underflow
    call printf
    add esp, 4
    popad
    pushad                      ; new line
    mov eax, 10
    push eax
    push format_c
    call printf
    add esp, 8
    popad
    jmp Main_Loop
Stack_Overflow:
    pushad
    push s_overflow
    call printf
    add esp, 4
    popad
    pushad                      ; new line
    mov eax, 10
    push eax
    push format_c
    call printf
    add esp, 8
    popad
    jmp Main_Loop

;******************************AND**********************************
And_code:
    inc dword[op_count]
    mov eax, [stack_index]
    cmp eax, 4
    jle Stack_Underflow
    sub eax, 4                  ; pop from operands stack
    mov [stack_index], eax
    mov ecx, op_stack
    add ecx, eax                ; first operand address
    mov [temp1], ecx
    mov eax, [ecx]              ; eax = first operand
    mov [num1], eax

    mov eax, [stack_index]
    sub eax, 4                  ; pop from operands stack
    mov [stack_index], eax
    mov ecx, op_stack
    add ecx, eax                ; second operand address
    mov [temp2], ecx
    mov eax, [ecx]              ; eax = second operand
    mov [num2], eax

    mov ecx, [num1]
    movzx edx, byte[eax]
    movzx ebx, byte[ecx]
    mov eax, edx

    and al, bl
; first link:
    mov esi, 0                  ; index in ans
    mov edi, ans
    mov byte[edi], al
    inc esi
And_Loop:
    mov eax, [num1]
    mov ebx, dword[eax+1]       ; ebx = pointer to next link of num1
    mov [num1], ebx
    mov eax, [num2]
    mov edx, dword[eax+1]       ; edx = pointer to next link of num2
    mov [num2], edx
    cmp ebx, 0
    je End_And_Loop
    cmp edx, 0
    je End_And_Loop
And2Nums:
    movzx eax, byte[ebx]
    movzx ecx, byte[edx]
    mov ebx, ecx
    and al, bl
    mov edi, ans
    add edi, esi
    mov byte[edi], al
    inc esi
    jmp And_Loop
End_And_Loop:
    sub esi, 1
    mov edi, ans
    add edi, esi
    mov [temp], edi
    mov eax, [temp1]
    free_list dword[eax]
    mov eax, [temp2]
    free_list dword[eax]
    mov edi, [temp]
    movzx ecx, byte[edi]
    call_malloc
    mov eax, [link]
    mov byte[eax], cl
    mov dword[eax+1], 0
AddLinks_Loop:
    cmp esi, 0
    je End_And_Code
    sub esi, 1
    mov edi, ans
    add edi, esi
    movzx ecx, byte[edi]
    mov edx, [link]
    call_malloc
    mov eax, [link]
    mov byte[eax], cl
    mov dword[eax+1], edx
    jmp AddLinks_Loop
End_And_Code:
    mov ecx, [link]
    mov edx, op_stack
    mov eax, [stack_index]
    add edx, eax 
    mov [edx], ecx
    mov ecx, [stack_index]      ; inc index
    add ecx, 4
    mov [stack_index], ecx

    mov eax, [debug]            ; debug print
    cmp eax, 1
    jne Main_Loop
    pushad
    push debug_stack_push
    mov edi, dword[stderr]
    push edi
    call fprintf
    add esp, 8
    popad
    jmp Only_Print

;******************************Or**********************************
Or_code:
    inc dword[op_count]
    mov eax, [stack_index]
    cmp eax, 4
    jle Stack_Underflow
    sub eax, 4                  ; pop from operands stack
    mov [stack_index], eax
    mov ecx, op_stack
    add ecx, eax                ; first operand address
    mov [temp1], ecx
    mov eax, [ecx]              ; eax = first operand
    mov [num1], eax

    mov eax, [stack_index]
    sub eax, 4                  ; pop from operands stack
    mov [stack_index], eax
    mov ecx, op_stack
    add ecx, eax                ; second operand address
    mov [temp2], ecx
    mov eax, [ecx]              ; eax = second operand
    mov [num2], eax

    mov ecx, [num1]
    movzx edx, byte[eax]
    movzx ebx, byte[ecx]
    mov eax, edx
    or al, bl
; first link:
    mov esi, 0                  ; index in ans
    mov edi, ans
    mov byte[edi], al
    inc esi
Or_Loop:
    mov eax, [num1]
    mov ebx, dword[eax+1]       ; ebx = pointer to next link of num1
    mov [num1], ebx
    mov eax, [num2]
    mov edx, dword[eax+1]       ; edx = pointer to next link of num2
    mov [num2], edx
    cmp ebx, 0
    je Or_Num2
    cmp edx, 0
    je Or_Num1
Or2Nums:
    movzx eax, byte[ebx]
    movzx ecx, byte[edx]
    mov ebx, ecx
    or al, bl
    mov edi, ans
    add edi, esi
    mov byte[edi], al
    inc esi
    jmp Or_Loop
End_Or_Loop:
    sub esi, 1
    mov edi, ans
    add edi, esi
    mov [temp], edi
    mov eax, [temp1]
    free_list dword[eax]
    mov eax, [temp2]
    free_list dword[eax]
    mov edi, [temp]
    movzx ecx, byte[edi]
    call_malloc
    mov eax, [link]
    mov byte[eax], cl
    mov dword[eax+1], 0
AddLinks_Loop1:
    cmp esi, 0
    je End_Or_Code
    sub esi, 1
    mov edi, ans
    add edi, esi
    movzx ecx, byte[edi]
    mov edx, [link]
    call_malloc
    mov eax, [link]
    mov byte[eax], cl
    mov dword[eax+1], edx
    jmp AddLinks_Loop1
Or_Num1:
    mov ebx, [num1]
    cmp ebx, 0
    je End_Or_Loop
    mov edi, ans
    add edi, esi
    movzx ecx, byte[ebx]
    mov [edi], ecx
    inc esi
    mov eax, [num1]
    mov ebx, dword[eax+1]       ; ebx = pointer to next link of num1
    mov [num1], ebx
    jmp Or_Num1
Or_Num2:
    mov edx, [num2]
    cmp edx, 0
    je End_Or_Loop
    mov edi, ans
    add edi, esi
    movzx ecx, byte[edx]
    mov [edi], ecx
    inc esi
    mov eax, [num2]
    mov edx, dword[eax+1]       ; edx = pointer to next link of num2
    mov [num2], edx
    jmp Or_Num2

End_Or_Code:
    mov ecx, [link]
    mov edx, op_stack
    mov eax, [stack_index]
    add edx, eax 
    mov [edx], ecx
    mov ecx, [stack_index]      ; inc index
    add ecx, 4
    mov [stack_index], ecx

    mov eax, [debug]            ; debug print
    cmp eax, 1
    jne Main_Loop
    pushad
    push debug_stack_push
    mov edi, dword[stderr]
    push edi
    call fprintf
    add esp, 8
    popad
    jmp Only_Print

;******************************************************************
createLinkedList:
; check if input number is 0:
    movzx ecx, byte[buf]
    cmp ecx, 48
    jne NotZero
    movzx ecx, byte[buf+1]
    cmp ecx, 10
    jne NotZero
    push 5			            ; size of each link
    call malloc                 ; return pointer in eax
    add esp, 4
    mov [link], eax
    mov ecx, 0
    mov byte[eax], cl
    mov dword[eax+1], 0
    jmp End_AddLinks
; else:
NotZero:
    mov ebx, 0
    mov [buf_index], ebx
Begin_FindZeros:
    mov edx, [buf_index]
    movzx ecx, byte[buf+edx]
    cmp ecx, 48
    jne End_FindZeros
    inc ebx
    mov [buf_index], ebx
    jmp Begin_FindZeros
End_FindZeros:
    mov eax, [buf_index]	    ; eax = index
Get_Buf_Len:
    movzx ecx, byte[buf+eax]	; go over the buffer
    cmp ecx, 10			        ; \n character
    je EvenOrOdd
    cmp ecx, 0			        ; null character
    je EvenOrOdd
    inc eax
    jmp Get_Buf_Len
EvenOrOdd:
    sub eax, [buf_index]
    mov ebx, 2
    cdq
    div ebx
    cmp edx, 1
    mov ecx, [buf_index]
    je Odd
Even:                           ; index in ecx (put index before calling this label)
    mov eax, 0                  
    movzx edx, byte[buf+ecx]    ; first byte
    char_to_hex
    mov eax, edx
    mov ebx, 16
    mul ebx
    inc ecx
    movzx edx, byte[buf+ecx]    ; second byte
    char_to_hex
    add eax, edx
    mov [hex_val], eax
    inc ecx
    mov [buf_index], ecx
    jmp End_firstLink
Odd: 
    movzx edx, byte[buf+ecx]    ; first byte
    char_to_hex
    mov [hex_val], edx
    inc ecx
    mov [buf_index], ecx
End_firstLink:
    push 5			            ; size of each link
    call malloc                 ; return pointer in eax
    add esp, 4
    mov [link], eax
    movzx ecx, byte[hex_val]
    mov byte[eax], cl
    mov dword[eax+1], 0

Begin_AddLinks:
    mov ecx, [buf_index]
    mov eax, 0                
    movzx edx, byte[buf+ecx]    ; first byte
    cmp edx, 10                 ; \n
    je End_AddLinks
    cmp edx, 0                  ; null
    je End_AddLinks
    char_to_hex
    mov eax, edx
    mov ebx, 16
    mul ebx
    inc ecx
    movzx edx, byte[buf+ecx]    ; second byte
    char_to_hex
    add eax, edx
    mov [hex_val], eax
    inc ecx
    mov [buf_index], ecx

; malloc the new link:    
    push 5			            ; size of each link
    call malloc                 ; return pointer in eax
    add esp, 4
    movzx ecx, byte[hex_val]
    mov byte[eax], cl
    mov ebx, [link]
    mov dword[eax+1], ebx
    mov [link], eax

    jmp Begin_AddLinks

End_AddLinks:
    mov eax, [link]
    ret