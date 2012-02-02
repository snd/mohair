_ = require 'underscore'

mohair = class

    constructor: ->
        @_sql = ''
        @_params = []

    raw: (sql, params...) ->
        @_sql += sql
        @_params.push params...

    insert: (table, object) ->
        @raw "INSERT INTO #{table} (#{_.keys(object).join(', ')}) VALUES ("

        isFirstValue = true
        _.each _.values(object), (value) =>
            @raw ', ' if not isFirstValue
            isFirstValue = false
            if _.isFunction(value) then value() else
                @raw '?'
                @_params.push value

        @raw ");\n"

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

    Delete: (table, inner) ->
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

    where: (inner) ->
        @raw " WHERE "
        inner()

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
