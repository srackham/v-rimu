module iotext

import srackham.pcre2
import encoding.utf8
import options

/*
Reader class.
*/
// Reader state.
pub struct Reader {
pub mut:
	lines []string
	pos   int // Line index of current line.
}

/*
Writer class.
*/
// Writer is a container for lines of text.
pub struct Writer {
pub mut:
	buffer []string // Appending an array is faster than string concatenation.
}

// NewReader returns a new reader for text string.
pub fn new_reader(text string) Reader {
	mut s := text
	if !utf8.validate_str(text) {
		options.error_callback('invalid UTF-8 input')
		s = ''
	}
	mut r := Reader{}
	s = s.replace('\u0000', ' ') // Used internally by spans package.
	s = s.replace('\u0001', ' ') // Used internally by spans package.
	s = s.replace('\u0002', ' ') // Used internally by macros package.
	r.lines = pcre2.must_compile(r'\r\n|\r|\n').split_all(s)
	return r
}

// Eof returns true is reader is at end of text.
pub fn (r Reader) eof() bool {
	return r.pos >= r.lines.len
}

// SetCursor sets the reader cursor line.
pub fn (mut r Reader) set_cursor(value string) {
	if r.eof() {
		panic('unexpected eof')
	}
	r.lines[r.pos] = value
}

// Cursor returns the cursor line.
pub fn (r Reader) cursor() string {
	if r.eof() {
		panic('unexpected eof')
	}
	return r.lines[r.pos]
}

// Next moves cursor to next input line.
pub fn (mut r Reader) next() {
	if !r.eof() {
		r.pos++
	}
}

// ReadTo reads to the first line matching the regular expression.
// Return the array of lines preceding the match plus a line containing
// the $1 match group (if it exists).
// If an EOF is encountered return all lines.
// Exit with the reader pointing to the line containing the matched line.
pub fn (mut r Reader) read_to(re pcre2.Regex) []string {
	mut res := []string{}
	for !r.eof() {
		if mat := re.find_one_submatch(r.cursor()) {
			if mat.len > 1 {
				res << mat[1]
			}
			break
		} else {
			res << r.cursor()
			r.next()
		}
	}
	return res
}

// SkipBlankLines advances cursor to next non-blank line.
pub fn (mut r Reader) skip_blank_lines() {
	for !r.eof() && r.cursor().trim_space() == '' {
		r.next()
	}
}

// NewWriter return a new empty Writer.
pub fn new_writer() Writer {
	return Writer{}
}

pub fn (mut w Writer) write(s string) {
	w.buffer << s
}

pub fn (w Writer) string() string {
	return w.buffer.join('')
}
