module lists

import srackham.pcre2
import blockattributes
import delimitedblocks
import expansion
import iotext
import lineblocks
import spans

// Definition of List element.
struct Definition {
mut:
	mat            pcre2.Regex
	list_open_tag  string
	list_close_tag string
	item_open_tag  string
	item_close_tag string
	term_open_tag  string // Definition lists only.
	term_close_tag string // Definition lists only.
}

// ItemInfo contains information about a matched list item element.
struct ItemInfo {
mut:
	mat []string
	def Definition
	id  string
}

__global (
	lists_ids = []string{}
)

const no_match = 'NO_MATCH' // "no matching list item found" list ID constant.

const defs = [
	// Prefix match with backslash to allow escaping.
	// Unordered lists.
	// $1 is list ID $2 is item text.
	Definition{
		mat: pcre2.must_compile(r'^\\?\s*(-|\+|\*{1,4})\s+(.*)$')
		list_open_tag: '<ul>'
		list_close_tag: '</ul>'
		item_open_tag: '<li>'
		item_close_tag: '</li>'
	},
	// Ordered lists.
	// $1 is list ID $2 is item text.
	Definition{
		mat: pcre2.must_compile(r'^\\?\s*(?:\d*)(\.{1,4})\s+(.*)$')
		list_open_tag: '<ol>'
		list_close_tag: '</ol>'
		item_open_tag: '<li>'
		item_close_tag: '</li>'
	},
	// Definition lists.
	// $1 is term, $2 is list ID, $3 is definition.
	Definition{
		mat: pcre2.must_compile(r'^\\?\s*(.*[^:])(:{2,4})(|\s+.*)$')
		list_open_tag: '<dl>'
		list_close_tag: '</dl>'
		item_open_tag: '<dd>'
		item_close_tag: '</dd>'
		term_open_tag: '<dt>'
		term_close_tag: '</dt>'
	},
]

// noMatchItem returns "no matching list item found" constant.
fn no_match_item() ItemInfo {
	return ItemInfo{
		id: lists.no_match
	}
}

// Render list item in reader to writer.
pub fn render(mut reader iotext.Reader, mut writer iotext.Writer) bool {
	if reader.eof() {
		panic('premature eof')
	}
	mut start_item := match_item(mut reader)
	if start_item.id == lists.no_match {
		return false
	}
	lists_ids = []
	render_list(start_item, mut reader, mut writer)
	// lists_ids should now be empty.
	if lists_ids.len != 0 {
		panic('list stack failure')
	}
	return true
}

fn render_list(item ItemInfo, mut reader iotext.Reader, mut writer iotext.Writer) ItemInfo {
	mut current_item := item
	lists_ids << current_item.id
	writer.write(blockattributes.inject(current_item.def.list_open_tag))
	for {
		mut next_item := render_list_item(current_item, mut reader, mut writer)
		if next_item.id == lists.no_match || next_item.id != current_item.id {
			// End of list or next current_item belongs to ancestor.
			writer.write(current_item.def.list_close_tag)
			lists_ids.pop()
			return next_item
		}
		current_item = next_item
	}
	panic('this line should be unreachable')
}

// Render the current list item, return the next list item or null if there are no more items.
fn render_list_item(item ItemInfo, mut reader iotext.Reader, mut writer iotext.Writer) ItemInfo {
	mut text := ''
	if item.mat.len == 4 { // 3 match groups => definition list.
		mut attrs := blockattributes_attrs
		writer.write(blockattributes.inject(item.def.term_open_tag))
		attrs.id = ''
		blockattributes_attrs = attrs // Restore consumed block attributes.
		text = spans.replace_inline(item.mat[1], expansion.Options{
			macros: true
			spans: true
		})
		writer.write(text)
		writer.write(item.def.term_close_tag)
	}
	writer.write(blockattributes.inject(item.def.item_open_tag))
	// Process item text from first line.
	mut item_lines := iotext.new_writer()
	text = item.mat[item.mat.len - 1]
	item_lines.write(text + '\n')
	// Process remainder of list item i.e. item text, optional attached block, optional child list.
	reader.next()
	mut attached_lines := iotext.new_writer()
	mut blank_lines := 0
	mut attached_done := false
	mut next_item := ItemInfo{}
	for {
		blank_lines = consume_block_attributes(mut reader, mut attached_lines)
		if blank_lines >= 2 || blank_lines == -1 {
			// EOF or two or more blank lines terminates list.
			next_item = no_match_item()
			break
		}
		next_item = match_item(mut reader)
		if next_item.id != lists.no_match {
			if lists_ids.index(next_item.id) != -1 {
				// Next item belongs to current list or a parent list.
			} else {
				// Render child list.
				next_item = render_list(next_item, mut reader, mut attached_lines)
			}
			break
		}
		if attached_done {
			break // Multiple attached blocks are not permitted.
		}
		if blank_lines == 0 {
			mut saved_ids := lists_ids.clone()
			lists_ids = []
			if delimitedblocks.render(mut reader, mut attached_lines, ['comment', 'code', 'division',
				'html', 'quote'])
			{
				attached_done = true
			} else {
				// Item body line.
				item_lines.write(reader.cursor() + '\n')
				reader.next()
			}
			lists_ids = saved_ids.clone()
		} else if blank_lines == 1 {
			if delimitedblocks.render(mut reader, mut attached_lines, ['indented', 'quote-paragraph']) {
				attached_done = true
			} else {
				break
			}
		}
	}
	// Write item text.
	text = item_lines.string().trim_space()
	text = spans.replace_inline(text, expansion.Options{
		macros: true
		spans: true
	})
	writer.write(text)
	// Write attachment and child list.
	writer.buffer << attached_lines.buffer
	// Close list item.
	writer.write(item.def.item_close_tag)
	return next_item
}

// Consume blank lines and Block Attributes.
// Return number of blank lines read or -1 if EOF.
fn consume_block_attributes(mut reader iotext.Reader, mut writer iotext.Writer) int {
	mut blanks := 0
	for {
		if reader.eof() {
			return -1
		}
		if lineblocks.render(mut reader, mut writer, ['attributes']) {
			continue
		}
		if reader.cursor() != '' {
			return blanks
		}
		blanks++
		reader.next()
	}
	panic('this line should be unreachable')
}

// Check if the line at the reader cursor matches a list related element.
// Unescape escaped list items in reader.
// If it does not match a list related element return null.
fn match_item(mut reader iotext.Reader) ItemInfo {
	if !reader.eof() {
		mut item := ItemInfo{} // ItemInfo factory.
		for _, def in lists.defs {
			mut mat := def.mat.find_one_submatch(reader.cursor()) or { continue }
			if mat[0][0] == `\\` {
				reader.set_cursor(reader.cursor()[1..]) // Drop backslash.
				break
			}
			item.mat = mat
			item.def = def
			item.id = mat[mat.len - 2] // The second to last match group is the list ID.
			return item
		}
	}
	return no_match_item()
}
