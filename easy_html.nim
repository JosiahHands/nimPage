import std/[macros, strutils, tables]

export tables

type
    HtmlTemplateKind {.pure.} = enum
        tag,
        text,
        paste,
        already_pasted,

    HtmlAttribute = object
        has_value: bool
        value: string

    HtmlTemplate * = object
        kind: HtmlTemplateKind

        tag: string
        children: seq[HtmlTemplate]
        attributes: OrderedTable[string, HtmlAttribute]

        text: string

var html_tmpl_stack {.threadvar.}: seq[HtmlTemplate]

proc ensure_html_stack() =
    if html_tmpl_stack.len == 0:
        html_tmpl_stack.add HtmlTemplate()

template defer_pop() =
    var it_has_been_popped = false
    defer:
        if not it_has_been_popped:
            discard pop(html_tmpl_stack)
    proc private_pop_and_set_do_not_use(): HtmlTemplate =
        it_has_been_popped = true
        return pop(html_tmpl_stack)

template common_html(str: string; body): untyped =
    block:
        ensure_html_stack()
        html_tmpl_stack &= HtmlTemplate(
            tag: str,
            kind: tag,
        )
        defer_pop()
        block:
            body
        private_pop_and_set_do_not_use()

proc apply_paste(a: var HtmlTemplate; b: HtmlTemplate) =
    for it in mitems(a.children):
        case it.kind
        of tag, already_pasted:
            apply_paste(it, b)
        of paste:
            it = b
        else: discard

template common_html(tmpl: HtmlTemplate; body): untyped =
    block:
        var ret = tmpl

        ensure_html_stack()
        html_tmpl_stack &= HtmlTemplate(
            kind: already_pasted,
        )
        defer_pop()

        body

        var inner = private_pop_and_set_do_not_use()

        for key, val in inner.attributes:
            ret.attributes[key] = val
        clear(inner.attributes)
        apply_paste(ret, inner)
        ret

template html*(tag; body) =
    ensure_html_stack()
    let x = common_html tag:
        body
    html_tmpl_stack[^1].children &= x

macro html_tmpl*(tag; fn) =
    expect_kind(fn, nnk_proc_def)

    if fn.params[0].kind != nnk_empty:
        error("expected proc with no return type", fn.params[0])
    fn.params[0] = ident "HtmlTemplate"

    let old_body = fn.body
    result = fn

    result.body = quote do:
        ensure_html_stack()
        add(html_tmpl_stack, HtmlTemplate())
        defer_pop()

        var x = `tag`

        result = common_html x: discard

        html x:
            `old_body`

        var parent = private_pop_and_set_do_not_use()
        return parent.children[0]

proc escape_html(str: string): string =
    for ch in str:
        case ch
        of '&': result &= "&amp;"
        of '<': result &= "&lt;"
        of '>': result &= "&gt;"
        of '"': result &= "&quot;"
        of '\'': result &= "&#39;"
        else: result &= ch

proc raw_html_text*(str: string) =
    ensure_html_stack()
    html_tmpl_stack[^1].children &= HtmlTemplate(
        text: str,
        kind: text,
    )

proc html_text*(str: string) =
    ensure_html_stack()
    html_tmpl_stack[^1].children &= HtmlTemplate(
        text: escape_html(str),
        kind: text,
    )

proc css*(str: string) =
    html "style":
        raw_html_text(str)

proc js*(str: string) =
    html "script":
        raw_html_text(str)

proc paste_body*() =
    ensure_html_stack()
    html_tmpl_stack[^1].children &= HtmlTemplate(
        kind: paste,
    )

proc attr*(key, val: string) =
    ensure_html_stack()
    html_tmpl_stack[^1].attributes[key] = HtmlAttribute(
        has_value: true,
        value: escape_html(val),
    )

proc attr*(key: string) =
    ensure_html_stack()
    html_tmpl_stack[^1].attributes[key] = HtmlAttribute(has_value: false)

proc is_void_tag(tag: string): bool =
    case to_lower_ascii(tag)
    of "area", "base", "br", "col", "embed", "hr", "img", "input",
        "link", "meta", "source", "track", "wbr":
        true
    else:
        false

proc `$`*(tmpl: HtmlTemplate): string =
    case tmpl.kind:
    of tag:
        result &= "<" & tmpl.tag
        for key, attr in tmpl.attributes:
            result &= " " & key
            if attr.has_value:
                result &= "=\"" & attr.value & "\""
        result &= ">\n"
        if is_void_tag(tmpl.tag):
            return

        for it in tmpl.children:
            result &= $it

        result &= "</" & tmpl.tag & ">\n"
    of text:
        result &= tmpl.text & "\n"
    of paste: discard
    of already_pasted:
        for it in tmpl.children:
            result &= $it
