assert = require 'assert'

_ = require 'underscore'

comparisonTable =
    '$ne': ' != '
    '$lt': ' < '
    '$lte': ' <= '
    '$gt': ' > '
    '$gte': ' >= '

comparisons = _.keys comparisonTable

comma = ', '

Mohair = class

    # Core
    # ====

    constructor: ->
        @_sql = ''
        @_params = []

        @_queries =
            $or: (x) => @parens => @subqueryByOp 'OR', x
            $and: (x) => @subqueryByOp 'AND', x
            $not: (x) =>
                @raw 'NOT '
                @parens => @query x

    sql: -> @_sql

    params: -> @_params

    raw: (sql, params...) ->
        @_sql += sql
        @_params.push params...

    # Helpers
    # =======

    quoted: (string) -> @raw "'#{string}'"

    intersperse: (string, list, f) ->
        first = true
        _.each list, (v, k) =>
            if first then first = false else @raw string
            f v, k

    around: (start, end, inner) ->
        @raw start
        inner() if inner?
        @raw end

    parens: (inner) -> @around '(', ')', inner

    command: (start, inner) -> @around start, ';\n', inner

    callOrQuery: (f) -> if _.isFunction f then f() else @where f

    callOrBind: (f) => if _.isFunction f then f() else @raw '?', f

    # Interface
    # =========

    insert: (table, objects...) ->
        keys = _.keys _.first objects
        @command "INSERT INTO #{table} (#{keys.join(', ')}) VALUES ", =>
            @intersperse comma, objects, (object, index) =>
                assert.deepEqual keys, _.keys(object),
                    'objects must have the same keys'

                @parens => @intersperse comma, _.values(object), @callOrBind

    update: (table, changes, funcOrQuery) ->
        @command "UPDATE #{table} SET ", =>
            @intersperse comma, changes, (value, column) =>
                @raw "#{column} = "
                @callOrBind value

            @callOrQuery funcOrQuery

    remove: (table, f) -> @command "DELETE FROM #{table}", => @callOrQuery f

    select: (table, columns, funcOrQuery) ->
        if not funcOrQuery?
            funcOrQuery = columns
            columns = '*'
        columns = columns.join(', ') if _.isArray columns
        @command "SELECT #{columns} FROM #{table}", =>
            @callOrQuery funcOrQuery if funcOrQuery?

    transaction: (inner) -> @around 'START TRANSACTION;\n', 'COMMIT;\n', inner

    # Select inner
    # ------------

    where: (f) ->
        @raw " WHERE "
        if _.isFunction f then f() else @query f

    _join: (prefix, table, left, right) ->
        @raw "#{prefix} JOIN #{table} ON #{left} = #{right}"

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
                special = @_queries[key]
                if  special?
                    special value
                    return

                @raw key

                if not _.isObject(value) or _.isFunction(value)
                    @raw ' = '
                    @callOrBind value
                    return

                comp = _.first _.intersection comparisons, _.keys value
                if comp?
                    @raw comparisonTable[comp]
                    @callOrBind value[comp]
                else if value.$in?
                    @raw ' IN '
                    @parens =>
                        array = value.$in
                        string = _.map([0...array.length], -> '?').join(', ')
                        @raw string, array...

    subqueryByOp: (op, list) -> @intersperse " #{op} ", list, (x) => @query x

module.exports = -> new Mohair
