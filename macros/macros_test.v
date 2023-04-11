module macros

pub fn test_values() {
	initialize()
	assert macros_defs.len == 2
	assert value('--')? == ''

	set_value('foo', 'bar', "'")
	assert macros_defs.len == 3
	assert value('foo')? == 'bar'

	set_value('foo?', 'baz', "'")
	assert macros_defs.len == 3
	assert value('foo')? == 'bar'

	set_value('foo', 'baz', "'")
	assert macros_defs.len == 3
	assert value('foo')? == 'baz'
}

pub fn test_render() {
	assert render('', false) == ''
	assert render('{--}{--header-ids}', false) == ''
}
