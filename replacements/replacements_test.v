module replacements

pub fn test_init() {
	init()
	assert default_defs.len == replacements_defs.len
	assert default_defs == replacements_defs
	assert u64(&default_defs) != u64(&replacements_defs)
}

pub fn test_set_definition() {
	init()
	set_definition(r'\\?<image:([^\s|]+?)>', '', 'foo')
	assert replacements_defs.len == default_defs.len
	set_definition('bar', 'mi', 'foo')
	assert replacements_defs.len == default_defs.len + 1
	assert replacements_defs[replacements_defs.len - 1].mat.pattern == '(?m)(?i)bar'
}
