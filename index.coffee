assert = require 'assert'

mysql =
    getPlaceholderGenerator: ->
        -> '?'
    quoteField: (field) -> "`#{field}`"

postgres =
    getPlaceholderGenerator: ->
        i = 1
        -> "$#{i++}"
    quoteField: (field) -> "\"#{field}\""

values = (obj) -> Object.keys(obj).map (key) -> obj[key]

Mohair = class

    constructor: (@options = mysql) ->
        @getNextPlaceholder = @options.getPlaceholderGenerator()
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

    callOrQuery: (f) -> if typeof f is 'function' then f() else @where f

    callOrBind: (f) =>
        if typeof f is 'function' then f() else @raw @getNextPlaceholder(), f

    # {key1} = {value1()}, {key2} = {value2()}, ...
    assignments: (obj) ->
        @intersperse ', ', obj, (value, column) =>
            @before "#{@options.quoteField(column)} = ", => @callOrBind value

    # Interface
    # =========

    insert: (table, objects, updates) ->
        throw new Error 'second argument missing in insert' if not objects?
        objects = if Array.isArray objects then objects else [objects]
        return @command "INSERT INTO #{table} () VALUES ()" if objects.length is 0
        keys = Object.keys objects[0]
        columnString = keys.map(@options.quoteField).join(', ')
        @command "INSERT INTO #{table} (#{columnString}) VALUES ", =>
            @intersperse ', ', objects, (object, index) =>
                assert.deepEqual keys, Object.keys(object),
                    'objects must have the same keys'

                @array values object
            if updates?
                throw new Error 'empty updates object' if Object.keys(updates).length is 0
                @raw ' ON DUPLICATE KEY UPDATE '
                @assignments updates

    update: (table, changes, f) ->
        @command "UPDATE #{table} SET ", =>
            @assignments changes

            @callOrQuery f

    remove: (table, f) -> @command "DELETE FROM #{table}", => @callOrQuery f

    select: (table, columns, f) ->
        if not f?
            f = columns
            columns = '*'
        columns = columns.join(', ') if Array.isArray columns
        @command "SELECT #{columns} FROM #{table}", =>
            @callOrQuery f if f?

    transaction: (inner) -> @around 'BEGIN;\n', 'COMMIT;\n', inner

    # Select inner
    # ------------

    where: (f) -> @before " WHERE ", =>
        if typeof f is 'function' then f() else @query f

    _join: (prefix, table, left, right) ->
        @raw if not left?
            "#{prefix} JOIN #{table}"
        else
            "#{prefix} JOIN #{table} ON #{left} = #{right}"

    join: (args...) -> @_join '', args...
    leftJoin: (args...) -> @_join ' LEFT', args...
    rightJoin: (args...) -> @_join ' RIGHT', args...
    innerJoin: (args...) -> @_join ' INNER', args...

    groupBy: (column) -> @raw " GROUP BY #{column}"

    orderBy: (sql) -> @raw " ORDER BY #{sql}"

    # Query
    # =====

    query: (query) ->
        @intersperse ' AND ', query, (value, key) =>
            return @_queryModifiers[key] value if @_queryModifiers[key]?

            @raw @options.quoteField(key)

            isTest = typeof value is 'object'
            test = @_tests[if isTest then Object.keys(value)[0] else '$eq']
            test if isTest then values(value)[0] else value

    subqueryByOp: (op, list) ->
        if not Array.isArray list
            msg = "array expected as argument to #{op} query but #{list} given"
            throw new Error msg
        @intersperse " #{op} ", list, (x) => @query x

module.exports = (options) -> new Mohair options
module.exports.mysql = mysql
module.exports.postgres = postgres
