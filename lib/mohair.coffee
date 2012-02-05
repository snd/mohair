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

    insert: (table, objects...) ->
        keys = _.keys _.first objects
        @command "INSERT INTO #{table} (#{keys.join(', ')}) VALUES ", =>
            isFirstObject = true
            _.each objects, (object) =>
                assert.deepEqual keys, _.keys(object), 'objects must have the same keys'

                if isFirstObject then isFirstObject = false else @comma()

                @parens =>
                    isFirstValue = true
                    _.each _.values(object), (value) =>
                        if isFirstValue then isFirstValue = false else @comma()
                        @callOrBind value

    update: (table, changes, funcOrQuery) ->
        @command "UPDATE #{table} SET ", =>
            isFirstValue = true
            _.each changes, (value, column) =>
                if isFirstValue then isFirstValue = false else @comma()
                @raw "#{column} = "
                @callOrBind value

            @callOrQuery funcOrQuery

    remove: (table, funcOrQuery) ->
        @command "DELETE FROM #{table}", => @callOrQuery funcOrQuery

    select: (table, columns, funcOrQuery) ->
        if not funcOrQuery?
            funcOrQuery = columns
            columns = '*'
        columns = columns.join(', ') if _.isArray columns
        @command "SELECT #{columns} FROM #{table}", =>
            @callOrQuery funcOrQuery if funcOrQuery?

    callOrQuery: (funcOrQuery) ->
        if _.isFunction funcOrQuery then funcOrQuery() else @where funcOrQuery

    transaction: (inner) -> @around 'START TRANSACTION;\n', 'COMMIT;\n', inner

    # inner

    where: (functionOrQuery) ->
        @raw " WHERE "
        if _.isFunction functionOrQuery then functionOrQuery()
        else @query functionOrQuery

    query: (query) ->
            first = true
            _.each query, (value, key) =>
                @raw " AND " if not first
                first = false

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

    callOrBind: (functionOrValue) ->
        if _.isFunction functionOrValue then functionOrValue() else @raw '?', functionOrValue

    # joins
    # -----

    join: (table, leftColumn, rightColumn) ->
        @raw " JOIN #{table} ON #{leftColumn} = #{rightColumn}"

    leftJoin: (args...) ->
        @raw " LEFT"
        @join args...

    rightJoin: (args...) ->
        @raw " RIGHT"
        @join args...

    innerJoin: (args...) ->
        @raw " INNER"
        @join args...

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
