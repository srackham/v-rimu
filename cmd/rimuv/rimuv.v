module main

import srackham.rimu
import os

const (
	version    = '11.4.0'
	stdin_name = '-'
)

const (
	// Pseudo nil option values (values that are assumed invalid).
	nil_html_replacement = 'ad17a6bf-5c92-4a16-8e6e-ab5622f2a2be'
	nil_safe_mode        = 2847238
)

// rimurcPath returns path of $HOME/.rimurc file.
// Return "" if $HOME not found.
fn rimurc_path() string {
	return os.join_path(os.home_dir(), '.rimurc')
}

// Helpers.
[noreturn]
fn die(message string) {
	if message != '' {
		eprintln(message)
	}
	exit(1)
}

fn read_resource(name string) string {
	return match name {
		'classic-footer.rmu' { $embed_file('./resources/classic-footer.rmu').to_string() }
		'classic-header.rmu' { $embed_file('./resources/classic-header.rmu').to_string() }
		'flex-footer.rmu' { $embed_file('./resources/flex-footer.rmu').to_string() }
		'flex-header.rmu' { $embed_file('./resources/flex-header.rmu').to_string() }
		'manpage.txt' { $embed_file('./resources/manpage.txt').to_string() }
		'plain-footer.rmu' { $embed_file('./resources/plain-footer.rmu').to_string() }
		'plain-header.rmu' { $embed_file('./resources/plain-header.rmu').to_string() }
		'sequel-footer.rmu' { $embed_file('./resources/sequel-footer.rmu').to_string() }
		'sequel-header.rmu' { $embed_file('./resources/sequel-header.rmu').to_string() }
		'v8-footer.rmu' { $embed_file('./resources/v8-footer.rmu').to_string() }
		'v8-header.rmu' { $embed_file('./resources/v8-header.rmu').to_string() }
		else { panic('illegal resource name: ${name}') }
	}
}

fn import_layout_file(name string) string {
	die('external layouts not supported in rimuv')
	return ''
}

fn shift<T>(mut a []T, err_msg string) T {
	if a.len == 0 {
		if err_msg == '' {
			die('shift: array argument is empty')
		} else {
			die(err_msg)
		}
	}
	res := a.first()
	// a.drop(1)	See https://github.com/vlang/v/issues/16322
	a.delete(0)
	return res
}

