.586
.model flat, stdcall
option casemap :none

.stack 4096
	; Other definitions
		ExitProcess proto,dwExitCode:dword
		GetStdHandle proto :dword
		ReadConsoleA  proto :dword, :dword, :dword, :dword, :dword
		WriteConsoleA proto :dword, :dword, :dword, :dword, :dword
		STD_INPUT_HANDLE equ -10
		STD_OUTPUT_HANDLE equ -11

	; My Procedure definitions
		copyStr proto :dword, :dword, :dword
		writeString proto :dword, :dword, :dword
		readString proto
		CtoF proto :dword
		FtoC proto :dword
		inttoStr proto :dword
		strtoInt proto
		strEqual proto :dword, :dword, :dword

.data
	; Variables for console reading
	bufSize = 80
	inputHandle DWORD ?
	readBuffer db bufSize dup(?)
	bytes_read dword ?

	; Variables for console writing
	openmsg db "All commands entered in lower case.", 13, 10, "Enter exit to close the program.", 13, 10
	prompt db "Enter C/F (C to convert to celsius, and F to convert to farenheit): "
	newline db 13, 10
	number_prompt db "Enter value to convert: "
	errorMsg db "Invalid command!"
	writeBuffer db bufSize dup(?)
	exitmsg db "Goodbye"
	outputHandle DWORD ?
	bytes_written dd ?

	; Conversion storage
	cStr db 10 dup (0)
	bytes_converted dd ?

	; Variables for some string based decision making
	CtoFStr db "f"
	FtoCStr db "c"
	CloseStr db "exit"

.code
; --------------------------------------------------------------------------------------------------
	main proc
		; Obtain input & output handles
		invoke GetStdHandle, STD_INPUT_HANDLE
		mov inputHandle, eax

		invoke GetStdHandle, STD_OUTPUT_HANDLE
		mov outputHandle, eax
		invoke writeString, offset openmsg, lengthof openmsg, 0
		
		start:
			; Get the number to convert
				invoke writeString, offset number_prompt, lengthof number_prompt, 0
				invoke readString
				invoke copyStr, offset readBuffer, offset cStr, bytes_read
				call strtoInt
				; Move number to ebx for use later
				mov ebx, eax

			invoke writeString, offset prompt, lengthof prompt, 0
			invoke readString
			; Check if buffer matches the exit command
				invoke strEqual, offset CloseStr, offset readBuffer, lengthof CloseStr
				cmp eax, 0
				jz stop
			; Check if buffer matches the CtoF command
				invoke strEqual, offset CtoFStr, offset readBuffer, lengthof CtoFStr
				cmp eax, 0
				jz converttoF
			; Check if buffer matches the FtoC command
				invoke strEqual, offset FtoCStr, offset readBuffer, lengthof FtoCStr
				cmp eax, 0
				jz converttoC
			invoke writeString, offset errorMsg, lengthof errorMsg, 1
			jmp start
		
		converttoC:
			invoke FtoC, ebx
			jmp printresult
		
		converttoF:
			invoke CtoF, ebx
		
		printresult:
			invoke inttoStr, eax
			mov eax, offset cStr
			add eax, lengthof cStr
			sub eax, bytes_converted
			invoke writeString, eax, bytes_converted, 1
			jmp start
		stop:
			call close
	main endp
; --------------------------------------------------------------------------------------------------
	strEqual proc uses ecx esi edi, string1:dword, string2:dword, comparelength:dword
		; Determine if the strings at the given offsets are equal, if they are equal EAX will be set to 0. Any other number means false.
		; Should be called as follwed: invoke strEqual, offset STRING1, offset STRING2, COMPARELENGTH
		mov esi, string1
		mov edi, string2
		mov ecx, comparelength
		add ecx, 1
		repe cmpsb
		; Move the result into eax
		mov eax, ecx
		ret
	strEqual endp
; --------------------------------------------------------------------------------------------------
	FtoC proc uses ebx ecx edx, farenheit:dword
		; Converts the given farenheit temperature into celsius, answer is put in eax
		mov eax, farenheit
		; Subtract 32
		sub eax, 32
		; Multiply by 5
		mov ebx, 5
		imul ebx
		; Divide by 9
		mov ebx, 9
		idiv ebx
		ret
	FtoC endp
