assert = require 'assert'

_ = require 'underscore'

comparisonTable =
    '$ne': ' != '
    '$lt': ' < '
    '$lte': ' <= '
    '$gt': ' > '
    '$gte': ' >= '

comparisons = _.keys comparisonTable

mohair = class

    constructor: ->
        @_sql = ''
        @_params = []

    raw: (sql, params...) ->
        @_sql += sql
        @_params.push params...

    quoted: (string) -> @raw "'#{string}'"

    intersperse: (string, list, f) ->
        first = true
        _.each list, (v, k) =>
            if first then first = false else @raw string
            f v, k

    commaSeparated: (args...) -> @intersperse ', ', args...

    insert: (table, objects...) ->
        keys = _.keys _.first objects
        @command "INSERT INTO #{table} (#{keys.join(', ')}) VALUES ", =>
            @commaSeparated objects, (object, index) =>
                assert.deepEqual keys, _.keys(object), 'objects must have the same keys'

                @parens =>
                    @commaSeparated _.values(object), (value) => @callOrBind value

    update: (table, changes, funcOrQuery) ->
        @command "UPDATE #{table} SET ", =>
            @commaSeparated changes, (value, column) =>
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

    callOrQuery: (f) -> if _.isFunction f then f() else @where f

    transaction: (inner) -> @around 'START TRANSACTION;\n', 'COMMIT;\n', inner

    # inner

    where: (f) ->
        @raw " WHERE "
        if _.isFunction f then f() else @query f

    query: (query) ->
            @intersperse ' AND ', query, (value, key) =>
                if key is '$or' then @parens => @subqueryByOp 'OR', value
                else if key is '$and' then @subqueryByOp 'AND', value
                else

                    @raw key

                    if _.isObject(value) and not _.isFunction(value)
                        intersection = _.intersection(comparisons, _.keys(value))
                        comp = _.first intersection
                        if comp?
                            @raw comparisonTable[comp]
                            @callOrBind value[comp]
                        else if value.$in?
                            @raw ' IN '
                            @parens =>
                                array = value.$in
                                string = _.map([0...array.length], -> '?').join(', ')
                                @raw string, array...
                        else
                            @raw ' = '
                            @callOrBind value
                    else
                        @raw ' = '
                        @callOrBind value

    subqueryByOp: (op, array) ->
            first = true
            _.each array, (object) =>
                @raw " #{op} " if not first
                first = false
                @query object

    callOrBind: (f) -> if _.isFunction f then f() else @raw '?', f

    # joins
    # -----

    _join: (prefix, table, left, right) ->
        @raw "#{prefix} JOIN #{table} ON #{left} = #{right}"

    join: (args...) -> @_join '', args...
    leftJoin: (args...) -> @_join ' LEFT', args...
    rightJoin: (args...) -> @_join ' RIGHT', args...
    innerJoin: (args...) -> @_join ' INNER', args...

    groupBy: (column) -> @raw " GROUP BY #{column}"

    orderBy: (sql) -> @raw " ORDER BY #{sql}"

    comma: -> @raw ', '

    parens: (inner) -> @around '(', ')', inner

    around: (start, end, inner) ->
        @raw start
        inner() if inner?
        @raw end

    command: (start, inner) -> @around start, ';\n', inner

    # getters
    # -------

    sql: -> @_sql

    params: -> @_params

module.exports = -> new mohair
