module rimu

import document
import options

// CallbackFunction is the API callback function type.
pub type CallbackFunction = fn (message CallbackMessage)

// CallbackMessage contains the callback message passed to the callback function.
pub type CallbackMessage = options.CallbackMessage

// RenderOptions contains the API render options.
pub type RenderOptions = options.RenderOptions

// Render is public API to translate Rimu Markup to HTML.
pub fn render(text string, opts RenderOptions) string {
	options.update_options(opts)
	return document.render(text)
}
