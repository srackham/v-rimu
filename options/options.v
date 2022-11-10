module options

import str

// TODO implement as singleton.
__global (
	api_init         fn ()
	safe_mode        int
	html_replacement string
	callback         CallbackFunction
)

const (
	// Pseudo nil option values (values that are assumed invalid).
	nil_html_replacement = 'ad17a6bf-5c92-4a16-8e6e-ab5622f2a2be'
	nil_safe_mode        = 2847238
	nil_callback         = CallbackFunction(0)
)

pub struct CallbackMessage {
pub:
	kind string
	text string
}

// CallbackFunction is the API callback function type.
type CallbackFunction = fn (message CallbackMessage)

// RenderOptions sole use is for passing options into the public API.
pub struct RenderOptions {
pub mut:
	reset            bool
	safe_mode        int    = options.nil_safe_mode
	html_replacement string = options.nil_html_replacement
	callback         CallbackFunction = options.nil_callback
}

fn init() {
	initialize()
}

// Init resets options to default values.
pub fn initialize() {
	safe_mode = 0
	html_replacement = '<mark>replaced HTML</mark>'
	callback = options.nil_callback
}

// Return true if safe_mode is non-zero.
pub fn is_safe_mode_nz() bool {
	return safe_mode != 0
}

// Return true if Macro Definitions are ignored.
pub fn skip_macro_defs() bool {
	return safe_mode != 0 && safe_mode & 0x8 == 0
}

// Return true if Block Attribute elements are ignored.
pub fn skip_block_attributes() bool {
	return safe_mode & 0x4 != 0
}

// UpdateOptions processes non-nil opts fields.
// Error callback option values are illegal.
pub fn update_options(opts RenderOptions) {
	// Install callback first to ensure option errors are logged.
	if opts.callback != options.nil_callback {
		callback = opts.callback
	}
	// Reset takes priority.
	if opts.reset {
		set_option('reset', '$opts.reset')
	}
	// Install callback again in case it has been reset.
	if opts.callback != options.nil_callback {
		callback = opts.callback
	}
	if opts.safe_mode != options.nil_safe_mode {
		set_option('safeMode', '$opts.safe_mode')
	}
	if opts.html_replacement != options.nil_html_replacement {
		set_option('htmlReplacement', opts.html_replacement)
	}
}

// SetOption parses a named API option value.
// Error callback if option values are illegal.
pub fn set_option(name string, value string) {
	match name {
		'safeMode' {
			n := value.parse_int(10, 0) or { -1 }
			if n < 0 || n > 15 {
				error_callback('illegal safeMode API option value: ' + value)
			} else {
				safe_mode = int(n)
			}
		}
		'htmlReplacement' {
			html_replacement = value
		}
		'reset' {
			if b := str.parse_bool(value) {
				if b {
					api_init()
				}
			} else {
				error_callback('illegal reset API option value: ' + value)
			}
		}
		else {
			error_callback('illegal API option name: ' + name)
		}
	}
}

// Htmlsafe_modeFilter filters HTML based on current safe_mode.
pub fn html_safe_mode_filter(html string) string {
	match safe_mode & 0x3 {
		0 { // Raw HTML (default behavior).
			return html
		}
		1 { // Drop HTML.
			return ''
		}
		2 { // Replace HTML with 'htmlReplacement' option string.
			return html_replacement
		}
		3 { // Render HTML as text.
			return str.replace_special_chars(html)
		}
		else {
			return ''
		}
	}
}

pub fn error_callback(message string) {
	if callback != options.nil_callback {
		callback(CallbackMessage{
			kind: 'error'
			text: message
		})
	}
}
