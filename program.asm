.586
.model flat, stdcall
option	casemap	:none
.stack 4096

STD_OUTPUT_HANDLE EQU -11

GetStdHandle PROTO,
	nStdHandle:DWORD

WriteConsoleA PROTO,
	handle:DWORD,
	lpBuffer:PTR BYTE,
	nNumberOfBytesToWrite:DWORD,
	lpNumberOfBytesWritten:PTR DWORD,
	lpReserved:DWORD
	
ExitProcess PROTO,dwExitCode:DWORD

.data
;array   DW  1,1,3,0,3,3,4,4,-1
;array   DW	9,15,68,24,22,98,8,10,-1
;array   DW	1,2,3,1,3,9,3,0,3,4,3,8,9,9,-1
;array	 DW	549,15,437,153,141,86,437,30,416,108,48,46,60,51,48,136,-1
;array   DW	70,4,30,34,75,91,41,41,97,3,42,13,30,29,20,21,99,57,-1
array   DW  1,1,3,0,3,3,4,4,-1
msg1    DB  "number of data pairs: ", 0
msg2    DB  "sorted data pairs:", 0
msg3    DB  10, 13, "half ranges:", 0
msg4    DB  10,13, "min range: ", 0
msg5    DB  "LMedS: ", 0

space		DB	" ", 0
comma		DB	", ", 0
semicolon	DB	";", 0
newline		DB  13, 10, 0
equals		DB	" = "
minus		DB	" - "

n			DD  0

consoleHandle	DD 0
bytesWritten	DD 0
buffer			DB 100 DUP(0)

.code

;-------------------------------------------------------------------------------
; Function: main()
; Main function
;-------------------------------------------------------------------------------
main PROC
	push ebp            ; create stack frame
	mov ebp, esp

	INVOKE GetStdHandle, STD_OUTPUT_HANDLE	; get console handle for printing output
	mov [consoleHandle], eax				; save handle in variable

    push OFFSET array   ; calculate the array length
    call arrayLength

    mov [n], eax        ; save array length in variable

	push OFFSET msg1	; print first message with number of pairs
	call printString
    add esp, 4
	push DWORD PTR [n]	; print number of pairs
	call printInteger
	add esp,4
	INVOKE WriteConsoleA, consoleHandle, OFFSET newline, 2, offset bytesWritten, 0	; print newline

    push DWORD PTR [n]      ; sort the array
    push OFFSET array
    call sort
    add esp, 8 

    push OFFSET msg2    ; print second message for the sorted array
	call printString
    add esp, 4

    push OFFSET array   ; print sorted array
    call printArray
    add esp, 4

    push DWORD PTR [n]  ; print half ranges
    push OFFSET array   
    call getMinRange
    add esp, 8

    push eax            ; calculate LMedS using the mid range index
    push DWORD PTR [n]
    push OFFSET array   
    call getLMedS
    add  esp, 8

    push eax            
    push OFFSET msg5    ; print fifth message for the LMeds result
    call printString
    add esp, 4
	call printInteger	; print LMedS value
	add esp, 4

	INVOKE WriteConsoleA, consoleHandle, OFFSET newline, 2, offset bytesWritten, 0	; print newline

	INVOKE ExitProcess, 0

	pop ebp                 ; remove stack frame
	ret
main ENDP

;-------------------------------------------------------------------------------
; Function: stringLength(string)
; Calculate the string length
;-------------------------------------------------------------------------------
stringLength  PROC
    push ebp                ; create stack frame
    mov  ebp, esp
	push esi
    mov esi, [ebp + 8]      ; load the string address from the stack
    mov eax, 0              ; initialize counter to zero
strL0: 
	mov cl, [esi + eax]     ; load current char
    cmp cl, 0               ; if we reached 0, end the count
    je strdone
    inc eax                 ; else, increment char count
    jmp strL0
strdone:
	pop esi
    pop ebp                 ; restore stack frame
    ret
stringLength  ENDP

;-------------------------------------------------------------------------------
; Function: printString(string)
; Print a string on the console
;-------------------------------------------------------------------------------
printString PROC
    push ebp                ; create stack frame
    mov  ebp, esp

	mov eax, [ebp + 8]      ; load the string address from the stack
	
	push eax				; get string length
	call stringLength
	add esp, 4

	INVOKE WriteConsoleA, consoleHandle, [ebp + 8], eax, offset bytesWritten, 0

    pop ebp                 ; restore stack frame
	ret
printString ENDP

