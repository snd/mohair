assert = require 'assert'

mysql =
    getPlaceholderGenerator: ->
        -> '?'
    quote: (string) -> string.split('.').map((part) -> "`#{part}`").join('.')

    upsert: (table, keyObject, object) ->
        throw new Error 'second argument must be an object' if not typeof keyObject is 'object'
        throw new Error 'third argument must be an object' if not typeof object is 'object'
        combined = {}
        combined[k] = v for k, v of keyObject
        combined[k] = v for k, v of object
        keys = Object.keys combined
        columnString = keys.map(@quote).join(', ')
        @command "INSERT INTO #{@quote table} (#{columnString}) VALUES ", =>
            @array values combined
            @raw ' ON DUPLICATE KEY UPDATE '
            @assignments combined

postgres =
    getPlaceholderGenerator: ->
        i = 1
        -> "$#{i++}"
    quote: (string) -> string.split('.').map((part) -> "\"#{part}\"").join('.')

    upsert: (table, keyObject, object) ->
        throw new Error 'second argument must be an object' if not typeof keyObject is 'object'
        throw new Error 'third argument must be an object' if not typeof object is 'object'
        combined = {}
        combined[k] = v for k, v of keyObject
        combined[k] = v for k, v of object

        @update table, combined, keyObject

        keys = Object.keys combined
        columnString = keys.map(@quote).join(', ')

        @command "INSERT INTO #{@quote table} (#{columnString}) SELECT ", =>
            @intersperse ', ', values(combined), @callOrBind
            @raw " WHERE NOT EXISTS (SELECT 1 FROM #{@quote table} WHERE "
            @query keyObject
            @raw ")"

values = (obj) -> Object.keys(obj).map (key) -> obj[key]

Mohair = class

    constructor: (@database = mysql) ->
        @getNextPlaceholder = @database.getPlaceholderGenerator()
        @quote = @database.quote

        @_sql = ''
        @_params = []

        @_queryModifiers =
            $or: (q) => @parens => @subqueryByOp 'OR', q
            $and: (q) => @subqueryByOp 'AND', q
            $not: (q) => @not => @query q
            $nor: (q) => @not => @subqueryByOp 'OR', q

        @_tests =
            $in: (x) => @before ' IN ', => @array x
            $nin: (x) => @before ' NOT IN ', => @array x

        comparisons =
            '$eq': ' = '
            '$ne': ' != '
            '$lt': ' < '
            '$lte': ' <= '
            '$gt': ' > '
            '$gte': ' >= '

        for key, operator of comparisons
            do (key, operator) =>
                @_tests[key] = (x) => @before operator, => @callOrBind x

    # Core
    # ====

    sql: -> @_sql

    params: -> @_params

    raw: (sql, params...) ->
        @_sql += sql
        @_params.push params...

    # Helpers
    # =======

    array: (xs) -> @parens => @intersperse ', ', xs, @callOrBind

    not: (inner) -> @before 'NOT ', => @parens inner

    quoted: (string) -> @raw "'#{string}'"

    intersperse: (string, obj, f) ->
        first = true
        for key, value of obj
            do (key, value) =>
                if first then first = false else @raw string
                f value, key

    around: (start, end, inner) ->
        @raw start
        inner() if inner?
        @raw end

    before: (start, inner) -> @around start, '', inner

    parens: (inner) -> @around '(', ')', inner

    command: (start, inner) -> @around start, ';\n', inner

    callOrQuery: (f) ->
        return if not f?
        if typeof f is 'function' then f() else @where f

    callOrBind: (f) =>
        if typeof f is 'function' then f() else @raw @getNextPlaceholder(), f

    # {key1} = {value1()}, {key2} = {value2()}, ...
    assignments: (obj) ->
        @intersperse ', ', obj, (value, column) =>
            @before "#{@quote(column)} = ", => @callOrBind value

    # Interface
    # =========

    insert: (table, objects, updates) ->
        throw new Error 'second argument missing in insert' if not objects?
        objects = if Array.isArray objects then objects else [objects]
        return @command "INSERT INTO #{@quote table} () VALUES ()" if objects.length is 0
        keys = Object.keys objects[0]
        columnString = keys.map(@quote).join(', ')
        @command "INSERT INTO #{@quote table} (#{columnString}) VALUES ", =>
            @intersperse ', ', objects, (object, index) =>
                assert.deepEqual keys, Object.keys(object),
                    'objects must have the same keys'

                @array values object

    update: (table, changes, f) ->
        @command "UPDATE #{@quote table} SET ", =>
            @assignments changes

            @callOrQuery f

    delete: (table, f) -> @command "DELETE FROM #{@quote table}", => @callOrQuery f

    select: (table, columns, f) ->
        if not f?
            f = columns
            columns = '*'
        columns = columns.join(', ') if Array.isArray columns
        @command "SELECT #{columns} FROM #{@quote table}", =>
            @callOrQuery f if f?

    transaction: (inner) -> @around 'BEGIN;\n', 'COMMIT;\n', inner

    upsert: ->
        if not @database.upsert?
            throw new Error 'upsert not implemented for selected database'
        @database.upsert.apply @, arguments

    # Select inner
    # ------------

    where: (f) -> @before " WHERE ", =>
        if typeof f is 'function' then f() else @query f

    _join: (prefix, table, left, right) ->
        @raw if not left?
            "#{prefix} JOIN #{table}"
        else
            "#{prefix} JOIN #{@quote table} ON #{@quote left} = #{@quote right}"

    join: (args...) -> @_join '', args...
    leftJoin: (args...) -> @_join ' LEFT', args...
    rightJoin: (args...) -> @_join ' RIGHT', args...
    innerJoin: (args...) -> @_join ' INNER', args...

    groupBy: (column) -> @raw " GROUP BY #{@quote column}"

    orderBy: (xs) ->
        xs = [xs] if not Array.isArray xs
        @raw " ORDER BY "
        @intersperse ', ', xs, (x) =>
            if typeof x is 'string'
                @raw @quote x
            else if typeof x is 'object'
                if x['$asc']
                    @raw @quote(x['$asc']) + ' ASC'
                else if x['$desc']
                    @raw @quote(x['$desc']) + ' DESC'
                else throw new Error "invalid order #{JSON.stringify x}"

    limit: (count) ->
        @raw " LIMIT "
        @callOrBind count

    skip: (count) ->
        @raw " SKIP "
        @callOrBind count

    # Query
    # =====

    query: (query) ->
        @intersperse ' AND ', query, (value, key) =>
            return @_queryModifiers[key] value if @_queryModifiers[key]?

            @raw @quote(key)

            isTest = typeof value is 'object'
            test = @_tests[if isTest then Object.keys(value)[0] else '$eq']
            test if isTest then values(value)[0] else value

    subqueryByOp: (op, list) ->
        if not Array.isArray list
            msg = "array expected as argument to #{op} query but #{list} given"
            throw new Error msg
        @intersperse " #{op} ", list, (x) => @query x

module.exports = (database) -> new Mohair database
module.exports.mysql = -> new Mohair mysql
module.exports.postgres = -> new Mohair postgres
