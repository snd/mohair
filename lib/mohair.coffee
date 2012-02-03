_ = require 'underscore'

assert = require 'assert'

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

            @raw '('

            isFirstValue = true
            _.each _.values(object), (value) =>
                @raw ', ' if not isFirstValue
                isFirstValue = false
                if _.isFunction(value) then value() else
                    @raw '?'
                    @_params.push value

            @raw ')'

        @raw ";\n"

    update: (table, changes, inner) ->
        @raw "UPDATE #{table} SET "
        isFirstValue = true
        _.each changes, (value, column) =>
            @raw ', ' if not isFirstValue
            isFirstValue = false
            @raw "#{column} = "
            if _.isFunction(value) then value() else
                @raw '?'
                @_params.push value

        inner()
        @raw ';\n'

    remove: (table, inner) ->
        @raw "DELETE FROM #{table}"
        inner()
        @raw ';\n'

    select: (table, columns, inner) ->
        if not inner
            inner = columns
            columns = '*'
        columns = columns.join(', ') if _.isArray columns
        @raw "SELECT #{columns} FROM #{table}"
        inner() if inner?
        @raw ";\n"

    transaction: (inner) ->
        @raw 'START TRANSACTION;\n'
        inner()
        @raw 'COMMIT;\n'

    # inner

    where: (inner) ->
        @raw " WHERE "
        inner()

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

    # conditions

    Is: (column, bindingOrFunction) ->
        @raw "#{column} = "
        if _.isFunction(bindingOrFunction) then bindingOrFunction() else
            @raw '?'
            @_params.push bindingOrFunction

    And: -> @raw ' AND '

    # getters

    sql: -> @_sql

    params: -> @_params

module.exports = -> new mohair