;-------------------------------------------------------------------------------
; Function: printInteger(integer)
; Print an integer on the console
;-------------------------------------------------------------------------------
printInteger PROC
    push ebp                ; create stack frame
    mov  ebp, esp
	push edi

	mov edi, OFFSET buffer	; point to end of buffer with edi
	add edi, 99
	mov BYTE PTR [edi], 0	; save end of string in buffer
	mov eax, [ebp + 8]      ; load number to print from the stack
	mov ecx, 10				; for dividing over 10
prl0:
	mov edx, 0				 
	div ecx					; divide number by 10
	add dl, '0'				; convert digit to ascii
	dec edi
	mov [edi], dl			; save digit in buffer
    cmp eax, 0				; repeat while the number is not zero
	jne prl0
	
	push edi				; print the number saved in the buffer
	call printString
	add esp, 4

	pop edi
	pop ebp                 ; restore stack frame
	ret
printInteger ENDP

;-------------------------------------------------------------------------------
; Function: arrayLength(array)
; Calculate the array length
;-------------------------------------------------------------------------------
arrayLength  PROC
    push ebp                ; create stack frame
    mov  ebp, esp
	push esi

    mov esi, [ebp + 8]      ; load the array address from the stack
    mov eax, 0              ; initialize counter to zero
L0: mov cx, WORD PTR [esi + eax*2]       ; load current word
    cmp cx, -1              ; if we reached -1, end the count
    je ldone
    inc eax                 ; else, increment word count
    jmp L0
ldone:
    shr eax, 1              ; divide word count by 2 to get array size

	pop esi
    pop ebp                 ; restore stack frame
    ret
arrayLength  ENDP


;-------------------------------------------------------------------------------
; Function: sort(array, n)
; Sort the array using bubble sort
;-------------------------------------------------------------------------------
sort PROC
    push ebp                                ; create stack frame
    mov  ebp, esp
    push ebx                                ; save registers
    push esi
    
    mov ecx, [ebp + 12]                     ; start counter i to number of elements - 1
    dec ecx
L1:
    mov esi, [ebp + 8]                      ; load pointer to start of array in esi
    mov edx, 0                              ; load inner counter to zero
L2:
    mov ax, WORD PTR [esi + edx*4]          ; load word from the array
    cmp ax, WORD PTR [esi + edx*4 + 4]      ; compare with next word on the array
    je L3                                   ; if they are equal, compare second values
    jg L4                                   ; else, if they are in order, skip

    mov bx, WORD PTR [esi + edx*4 + 4]      ; swap keys
    mov WORD PTR [esi + edx*4 + 4], ax
    mov WORD PTR [esi + edx*4], bx
    mov ax, WORD PTR [esi + edx*4 + 2]      ; load word from the array
    jmp swapVals
L3:    
    mov ax, WORD PTR [esi + edx*4 + 2]      ; load word from the array
    cmp ax, WORD PTR [esi + edx*4 + 6]      ; compare with next word on the array
    jge L4                                  ; if they are ordered, don't swap
swapVals:
    mov bx, WORD PTR [esi + edx*4 + 6]      ; else, swap values
    mov WORD PTR [esi + edx*4 + 6], ax
    mov WORD PTR [esi + edx*4 + 2], bx
L4:
    inc edx                                 ; increment counter
    cmp edx, ecx                            ; compare with n - i -1
    jl  L2                                  ; repeat if it's below

    loop L1                                 ; repeat for all elements

    pop esi                                 ; restore registers
    pop ebx
    pop ebp                                 ; restore stack frame
    ret
sort ENDP

;-------------------------------------------------------------------------------
; Function: printArray(array)
; Prints the array as data pairs
;-------------------------------------------------------------------------------
printArray  PROC
    push ebp                ; create stack frame
    mov  ebp, esp
	push esi                ; save registers
    push ebx

    mov esi, [ebp + 8]      ; load the array address from the stack
    mov ebx, 0              ; start at position 0
pl0: 
    movzx eax, WORD PTR [esi + ebx*4]       ; load current key
    cmp ax, -1              ; if we reached -1, end 
    je pdone

	INVOKE WriteConsoleA, consoleHandle, OFFSET space, 1, offset bytesWritten, 0	; print space

    movzx eax, WORD PTR [esi + ebx*4]       ; load current key
	push eax			; print key              
    call printInteger
    add esp, 4

	INVOKE WriteConsoleA, consoleHandle, OFFSET comma, 2, offset bytesWritten, 0	; print comma

	movzx eax, WORD PTR [esi + ebx*4 + 2]   ; load current value
	push eax			; print value
    call printInteger
    add esp, 4

	INVOKE WriteConsoleA, consoleHandle, OFFSET semicolon, 1, offset bytesWritten, 0	; print semicolon

    inc ebx                 ; advance to next pair
    jmp pl0
