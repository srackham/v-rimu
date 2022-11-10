module iotext

import srackham.pcre2

pub fn test_reader() {
	mut reader := new_reader('')
	assert reader.eof() == false
	assert reader.lines.len == 1
	assert reader.cursor() == ''
	reader.next()
	assert reader.eof() == true
	reader = new_reader('Hello\nWorld!')
	assert reader.lines.len == 2
	assert reader.cursor() == 'Hello'
	reader.next()
	assert reader.cursor() == 'World!'
	assert reader.eof() == false
	reader.next()
	assert reader.eof() == true
	reader = new_reader('\n\nHello')
	assert reader.lines.len == 3
	reader.skip_blank_lines()
	assert reader.cursor() == 'Hello'
	assert reader.eof() == false
	reader.next()
	assert reader.eof() == true
	reader = new_reader('Hello\n*\nWorld!\nHello\n< Goodbye >')
	assert reader.lines.len == 5
	mut lines := reader.read_to(pcre2.must_compile(r'\*'))
	assert lines.len == 1
	assert lines[0] == 'Hello'
	assert reader.eof() == false
	reader.next()
	lines = reader.read_to(pcre2.must_compile(r'^<(.*)>$'))
	assert lines.len == 3
	assert lines[2] == ' Goodbye '
	assert reader.eof() == false
	reader.next()
	assert reader.eof() == true
	reader = new_reader('\n\nHello\nWorld!\n\nfoo\nbar')
	assert reader.lines.len == 7
	reader.skip_blank_lines()
	assert reader.pos == 2
	lines = reader.read_to(pcre2.must_compile(r'^$'))
	assert reader.pos == 4
	assert lines == ['Hello', 'World!']
	reader.skip_blank_lines()
	assert reader.pos == 5
	lines = reader.read_to(pcre2.must_compile(r'^$'))
	assert reader.pos == 7
	assert lines == ['foo', 'bar']
	assert reader.eof() == true
}

pub fn test_writer() {
	mut writer := new_writer()
	writer.write('Hello')
	assert writer.buffer[0] == 'Hello'
	writer.write('World!')
	assert writer.buffer[1] == 'World!'
	assert writer.string() == 'HelloWorld!'
}
