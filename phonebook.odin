package main

import "core:fmt"
import "core:os"
import "core:mem"
import "core:strings"
import "core:strconv"

Contact :: struct {
	name: string,
	last_name: string,
	nickname: string,
	phone_number: string,
	worst_nightmare: string,
}

Phonebook :: struct {
	entries: [dynamic]Contact,
}

prompt :: proc(prompt: string) -> string {
	buf: [256]byte
	str: string
	fmt.print(prompt)
	n, err := os.read(os.stdin, buf[:])
	if err < 0 {
		fmt.println("Err while reading input")
	}
	str = string(buf[:n]) // THIS IS JUST A POINTER TO BUF (BYTES) AND WRAPS IT IN STRING
	// ON SCOPE END BUF GETS FREED, BUT STR STILL POINTS TO IT, SO VALUE IS EMPTY
	str = strings.trim_space(str)
	/* !
	In Odin string is just a view over underlaying data buffer. In your case it points to buf which is
	local to read_input procedure. Once read_input returns its stack memory is gone, but returned string
	still points to it.
	strings.clone(str) works because it allocates memory for a string copy and return string which points
	into this memory. In this case you'll need to delete it in main to avoid memory leak.
	! */
	return strings.clone(str)			// THIS TOOK ME 2 HOURS I CANT JUST RETURN STR
}

new_contact :: proc(book: ^Phonebook) {
	new := Contact {
		name = prompt("First name >> "),
		last_name = prompt("Last name >> "),
		nickname = prompt("Nickname >> "),
		phone_number = prompt("Phone number >> "),
		worst_nightmare = prompt("Worst nightmare >> "),
	}
	append(&book.entries, new)
	fmt.printf("Successfully added [%v] to Phonebook!\n", new.name)
}

remove_contact :: proc(book: ^Phonebook, idx: int) {
	buf: [256]byte
	str: string
	for true {
		fmt.printf("You are about to remove [%v]\nAre you sure? Y(yes)/N(no) >> ", book.entries[idx].name)
		n, err := os.read(os.stdin, buf[:])
		if err < 0 {
			fmt.eprintln("Error reading input")
		}
		str = string(buf[:n])
		str = strings.trim_space(str)
		str = strings.to_lower(str)
		switch str {
			case "y", "yes":
				fmt.printf("Removing [%v] from Phonebook!\n", book.entries[idx].name)
				ordered_remove(&book.entries, idx)
				return
			case "n", "no":
				fmt.println("Cancelling...")
				return
		}
	}
}

display_contacts :: proc(book: Phonebook) {
	fmt.printf("%-10v|%-10v|%-10v|%-10v\n", "Index", "Name", "Last Name", "Phone number")
	for contact, idx in book.entries {
		fmt.printf("%v         |%-10v|%-10v|%-10v\n", idx, contact.name, contact.last_name, contact.phone_number)
	}
}

display_full_contact :: proc(book: Phonebook, idx: int) {
	fmt.printf("%-10v|%-10v|%-10v|%-10v|%-10v|%-10v\n",
		"Index", "Name", "Last Name", "Nickname", "Phone", "Worst nightmare")
	fmt.printf("%v         |%-10v|%-10v|%-10v|%-10v|%-10v\n",
		idx, book.entries[idx].name, book.entries[idx].last_name,
		book.entries[idx].nickname, book.entries[idx].phone_number,
		book.entries[idx].worst_nightmare)
}

select_contact :: proc (book: Phonebook) -> int {
	buf: [256]byte
	str: string
	for {
		fmt.print("Select index >> ")
		n, err := os.read(os.stdin, buf[:])
		if err < 0 {
			fmt.println("Err while reading input")
		}
		str = string(buf[:n])
		str = strings.trim_space(str)
		if idx, ok := strconv.parse_int(str); ok {
			if idx <= len(book.entries) && idx >= 0 {
				return idx
			} else {
				fmt.println("Error: Index out of range")
			}
		} else {
			fmt.println("Error: Please enter a digit")
		}
	}
}

main :: proc() {
	//------------------------
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	defer {		// ends on scope end, in thise case function finish.
		for _, entry in track.allocation_map {	// only care about value, not key of map
			fmt.eprintf("%v leaked %v bytes\n", entry.location, entry.size)
		}
		for entry in track.bad_free_array {
			fmt.eprintf("%v bad free\n", entry.location)
		}
		mem.tracking_allocator_destroy(&track)
	}
	//------------------------
	buf: [256]byte
	book: Phonebook
	defer {
		delete(book.entries)
	}
	if len(os.args) > 1 {
		fmt.eprintln("Invalid usage")
		os.exit(1)
	}
	fmt.println("Usage: ADD, SEARCH, REMOVE, EXIT")
	for {
		fmt.print("Input >> ")
		n, err := os.read(os.stdin, buf[:])
		if err < 0 {
			return
		}
		str := string(buf[:n])
		str = strings.to_lower(str)
		str = strings.trim_space(str)
		switch str {
			case "exit":
				os.exit(0)
			case "add":
				new_contact(&book)
			case "search":
				display_contacts(book)
				idx := select_contact(book)
				display_full_contact(book, idx)
			case "remove":
				display_contacts(book)
				idx := select_contact(book)
				remove_contact(&book, idx)
			case:
				fmt.println("Invalid Input")
		}
	}
}