[noreturn]
fn main() {
	mut args := os.args.clone()
	shift(mut args, '')
	mut safe_mode := nil_safe_mode // TODO shadows global
	mut html_replacement := nil_html_replacement // TODO shadows global
	mut layout := ''
	mut no_rimurc := false
	mut prepend_files := []string{}
	mut pass := false
	mut prepend := ''
	mut outfile := ''
	outer: for args.len > 0 {
		mut arg := shift(mut args, '')
		match arg {
			'--help', '-h' {
				println('\n${read_resource('manpage.txt').replace('rimuc', 'rimuv')}')
				exit(0)
			}
			'--version' {
				println(version)
				exit(0)
			}
			'--lint', '-l' {
				break
			}
			'--output', '-o' {
				outfile = shift(mut args, 'missing --output file name')
			}
			'--pass' {
				pass = true
			}
			'--prepend', '-p' {
				prepend += shift(mut args, 'missing --prepend value') + '\n'
			}
			'--prepend-file' {
				prepend_files << shift(mut args, 'missing --prepend-file file name')
				// prepend_files.push(shift(mut args, 'missing --prepend-file file name'))// TODO Compiler bug.
			}
			'--no-rimurc' {
				no_rimurc = true
			}
			'--safe-mode', '--safeMode' {
				mut s := shift(mut args, 'missing --safe-mode value')
				mut n := s.parse_int(10, 0) or { die('illegal --safe-mode option value: ' + s) }
				safe_mode = int(n)
			}
			'--html-replacement', '--htmlReplacement' {
				html_replacement = shift(mut args, 'missing --html-replacement value')
			}
			'--highlightjs', '--mathjax', '--section-numbers', '--theme', '--title', '--lang',
			'--toc', '--no-toc', '--sidebar-toc', '--dropdown-toc', '--custom-toc', '--header-ids',
			'--header-links' {
				mut macro_value := ''
				if '--lang|--title|--theme'.contains(arg) {
					macro_value = shift(mut args, 'missing ${arg} value')
				} else {
					macro_value = 'true'
				}
				prepend += "{${arg}}='${macro_value}'\n"
			}
			'--layout', '--styled-name' {
				layout = shift(mut args, 'missing --layout value')
				prepend += "{--header-ids}='true'\n"
			}
			'--styled', '-s' {
				prepend += "{--header-ids}='true'\n"
				prepend += "{--no-toc}='true'\n"
				layout = 'sequel'
			}
			else {
				args.prepend(arg)
				break outer
			}
		}
	}
	mut files := args.clone()
	if files.len == 0 {
		files << stdin_name
	} else if files.len == 1 && layout != '' && files[0] != '-' && outfile != '' {
		mut ext := os.file_ext(files[0])
		outfile = files[0][..files[0].len - ext.len] + '.html'
	}
	resource_tag := 'resource:'
	prepend_opt := '--prepend options'
	if layout != '' {
		files.prepend('${resource_tag}${layout}-header.rmu')
		// files.push('$resource_tag$layout-footer.rmu')// TODO Compiler bug.
		files << '${resource_tag}${layout}-footer.rmu'
	}
	if !no_rimurc && os.exists(rimurc_path()) {
		prepend_files.prepend(rimurc_path())
	}
	if prepend != '' {
		prepend_files << prepend_opt
	}
	files.prepend(prepend_files)
	mut output := ''
	mut errors := 0
	mut opts := rimu.RenderOptions{}
	if html_replacement != nil_html_replacement {
		opts.html_replacement = html_replacement
	}
	for mut infile in files {
		mut source := ''
		match true {
			infile.starts_with(resource_tag) {
				// infile = infile[resource_tag.len..]	// TODO Compiler bug.
				infile = infile[resource_tag.len..infile.len]
				if ['classic', 'flex', 'plain', 'sequel', 'v8'].contains(layout) {
					source = read_resource(infile)
				} else {
					source = import_layout_file(infile)
				}
				opts.safe_mode = 0
			}
			infile == stdin_name {
				source = os.get_raw_lines_joined()
				if safe_mode != nil_safe_mode {
					opts.safe_mode = safe_mode
				}
			}
			infile == prepend_opt {
				source = prepend
				opts.safe_mode = 0
			}
			else {
				if !os.exists(infile) {
					die('source file does not exist: ${infile}')
				}
				source = os.read_file(infile) or { die(err.msg()) }
				if prepend_files.contains(infile) {
					opts.safe_mode = 0
				} else {
					if safe_mode != nil_safe_mode {
						opts.safe_mode = safe_mode
					}
				}
			}
		}
		if !(infile.ends_with('.html') || (pass && infile == stdin_name)) {
			mut errors_ref := &errors
			opts.callback = fn [infile, mut errors_ref] (message rimu.CallbackMessage) {
				mut f := infile
				if infile == stdin_name {
					f = '/dev/stdin'
				}
				mut msg := '${message.kind}: ${f}: ${message.text}'
				if msg.len > 120 {
					msg = msg[..117] + '...'
				}
				println(msg)
				if message.kind == 'error' {
					unsafe {
						*errors_ref = *errors_ref + 1
					}
				}
			}
			source = rimu.render(source, opts)
		}
		source = source.trim_space()
		if source != '' {
			output += source + '\n'
		}
	}
	output = output.trim_space()
	if outfile == '' || outfile == '-' {
		print(output)
	} else {
		os.write_file(outfile, output) or { die(err.msg()) }
	}
	if errors > 0 {
		exit(1)
	}
	exit(0)
}
