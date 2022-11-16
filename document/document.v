module document

import blockattributes
import delimitedblocks
import iotext
import lineblocks
import lists
import macros
import options
import quotes
import replacements

// Dependency injectiion so we can use document functions in imported packages without incuring import cycle errors.
fn init() {
	doc_init = initialize
	doc_render = render
}

// Init initialises Rimu state.
pub fn initialize() {
	blockattributes.initialize()
	options.initialize()
	delimitedblocks.initialize()
	macros.initialize()
	quotes.initialize()
	replacements.initialize()
}

// Render source text to HTML string.
pub fn render(source string) string {
	mut reader := iotext.new_reader(source)
	mut writer := iotext.new_writer()
	for !reader.eof() {
		reader.skip_blank_lines()
		if reader.eof() {
			break
		}
		if lineblocks.render(mut reader, mut writer, []) {
			continue
		}
		if lists.render(mut reader, mut writer) {
			continue
		}
		if delimitedblocks.render(mut reader, mut writer, []) {
			continue
		}
		// This code should never be executed (normal paragraphs should match anything).
		panic('no matching delimited block found')
	}
	return writer.string()
}
