module options

pub fn test_initialize() {
	initialize()
	assert safe_mode == 0
	assert '<mark>replaced HTML</mark>' == html_replacement
	assert callback == unsafe { nil }
}

pub fn test_is_safe_mode_nz() {
	initialize()
	assert !is_safe_mode_nz()
	safe_mode = 1
	assert is_safe_mode_nz()
}

pub fn test_skip_macro_defs() {
	initialize()
	assert !skip_macro_defs()
	safe_mode = 1
	assert skip_macro_defs()
	safe_mode = 1 + 8
	assert !skip_macro_defs()
}

pub fn test_skip_block_attributes() {
	initialize()
	assert !skip_block_attributes()
	safe_mode = 1
	assert !skip_block_attributes()
	safe_mode = 1 + 4
	assert skip_block_attributes()
}

pub fn test_update_options() {
	initialize()
	update_options(RenderOptions{
		safe_mode: 1
	})
	assert safe_mode == 1
	assert html_replacement == '<mark>replaced HTML</mark>'
	update_options(RenderOptions{
		html_replacement: 'foo'
	})
	assert safe_mode == 1
	assert html_replacement == 'foo'
}

pub fn test_set_option() {
	initialize()
	set_option('safeMode', 'qux')
	assert safe_mode == 0
	set_option('safeMode', '42')
	assert safe_mode == 0
	set_option('safeMode', '1')
	assert safe_mode == 1
	set_option('reset', 'qux')
	assert safe_mode == 1
}

pub fn test_html_safe_mode_filter() {
	initialize()
	assert html_safe_mode_filter('foo') == 'foo'
	safe_mode = 1
	assert html_safe_mode_filter('foo') == ''
	safe_mode = 2
	assert html_safe_mode_filter('foo') == '<mark>replaced HTML</mark>'
	safe_mode = 3
	assert html_safe_mode_filter('<br>') == '&lt;br&gt;'
	safe_mode = 0 + 4
	assert html_safe_mode_filter('foo') == 'foo'
}
