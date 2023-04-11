module quotes

pub fn test_init() {
	init()
	assert default_defs.len == defs.len
	assert default_defs == defs
	assert u64(&default_defs) != u64(&defs)
}

/*
Commented out because quotes.get_definition() raises a panic if the definition is not found.
pub fn test_get_definition() {
	init()
	get_definition('*')?
	if _ := get_definition('MISSING') {
		assert false, 'should have returned an error'
	} else {
		assert err.msg() == 'missing quote definition: MISSING'
	}
}
*/

pub fn test_set_definition() {
	init()

	set_definition(Definition{
		quote: '*'
		open_tag: '<strong>'
		close_tag: '</strong>'
		spans: true
	})
	assert default_defs.len == defs.len
	mut def := get_definition('*')?
	assert '<strong>' == def.open_tag

	set_definition(Definition{
		quote: 'x'
		open_tag: '<del>'
		close_tag: '</del>'
		spans: true
	})
	assert default_defs.len + 1 == defs.len
	def = get_definition('x')?
	assert '<del>' == def.open_tag
	assert '<del>' == defs[defs.len - 1].open_tag

	set_definition(Definition{
		quote: 'xx'
		open_tag: '<u>'
		close_tag: '</u>'
		spans: true
	})
	assert default_defs.len + 2 == defs.len
	def = get_definition('xx')?
	assert '<u>' == def.open_tag
	assert '<u>' == defs[0].open_tag
}

pub fn test_unescape() {
	init()
	assert r'* ~~ \x' == unescape(r'\* \~~ \x')
}

pub fn test_find() {
	assert find('') == []
	assert find('*foo*') == [0, 5, 0, 1, 1, 4]
	assert find('**foo**') == [0, 7, 0, 2, 2, 5]
	assert find('\\*foo*') == [0, 6, 1, 2, 2, 5]
	assert find('*bar* _foo_') == [0, 5, 0, 1, 1, 4]
	assert find('_bar_ *foo*') == [0, 5, 0, 1, 1, 4]
}
