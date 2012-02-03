_ = require 'underscore'

assert = require 'assert'

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
        @raw "INSERT INTO #{table} (#{keys.join(', ')}) VALUES "

        isFirstObject = true
        _.each objects, (object) =>
            assert.deepEqual keys,  _.keys(object), 'objects must have the same keys'

            @raw ', ' if not isFirstObject
            isFirstObject = false

            @parens =>
                isFirstValue = true
                _.each _.values(object), (value) =>
                    @raw ', ' if not isFirstValue
                    isFirstValue = false
                    @callOrBind value

        @raw ";\n"

    update: (table, changes, funcOrQuery) ->
        @raw "UPDATE #{table} SET "
        isFirstValue = true
        _.each changes, (value, column) =>
            @raw ', ' if not isFirstValue
            isFirstValue = false
            @raw "#{column} = "
            @callOrBind value

        @callOrQuery funcOrQuery
        @raw ';\n'

    remove: (table, funcOrQuery) ->
        @raw "DELETE FROM #{table}"
        @callOrQuery funcOrQuery
        @raw ';\n'

    select: (table, columns, funcOrQuery) ->
        if not funcOrQuery?
            inner = columns
            columns = '*'
        columns = columns.join(', ') if _.isArray columns
        @raw "SELECT #{columns} FROM #{table}"
        @callOrQuery funcOrQuery if funcOrQuery?
        @raw ";\n"

    callOrQuery: (funcOrQuery) ->
        if _.isFunction funcOrQuery then funcOrQuery() else @where funcOrQuery

    transaction: (inner) ->
        @raw 'START TRANSACTION;\n'
        inner()
        @raw 'COMMIT;\n'

    # inner

    where: (functionOrQuery) ->
        @raw " WHERE "
        if _.isFunction functionOrQuery then functionOrQuery()
        else @query functionOrQuery

    query: (query) -> @andQuery query

    andQuery: (query) ->
            first = true
            _.each query, (value, key) =>
                @raw " AND " if not first
                first = false

                if key is '$or'
                    @parens => @subqueryByOp 'OR', value
                else if key is '$and'
                    @subqueryByOp 'AND', value
                else
                    @raw key

                    if _.isObject(value) and not _.isFunction(value)
                        intersection = _.intersection(comparisons, _.keys(value))
                        comp = _.first intersection
                        if comp?
                            @raw comparisonTable[comp]
                            @callOrBind value[comp]
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
                @andQuery object

    callOrBind: (functionOrValue) ->
        if _.isFunction functionOrValue then functionOrValue() else @raw '?', functionOrValue

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

    groupBy: (column) ->
        @raw " GROUP BY #{column}"

    orderBy: (sql) ->
        @raw " ORDER BY #{sql}"

    parens: (inner) ->
        @raw '('
        inner()
        @raw ')'

    # getters

    sql: -> @_sql

    params: -> @_params

module.exports = -> new mohair