; --------------------------------------------------------------------------------------------------
	CtoF proc uses ebx ecx edx, celsius:dword
		; Converts the given number from celsius to farenheight, stores result in eax
		mov eax, celsius
		process:
			; Multiply by 9
			mov ebx, 9
			imul ebx
			; Divide by 5
			mov ebx, 5
			idiv ebx
			; Add 32
			add eax, 32
		ret
	CtoF endp
; --------------------------------------------------------------------------------------------------
	copyStr proc uses eax esi edi ecx source:dword, dest:dword, len:dword
		; Copies a string from source to dest
		; Specify memory parameters
		mov ecx, len
		mov esi, source
		mov edi, dest
		; clear direction register, so string is copied forwards.
		cld
		; Copy the string
		rep movsb
		ret
	copyStr endp
; --------------------------------------------------------------------------------------------------
	inttoStr proc uses eax ebx ecx edx, number:dword
		; Converts the passed int into a string and puts the result in cStr
		mov eax,number
		mov ecx,10
		mov	ebx, lengthof cStr - 1
		mov edx, 0
		mov bytes_converted, 0
		; Check if number is above 1, skip the negation if it is
			cmp eax, 0
			jge start
			neg eax
		; Set edx to 1 and push it onto the stack for adding a negative sign later
			mov edx, 1
		start:
			push edx
		nextNum:
			div cl
			add	ah,30h
			mov byte ptr cStr+[ebx],ah
			dec	ebx
			mov	ah,0
			add bytes_converted, 1
			cmp al,0
			ja nextNum
		; Deal with negative sign
			pop edx
			; If edx is 0, jump to the end of the procedure
			cmp edx, 0
			jz finish
			mov ah, 45
			mov byte ptr cStr+[ebx], ah
			add bytes_converted, 1
		finish:
			ret
	inttoStr endp
; --------------------------------------------------------------------------------------------------
	strtoInt proc uses ebx ecx
		; Converts the string held in cStr into an integer and puts it in cInt
		mov eax, 0
		mov ebx, 0
		mov ecx, 0
		mov edx, 0
		; dl used to store whether the number is negative or positive
		mov al, byte ptr cStr+[ebx] 
		
		cmp al, 45
		jnz start
		inc ebx
		mov edx, 1
		start:
			; Push the result of this onto the stack for later use
			push edx
		getNext:
			mov al, byte ptr cStr+[ebx]
			sub al,30h
			add	ecx,eax
			inc	ebx
			cmp ebx,bytes_read
			jz cont
			mov	eax,10
			mul	ecx
			mov ecx,eax
			mov eax, 0
		
			jmp getNext
		
		cont:
			mov eax, ecx
			; Check whether this number needs to be converted to its negative representation
			pop edx
			cmp edx, 1
			jnz strtoInt_end
			; Convert number two its two's complement representation
			neg eax
		strtoInt_end:
			ret
	strtoInt endp
; --------------------------------------------------------------------------------------------------
	readString proc uses eax
		; This reads the text in from the console and stores it in the buffer variable			
		invoke ReadConsoleA, inputHandle, addr readBuffer, bufSize, addr bytes_read, 0
		; Remove the cr and lf from the string
		sub bytes_read, 2
		ret
	readString endp
; --------------------------------------------------------------------------------------------------
	writeString proc uses eax ebx, string:dword, len:dword, print_nl:dword
		; Write the message contained in writeBuffer to the console
		mov eax, len
		invoke WriteConsoleA, outputHandle, string, eax, addr bytes_written, 0
		; If the newline argument is equal to 0, jump to the end of this function.
		cmp print_nl, 0
		jz no_newline
			mov ebx, bytes_written
			invoke WriteConsoleA, outputHandle, addr newline, lengthof newline, addr bytes_written, 0
			mov bytes_written, ebx
		no_newline:
		ret
	writeString endp
; --------------------------------------------------------------------------------------------------
	close proc
		mov eax, lengthof exitmsg
		invoke writeString, offset exitmsg, lengthof exitmsg, 1
		; Close the program
		invoke ExitProcess, 0
	close endp
end