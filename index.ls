# Requires

require! [fs.read-file-sync, os.EOL]
{join, dirname, resolve} = require \path
{empty, is-type, apply, id, fix, span, values, take-while, split, map, reject, words, foldr, replicate} = require \prelude-ls

# Init
const methods = <[GET POST PUT DELETE]>

options =
  routes-path: \./config/routes

# Utils
iterate = (n, f) -> foldr (<<), id, (replicate n, f)

lookup = (obj, [head, ...rest]:keys, not-found) ->
  (if empty rest then obj[head] else lookup obj[head], rest) ? not-found

# Core
load-splitted-config-file = ->
  read-file-sync options.routes-path, \utf-8
    |> split EOL |> map take-while (!= \#) |> reject empty

resources = (agg, ctx, path, ctr, [mod, ...mets]) ->
  partial-path = -> apply join, [ctx, path] ++ map id, &
  routes =
    index:  [\GET    partial-path!,              "#ctr.index"]
    new:    [\GET    (partial-path \new),        "#ctr._new"]
    create: [\POST   partial-path!,              "#ctr.create"]
    show:   [\GET    (partial-path \:id),        "#ctr.show"]
    edit:   [\GET    (partial-path \:id, \edit), "#ctr.edit"]
    update: [\PUT    (partial-path \:id),        "#ctr.update"]
    delete: [\DELETE (partial-path \:id),        "#ctr._delete"]
  apply agg~push, switch mod
    | \only   => [v for k, v of routes when k in mets]
    | \except => [v for k, v of routes when k not in mets]
    | _       => values routes

build-routes = ->
  (fix (reducer) -> ([head, ...rest]:list, lvl, path, agg) ->
    return agg if empty list

    [{length: nlvl}, i] = span (== ' '), head
    [x, y, z, ...opts]  = words i
    path                = (iterate (lvl - nlvl) / 2, dirname) path if nlvl < lvl

    match x, y, z
      | (in methods), (!= void), (!= void) => agg.push [x, (resolve join path, y), z]
      | \resources,   (!= void), (!= void) => resources agg, path, y, z, opts
      | (!= void), void, void              => path = join path, x
      | otherwise                          => throw new Error "Format error: '#i'"
    reducer rest, nlvl, path, agg)(load-splitted-config-file!, 0, \/, [])

# Exports
module.exports = (app, controllers) ->
  for [method, path, keys] in build-routes!
    app[method.to-lower-case!] path, lookup controllers, (split \. keys)
