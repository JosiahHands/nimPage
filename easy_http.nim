{.push raises: [].}

import std/[
    asyncdispatch,
    asynchttpserver,
    macros,
    mimetypes,
    os,
    parseutils,
    strutils,
    tables,
    uri,
]
export uri, asynchttpserver, asyncdispatch, tables

template catch(expr): untyped =
    block:
        type T = typeof(expr)
        try:
            (val: expr, err: "")
        except CatchableError as e:
            (val: default(T), err: if e.msg.len > 0: e.msg else: "Error")

type HttpPath * = object
    request *: Request
    parts *: seq[string]

type HttpResponse * = object
    code *: HttpCode
    content *: string
    headers *: seq[tuple[key: string, val: string]]

macro http_server*(fn): untyped =
    expect_kind(fn, nnk_proc_def)
    result = fn
    result.add_pragma(ident "closure")
    result.add_pragma(ident "gcsafe")
    result.add_pragma(new_tree(
        nnk_expr_colon_expr,
        ident "raises",
        new_tree(nnk_bracket)
    ))

type HttpHandler = proc(
    req: Request
): HttpResponse {.closure, gcsafe, raises: [].}

{.pop.}

proc run_http_server*(port: uint16; handler: HttpHandler): string {.raises: [].} =
    proc run_event_loop() {.async, raises: [Exception].} =
        var server = new_async_http_server()

        proc callback(req: Request) {.
            async,
            closure,
            gcsafe,
            raises: [Exception]
        .} =
            let response = handler(req)
            try:
                await respond(
                    req,
                    response.code,
                    response.content,
                    new_http_headers(response.headers)
                )
            except Exception:
                discard

        server.listen(Port(port))

        while true:
            if should_accept_request(server):
                await accept_request(server, callback)
            else:
                await sleep_async(500)

    try:
        wait_for run_event_loop()
    except Exception as error:
        return error.msg

{.push raises: [].}

proc http_send_html*(content: string; code: HttpCode = Http200): HttpResponse =
    return HttpResponse(
        code: code,
        content: content,
        headers: @[("Content-Type", "text/html; charset=utf-8")],
    )

proc http_send_file*(path: string; code: HttpCode = Http200): tuple[
    response: HttpResponse,
    err: string
] =
    var mime_types = new_mimetypes()
    var content_type = get_mimetype(
        mime_types,
        split_file(path).ext,
        "application/octet-stream"
    )

    if starts_with(content_type, "text/"):
        content_type &= "; charset=utf-8"

    var content_result = catch(read_file(path))
    if content_result.err.len > 0:
        result.err = content_result.err
        return

    result.response = HttpResponse(
        code: code,
        content: content_result.val,
        headers: @[("Content-Type", content_type)],
    )

proc parse_form*(req: Request): Table[string, string] =
    for key, value in decode_query(req.body):
        result[key] = value

proc get_path*(req: Request): HttpPath =
    result.request = req

    for part in split(req.url.path, "/"):
        if part.len > 0:
            result.parts.add decode_url(
                part,
                decode_plus = false
            )

proc get_path_str*(path: HttpPath): string =
    result = "/"

    for i, part in path.parts:
        if i > 0: result &= "/"
        result &= encode_url(part, use_plus = false)

type MatchPathArgKind {.pure.} = enum
    val_none
    val_string
    val_path
    ptr_string
    ptr_int

type MatchPathArg = object
    kind: MatchPathArgKind
    val_string: string
    val_path: HttpPath
    ptr_string: ptr string
    ptr_int: ptr int

proc to_match_path_arg*[T](x: T): MatchPathArg =
    when T is MatchPathArg: result = x
    elif T is string:       result = MatchPathArg(kind: val_string, val_string: x)
    elif T is HttpPath:     result = MatchPathArg(kind: val_path,   val_path: x)
    elif T is ptr string:   result = MatchPathArg(kind: ptr_string, ptr_string: x)
    elif T is ptr int:      result = MatchPathArg(kind: ptr_int,    ptr_int: x)
    else: {.error: "invalid type " & $T.}

proc match_path_partial_any*(
    path: HttpPath;
    args: varargs[MatchPathArg, to_match_path_arg]
): tuple[
    matched: bool,
    path_start: HttpPath,
    path_end: HttpPath,
] =
    var i = 0

    result.path_start.request = path.request
    result.path_end.request = path.request

    defer:
        if i > 0:
            result.path_start.parts = path.parts[0..<i]
        if i < path.parts.len:
            result.path_end.parts = path.parts[i..^1]

    for it in args:
        if it.kind == val_path:
            for value in it.val_path.parts:
                if i >= path.parts.len or value != path.parts[i]: return
                i += 1
            continue

        if i >= path.parts.len: return

        let part = path.parts[i]

        case it.kind
        of val_none:
            discard
        of val_string:
            if it.val_string != part: return
        of val_path:
            discard
        of ptr_string:
            it.ptr_string[] = part
        of ptr_int:
            var x: int
            try:
                var consumed = parse_int(part, x)
                if consumed != part.len or consumed == 0: return
            except CatchableError:
                return
            it.ptr_int[] = x

        i += 1

    result.matched = true

proc match_path_partial*(
    path: HttpPath;
    http_method: HttpMethod;
    args: varargs[MatchPathArg, to_match_path_arg]
): tuple[
    matched: bool,
    path_start: HttpPath,
    path_end: HttpPath,
] =
    result.path_start.request = path.request
    result.path_end = path

    if path.request.req_method != http_method: return
    return match_path_partial_any(path, args)

proc match_path_any*(
    path: HttpPath;
    args: varargs[MatchPathArg, to_match_path_arg]
): bool =
    var partial = match_path_partial_any(path, args)
    return partial.matched and partial.path_end.parts.len == 0

proc match_path*(
    path: HttpPath;
    http_method: HttpMethod;
    args: varargs[MatchPathArg, to_match_path_arg]
): bool =
    var partial = match_path_partial(path, http_method, args)
    return partial.matched and partial.path_end.parts.len == 0

proc serve_files*(
    path: HttpPath;
    prefix: HttpPath;
    files: seq[string]
): tuple[
    matched: bool,
    res: HttpResponse,
    err: string,
] =
    for it in files:
        if match_path(path, HttpGet, prefix, it):
            var (res, err) = http_send_file("." & get_path_str(prefix) & "/" & it)
            return (matched: true, res: res, err: err)
