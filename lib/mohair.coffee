assert = require 'assert'

_ = require 'underscore'

comma = ', '

Mohair = class

    constructor: (placeholder = -> '?') ->
        @_sql = ''
        @_params = []
        @placeholder = placeholder

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

        _.each comparisons, (value, key) =>
            @_tests[key] = (x) => @before value, => @callOrBind x

    # Core
    # ====

    sql: -> @_sql

    params: -> @_params

    raw: (sql, params...) ->
        @_sql += sql
        @_params.push params...

    # Helpers
    # =======

    array: (xs) -> @parens => @intersperse comma, xs, @callOrBind

    not: (inner) -> @before 'NOT ', => @parens inner

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

    before: (start, inner) -> @around start, '', inner

    parens: (inner) -> @around '(', ')', inner

    command: (start, inner) -> @around start, ';\n', inner

    callOrQuery: (f) -> if _.isFunction f then f() else @where f

    callOrBind: (f) => if _.isFunction f then f() else @raw @placeholder(), f

    # Interface
    # =========

    insert: (table, objects...) ->
        keys = _.keys _.first objects
        @command "INSERT INTO #{table} (#{keys.join(', ')}) VALUES ", =>
            @intersperse comma, objects, (object, index) =>
                assert.deepEqual keys, _.keys(object),
                    'objects must have the same keys'

                @array _.values object

    update: (table, changes, funcOrQuery) ->
        @command "UPDATE #{table} SET ", =>
            @intersperse comma, changes, (value, column) =>
                @before "#{column} = ", => @callOrBind value

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

    where: (f) -> @before " WHERE ", => if _.isFunction f then f() else @query f

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
                modifier = @_queryModifiers[key]
                if modifier?
                    modifier value
                    return

                @raw key

                isTest = _.isObject(value) and not _.isFunction(value)

                test = @_tests[if isTest then _.first _.keys value else '$eq']
                test if isTest then _.first _.values value else value

    subqueryByOp: (op, list) -> @intersperse " #{op} ", list, (x) => @query x

module.exports = (params...) -> new Mohair params...