pdone:
    shr eax, 1              ; divide word count by 2 to get array size

    pop ebx                 ; restore registers
	pop esi
    pop ebp                 ; restore stack frame
    ret
printArray  ENDP

;-------------------------------------------------------------------------------
; Function: getMinRange(array)
; Gets the minimum half range in the sorted array, prints all the half ranges
; found in the array
;-------------------------------------------------------------------------------
getMinRange PROC
    push ebp                ; create stack frame
    mov  ebp, esp
	push esi                ; save registers
	push edi
    push ebx

    push OFFSET msg3		; print third message for the half ranges
    call printString
    add esp, 4

    mov esi, [ebp + 8]      ; load the array address from the stack
    mov ecx, 0              ; start index in 0
    mov ebx, [ebp + 12]     ; load number of elements in ebx
    shr ebx, 1              ; divide number by 2 to get half index
    
    mov edx, 65535          ; set minimum range as a big number
    mov edi, esi            ; set start of range as the initial one
rngLoop:
    movzx eax, WORD PTR [esi + ecx*4]           ; load word from the array
    push ecx
    add  ecx, ebx                               ; calculate index + half
    sub  ax,  WORD PTR [esi + ecx*4]            ; subtract word at half + i to get range

    cmp eax, edx            ; compare current range with the minimum
    jge printRng            ; if it's not smaller, don't update minimum

    mov edx, eax            ; else, set range as minimum
    mov edi, ecx            ; save index for the range
printRng:
    push edx                ; save edx value (min range)
    push eax                

	INVOKE WriteConsoleA, consoleHandle, OFFSET space, 1, offset bytesWritten, 0	; print space

    call printInteger		; print range
    add esp, 4

	INVOKE WriteConsoleA, consoleHandle, OFFSET semicolon, 1, offset bytesWritten, 0	; print semicolon

    pop edx                 ; restore edx value (min range)
    pop ecx                 ; restore current index
    inc ecx                 ; advance to next element in array
	mov eax, ecx
	add eax, ebx
    cmp eax, [ebp + 12]     ; see if index+half > number of elements
    jl  rngLoop             ; if not, repeat

    mov ecx, edi                        ; get index of min range
    movzx eax, WORD PTR [esi + ecx*4]   ; load word from the array
    push eax
    sub ecx, ebx                        ; get position of start of range
    mov  edi, ecx                       ; save it in edi
    movzx eax, WORD PTR [esi + ecx*4]   ; load word from the array
    push eax
    push edx                ; minimum half range

    push OFFSET msg4        ; print fourth message for the minimum half range
    call printString
    add esp, 4

	call printInteger		; print minimum half range
	add esp, 4

	INVOKE WriteConsoleA, consoleHandle, OFFSET equals, 3, offset bytesWritten, 0	; print equal sign

	call printInteger		; print range start
	add esp, 4

	INVOKE WriteConsoleA, consoleHandle, OFFSET minus, 3, offset bytesWritten, 0	; print minus sign

	call printInteger		; print range end
	add esp, 4

	INVOKE WriteConsoleA, consoleHandle, OFFSET newline, 2, offset bytesWritten, 0	; print newline

    mov eax, edi            ; return minimum half range index

    pop ebx                 ; restore registers
    pop edi
	pop esi
    pop ebp                 ; restore stack frame
    ret
getMinRange ENDP

;-------------------------------------------------------------------------------
; Function: getLMedS(array, n, minrngi)
; Calculates the LMeds for the array using the minimun range index
;-------------------------------------------------------------------------------
getLMedS    PROC
    push ebp                ; create stack frame
    mov  ebp, esp
	push esi                ; save registers

    mov esi, [ebp + 8]      ; load the array address from the stack
    mov edx, [ebp + 12]     ; load number of elements in edx
    shr edx, 1              ; divide number by 2 to get half index
    mov ecx, [ebp + 16]     ; load minimum range index into ecx

    movzx eax, WORD PTR [esi + ecx*4]           ; load word at min range index from the array
    add  ecx, edx                               ; calculate min index + half
    add  ax,  WORD PTR [esi + ecx*4]            ; add word at half + m
    shr  eax, 1                                 ; divide over 2 using a shift right

    pop esi                 ; restore registers
    pop ebp                 ; restore stack frame
    ret
getLMedS    ENDP

END main